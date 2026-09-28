"""Integration tests: the vocabulary admin API (story 006-vocabulary-api,
bolt 040-admin-vocabulary), over HTTP against a temp SQLite database holding
the real seeded content. Admin-only access is covered for every route by
`test_admin_content_endpoints.TestAccess`.
"""

from __future__ import annotations

import asyncio
import logging
import sqlite3
from collections.abc import Callable
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.orm import Session as SyncSession

from app.config import Settings
from app.infrastructure.api import dependencies
from app.infrastructure.db.lesson_models import UserVocabProgressModel, VocabItemModel
from app.infrastructure.db.seed_lesson_content import _content_id, seed
from tests.fakes import EN_AM_COURSE_ID, FakeTokenVerifier

ClientFactory = Callable[[object, object], TestClient]
ADMIN = "admin@example.com"
A = "/api/v1/admin"
HELLO = _content_id("vocab:hello")
GOODBYE = _content_id("vocab:goodbye")


@pytest.fixture
def seeded(db_path: Path) -> Path:
    async def _seed() -> None:
        engine = create_async_engine(f"sqlite+aiosqlite:///{db_path}")
        async with AsyncSession(engine) as session:
            await seed(session)
            await session.commit()
        await engine.dispose()

    asyncio.run(_seed())
    return db_path


@pytest.fixture
def client(make_client: ClientFactory, seeded: Path, monkeypatch: pytest.MonkeyPatch) -> TestClient:
    monkeypatch.setattr(dependencies, "get_settings", lambda: Settings(admin_emails=ADMIN))
    return make_client(FakeTokenVerifier(subject="sub-admin", email=ADMIN), FakeTokenVerifier())


@pytest.fixture
def h(client: TestClient) -> dict[str, str]:
    token = client.post("/api/v1/auth/google", json={"id_token": "t"}).json()["session_token"]
    return {"Authorization": f"Bearer {token}"}


def _rows(db: Path, sql: str, *args: Any) -> list[tuple]:
    with sqlite3.connect(db) as conn:
        return conn.execute(sql, args).fetchall()


def _user_id(db: Path) -> str:
    return _rows(db, "SELECT id FROM users LIMIT 1")[0][0]


def _add_progress(db: Path, user_id: str, vocab_item_id: str, *, due: bool = False) -> None:
    now = datetime.now(UTC)
    engine = create_engine(f"sqlite:///{db}")
    with SyncSession(engine) as session:
        session.add(
            UserVocabProgressModel(
                user_id=user_id,
                vocab_item_id=vocab_item_id,
                box_level=2,
                next_review_at=now - timedelta(hours=1) if due else now + timedelta(days=3),
                last_seen_at=now - timedelta(days=1),
            )
        )
        session.commit()
    engine.dispose()


def _add_unused_word(db: Path, vocab_id: str, word: str) -> None:
    engine = create_engine(f"sqlite:///{db}")
    with SyncSession(engine) as session:
        session.add(
            VocabItemModel(id=vocab_id, course_id=EN_AM_COURSE_ID, word=word, translation="x")
        )
        session.commit()
    engine.dispose()


def _numbers(client: TestClient, h: dict) -> dict[str, str]:
    """Each lesson's number as the tree screen gives it: 1-based positions
    of section, skill and lesson in order."""
    tree = client.get(f"{A}/courses/{EN_AM_COURSE_ID}/tree", headers=h).json()

    def by_order(items: list[dict[str, Any]]) -> list[dict[str, Any]]:
        return sorted(items, key=lambda i: i["order_index"])

    return {
        lesson["id"]: f"{s}.{k}.{n}"
        for s, section in enumerate(by_order(tree["sections"]), start=1)
        for k, skill in enumerate(by_order(section["skills"]), start=1)
        for n, lesson in enumerate(by_order(skill["lessons"]), start=1)
    }


def _place(number: str) -> tuple[int, ...]:
    """A lesson number as a tuple, so places sort as numbers: 5.1.10 -> (5, 1, 10)."""
    return tuple(int(n) for n in number.split("."))


def _vocab(client: TestClient, h: dict) -> dict[str, Any]:
    response = client.get(f"{A}/courses/{EN_AM_COURSE_ID}/vocab", headers=h)
    assert response.status_code == 200
    return response.json()


class TestList:
    def test_lists_this_course_and_nothing_else(
        self, client: TestClient, h: dict, seeded: Path
    ) -> None:
        body = _vocab(client, h)

        mine = "SELECT id FROM vocab_items WHERE course_id = ?"
        others = "SELECT count(*) FROM vocab_items WHERE course_id != ?"
        expected = {r[0] for r in _rows(seeded, mine, EN_AM_COURSE_ID)}
        assert _rows(seeded, others, EN_AM_COURSE_ID)[0][0] > 0  # other courses have words too
        assert {i["id"] for i in body["items"]} == expected
        assert body["course"]["id"] == EN_AM_COURSE_ID
        assert body["course"]["section_count"] > 0

    def test_each_word_lists_every_exercise_that_points_at_it_with_its_place(
        self, client: TestClient, h: dict, seeded: Path
    ) -> None:
        numbers = _numbers(client, h)
        body = _vocab(client, h)

        links = _rows(
            seeded,
            "SELECT e.id, e.lesson_id, e.vocab_item_id, e.type, e.prompt FROM exercises e "
            "JOIN vocab_items v ON v.id = e.vocab_item_id WHERE v.course_id = ?",
            EN_AM_COURSE_ID,
        )
        assert links
        by_id = {i["id"]: i for i in body["items"]}
        for exercise_id, lesson_id, vocab_id, ex_type, prompt in links:
            use = next(u for u in by_id[vocab_id]["used_by"] if u["exercise_id"] == exercise_id)
            assert use["lesson_id"] == lesson_id
            assert use["type"] == ex_type
            assert use["prompt"] == prompt
            assert use["number"] == numbers[lesson_id]
        assert sum(len(i["used_by"]) for i in body["items"]) == len(links)

        hello = by_id[HELLO]
        assert hello["word"] == "ሰላም"
        assert hello["translation"] == "Hello"
        (use,) = hello["used_by"]
        assert use["number"] == "1.1.1"
        assert use["section_title"] and use["skill_title"] and use["lesson_title"]

    def test_curriculum_order_then_unused_words_by_word(
        self, client: TestClient, h: dict, seeded: Path
    ) -> None:
        _add_unused_word(seeded, "vocab-zz", "zebra")
        _add_unused_word(seeded, "vocab-aa", "Apple")
        numbers = _numbers(client, h)
        body = _vocab(client, h)

        items = body["items"]
        used = [i for i in items if i["used_by"]]
        unused = [i for i in items if not i["used_by"]]
        assert items == used + unused
        places = [_place(numbers[i["used_by"][0]["lesson_id"]]) for i in used]
        assert places == sorted(places)
        assert items[0]["id"] == HELLO
        words = [i["word"] for i in unused]
        assert words == sorted(words, key=str.casefold)
        assert {"vocab-zz", "vocab-aa"} <= {i["id"] for i in unused}

    def test_learner_counts(self, client: TestClient, h: dict, seeded: Path) -> None:
        assert _vocab(client, h)["learners"] == 0
        admin = _user_id(seeded)
        _add_progress(seeded, admin, HELLO)
        _add_progress(seeded, admin, GOODBYE)

        body = _vocab(client, h)

        counts = {i["id"]: i["learners"] for i in body["items"]}
        assert counts[HELLO] == 1
        assert counts[GOODBYE] == 1
        assert sum(counts.values()) == 2
        assert body["learners"] == 1  # one learner, however many words

    def test_an_empty_course_lists_nothing(self, client: TestClient, h: dict, seeded: Path) -> None:
        with sqlite3.connect(seeded) as conn:
            conn.execute("UPDATE exercises SET vocab_item_id = NULL")
            conn.execute("DELETE FROM vocab_items")
        body = _vocab(client, h)
        assert body["items"] == []
        assert body["learners"] == 0

    def test_unknown_course_is_404(self, client: TestClient, h: dict) -> None:
        response = client.get(f"{A}/courses/nope/vocab", headers=h)
        assert response.status_code == 404
        assert response.json()["error_code"] == "content_not_found"


class TestUpdate:
    def _patch(self, client: TestClient, h: dict, vocab_id: str, **body: Any) -> Any:
        return client.patch(f"{A}/vocab/{vocab_id}", json=body, headers=h)

    def test_trims_saves_and_answers_in_the_list_shape(
        self, client: TestClient, h: dict, seeded: Path
    ) -> None:
        before = next(i for i in _vocab(client, h)["items"] if i["id"] == HELLO)

        response = self._patch(client, h, HELLO, word="  ሰላም ነው ", translation=" Hi there ")

        assert response.status_code == 200
        assert response.json() == {**before, "word": "ሰላም ነው", "translation": "Hi there"}
        assert _rows(seeded, "SELECT word, translation FROM vocab_items WHERE id = ?", HELLO) == [
            ("ሰላም ነው", "Hi there")
        ]

    def test_one_field_alone_leaves_the_other(
        self, client: TestClient, h: dict, seeded: Path
    ) -> None:
        assert self._patch(client, h, HELLO, translation="Hi").status_code == 200
        assert _rows(seeded, "SELECT word, translation FROM vocab_items WHERE id = ?", HELLO) == [
            ("ሰላም", "Hi")
        ]

    @pytest.mark.parametrize(
        ("body", "field"),
        [
            ({"word": "   "}, "word"),
            ({"word": ""}, "word"),
            ({"translation": " "}, "translation"),
            ({"word": "ok", "translation": "x" * 256}, "translation"),
            ({"word": "ሀ" * 256}, "word"),
        ],
    )
    def test_refuses_empty_or_too_long_text_and_writes_nothing(
        self, client: TestClient, h: dict, seeded: Path, body: dict[str, str], field: str
    ) -> None:
        response = self._patch(client, h, HELLO, **body)

        assert response.status_code == 422
        assert response.json()["error_code"] == "invalid_content"
        assert response.json()["details"] == {"field": field}
        assert _rows(seeded, "SELECT word, translation FROM vocab_items WHERE id = ?", HELLO) == [
            ("ሰላም", "Hello")
        ]

    def test_255_characters_is_allowed(self, client: TestClient, h: dict) -> None:
        assert self._patch(client, h, HELLO, translation="x" * 255).status_code == 200

    def test_unknown_word_is_404(self, client: TestClient, h: dict) -> None:
        response = self._patch(client, h, "nope", word="x")
        assert response.status_code == 404
        assert response.json()["error_code"] == "content_not_found"

    def test_progress_is_kept_and_practice_still_serves_the_word(
        self, client: TestClient, h: dict, seeded: Path
    ) -> None:
        admin = _user_id(seeded)
        _add_progress(seeded, admin, HELLO, due=True)
        progress = "SELECT box_level, next_review_at, last_seen_at FROM user_vocab_progress"
        before = _rows(seeded, progress)

        assert self._patch(client, h, HELLO, word="ሰላም!", translation="Hello!").status_code == 200

        assert _rows(seeded, progress) == before
        due = client.get("/api/v1/practice/due-items", headers=h).json()["items"]
        (item,) = due
        assert item["vocab_item_id"] == HELLO
        assert (item["word"], item["translation"]) == ("ሰላም!", "Hello!")
        assert next(i for i in _vocab(client, h)["items"] if i["id"] == HELLO)["learners"] == 1

    def test_logs_one_line_without_the_text(
        self, client: TestClient, h: dict, caplog: pytest.LogCaptureFixture
    ) -> None:
        with caplog.at_level(logging.INFO, logger="app.admin"):
            self._patch(client, h, HELLO, word="SECRET-WORD")
            self._patch(client, h, HELLO, word=" ")  # refused: no line

        lines = [r.getMessage() for r in caplog.records if r.name == "app.admin"]
        assert lines == [f"admin_write action=update entity=vocab id={HELLO} admin={ADMIN}"]
