"""Integration tests: a curriculum lesson's draft exercises, and publishing
it into the live course beside the seeded, hand-made content (bolt 085)."""

from __future__ import annotations

import asyncio
import sqlite3
import uuid
from collections.abc import Callable
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine

from app.config import Settings
from app.infrastructure.api import dependencies
from app.infrastructure.db.seed_lesson_content import seed
from tests.fakes import EN_AM_COURSE_ID, FakeTokenVerifier

ClientFactory = Callable[[object, object], TestClient]
ADMIN = "admin@example.com"
C = f"/api/v1/admin/courses/{EN_AM_COURSE_ID}/curriculum"
TREE = f"/api/v1/admin/courses/{EN_AM_COURSE_ID}/tree"
CLIP = "https://pub-abc.r2.dev/am/curriculum/W001/0123456789ab.m4a"
LESSON = "S1-U01-L1"
_BODY = ("type", "prompt", "content", "answer_key")


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


def _import(client: TestClient, h: dict) -> None:
    entries = [
        {"ref": "S1", "kind": "section", "position": 1, "title": "First conversations"},
        {"ref": "S1-U01", "kind": "skill", "parent_ref": "S1", "position": 1, "title": "Greetings"},
        {"ref": LESSON, "kind": "lesson", "parent_ref": "S1-U01", "position": 1, "title": "Hello"},
        {"ref": "S1-U01-L2", "kind": "lesson", "parent_ref": "S1-U01", "position": 2},
    ]
    entries[-1]["title"] = "Bye"
    word = {"kind": "word", "lesson_ref": LESSON, "status": "draft"}
    rows = [
        {**word, "ref": "W001", "position": 1, "english": "hello", "text": "ሰላም"},
        {**word, "ref": "W002", "position": 2, "english": "goodbye", "text": "ቻው"},
        {
            "ref": "S001",
            "kind": "sentence",
            "lesson_ref": LESSON,
            "position": 3,
            "english": "Hello, goodbye",
            "text": "ሰላም ቻው",
            "blank": "ቻው",
            "status": "draft",
        },
        {**word, "ref": "W003", "lesson_ref": "S1-U01-L2", "position": 1, "english": "bye"},
    ]
    response = client.put(C, json={"entries": entries, "rows": rows}, headers=h)
    assert response.status_code == 200, response.text


def _row(client: TestClient, h: dict, ref: str) -> dict[str, Any]:
    return next(r for r in client.get(C, headers=h).json()["rows"] if r["ref"] == ref)


def _patch(client: TestClient, h: dict, ref: str, **changes: Any) -> None:
    version = _row(client, h, ref)["version"]
    response = client.patch(f"{C}/rows/{ref}", json={"version": version, **changes}, headers=h)
    assert response.status_code == 200, response.text


def _finish(client: TestClient, h: dict, refs: tuple[str, ...] = ("W001", "W002", "S001")) -> None:
    for ref in refs:
        _patch(client, h, ref, audio_url=CLIP)
        _patch(client, h, ref, status="reviewed")


def _choice(prompt: str, vocab_ref: str | None = "W001") -> dict[str, Any]:
    body = {
        "type": "multiple_choice",
        "prompt": prompt,
        "content": {"choices": [{"id": "a", "text": "ሰላም"}, {"id": "b", "text": "ቻው"}]},
        "answer_key": {"correct_choice_id": "a"},
    }
    return {**body, "vocab_ref": vocab_ref, "generated": body, "edited": False}


def _save(client: TestClient, h: dict, *exercises: dict[str, Any], lesson: str = LESSON) -> Any:
    return client.put(
        f"{C}/lessons/{lesson}/exercises", json={"exercises": list(exercises)}, headers=h
    )


def _publish(client: TestClient, h: dict, lesson: str = LESSON) -> Any:
    return client.post(f"{C}/lessons/{lesson}/publish", headers=h)


def _entry(client: TestClient, h: dict, ref: str) -> dict[str, Any]:
    return next(e for e in client.get(C, headers=h).json()["entries"] if e["ref"] == ref)


class TestDraftExercises:
    def test_are_kept_in_order_once_the_lesson_is_ready(self, client: TestClient, h: dict) -> None:
        _import(client, h)
        _finish(client, h)

        response = _save(client, h, _choice("Which is hello?"), _choice("Pick ሰላም", None))

        assert response.status_code == 200, response.text
        saved = client.get(f"{C}/lessons/{LESSON}/exercises", headers=h).json()["exercises"]
        assert [x["prompt"] for x in saved] == ["Which is hello?", "Pick ሰላም"]
        assert saved[0]["vocab_ref"] == "W001"
        assert saved[0]["generated"]["type"] == "multiple_choice"
        assert _entry(client, h, LESSON)["exercise_count"] == 2

    def test_wait_until_every_row_is_reviewed_and_recorded(
        self, client: TestClient, h: dict
    ) -> None:
        _import(client, h)
        _finish(client, h, ("W001", "W002"))

        response = _save(client, h, _choice("Which is hello?"))

        assert response.status_code == 409
        body = response.json()
        assert body["error_code"] == "lesson_not_ready"
        assert body["details"] == {
            "reason": "rows",
            "rows": 3,
            "not_reviewed": 1,
            "not_recorded": 1,
        }

    def test_are_checked_like_any_exercise(self, client: TestClient, h: dict) -> None:
        _import(client, h)
        _finish(client, h)
        broken = _choice("Which?")
        broken["answer_key"] = {"correct_choice_id": "z"}

        response = _save(client, h, _choice("Fine"), broken, _choice("Bye?", "S001"))

        assert response.status_code == 422
        rows = response.json()["details"]["rows"]
        assert [(r["index"], r["field"]) for r in rows] == [
            (1, "answer_key.correct_choice_id"),
            (2, "vocab_ref"),
        ]
        assert client.get(f"{C}/lessons/{LESSON}/exercises", headers=h).json()["exercises"] == []

    def test_a_missing_lesson_is_404(self, client: TestClient, h: dict) -> None:
        _import(client, h)

        assert client.get(f"{C}/lessons/S1-U01/exercises", headers=h).status_code == 404
        assert _publish(client, h, "S9-U01-L1").status_code == 404


class TestPublishing:
    def test_needs_a_finished_lesson_with_exercises(self, client: TestClient, h: dict) -> None:
        _import(client, h)

        not_reviewed = _publish(client, h)
        assert not_reviewed.status_code == 409
        assert not_reviewed.json()["details"]["reason"] == "rows"
        _finish(client, h)
        no_exercises = _publish(client, h)
        assert no_exercises.status_code == 409
        assert no_exercises.json()["details"] == {"reason": "exercises"}

    def test_the_first_lesson_makes_its_section_and_skill_beside_the_rest(
        self, client: TestClient, h: dict, seeded: Path
    ) -> None:
        before = client.get(TREE, headers=h).json()["sections"]
        _import(client, h)
        _finish(client, h)
        _save(client, h, _choice("Which is hello?"), _choice("Pick ሰላም", None))
        assert _entry(client, h, LESSON)["publish_state"] == "not_published"

        response = _publish(client, h)

        assert response.status_code == 200, response.text
        result = response.json()
        assert result["created"] == ["section", "skill", "lesson"]
        sections = client.get(TREE, headers=h).json()["sections"]
        # Everything already in the course is as it was, and comes first.
        assert sections[: len(before)] == before
        new = sections[-1]
        assert new["id"] == result["category_id"] and new["title"] == "First conversations"
        assert new["skills"][0]["title"] == "Greetings"
        lesson = new["skills"][0]["lessons"][0]
        assert lesson["id"] == result["lesson_id"] and lesson["title"] == "Hello"
        assert [x["prompt"] for x in lesson["exercises"]] == ["Which is hello?", "Pick ሰላም"]

        with sqlite3.connect(seeded) as conn:
            vocab = conn.execute(
                "SELECT v.word, v.translation, e.prompt FROM exercises e"
                " JOIN vocab_items v ON v.id = e.vocab_item_id WHERE e.lesson_id = ?",
                (result["lesson_id"],),
            ).fetchall()
        assert vocab == [("ሰላም", "hello", "Which is hello?")]
        entry = _entry(client, h, LESSON)
        assert entry["publish_state"] == "published"
        assert entry["published_id"] == result["lesson_id"]
        assert _entry(client, h, "S1")["published_id"] == result["category_id"]

    def test_a_second_lesson_joins_the_same_skill(self, client: TestClient, h: dict) -> None:
        _import(client, h)
        _finish(client, h)
        _finish(client, h, ("W003",))
        _save(client, h, _choice("Which is hello?"))
        first = _publish(client, h).json()
        _save(client, h, _choice("Which is bye?", "W003"), lesson="S1-U01-L2")

        second = _publish(client, h, "S1-U01-L2").json()

        assert second["created"] == ["lesson"]
        assert second["skill_id"] == first["skill_id"]
        skill = client.get(TREE, headers=h).json()["sections"][-1]["skills"][0]
        assert [lesson["title"] for lesson in skill["lessons"]] == ["Hello", "Bye"]

    def test_publishing_again_keeps_the_lesson_and_replaces_only_its_exercises(
        self, client: TestClient, h: dict, seeded: Path
    ) -> None:
        _import(client, h)
        _finish(client, h)
        _save(client, h, _choice("First go"))
        first = _publish(client, h).json()
        # An admin adds one by hand in the tree.
        hand = client.post(
            f"/api/v1/admin/lessons/{first['lesson_id']}/exercises",
            json={k: v for k, v in _choice("By hand").items() if k in _BODY},
            headers=h,
        )
        assert hand.status_code == 201, hand.text
        with sqlite3.connect(seeded) as conn:
            (stamp,) = conn.execute(
                "SELECT updated_at FROM lessons WHERE id = ?", (first["lesson_id"],)
            ).fetchone()
        _patch(client, h, "W001", text="ሰላም!", status="reviewed")
        assert _entry(client, h, LESSON)["publish_state"] == "changed"
        _save(client, h, _choice("Second go"), _choice("Another"))

        again = _publish(client, h).json()

        assert again["created"] == []
        assert again["lesson_id"] == first["lesson_id"]
        lesson = client.get(TREE, headers=h).json()["sections"][-1]["skills"][0]["lessons"][0]
        assert [x["prompt"] for x in lesson["exercises"]] == ["By hand", "Second go", "Another"]
        with sqlite3.connect(seeded) as conn:
            (moved,) = conn.execute(
                "SELECT updated_at FROM lessons WHERE id = ?", (first["lesson_id"],)
            ).fetchone()
            words = conn.execute(
                "SELECT word FROM vocab_items WHERE translation = 'hello' AND course_id = ?",
                (EN_AM_COURSE_ID,),
            ).fetchall()
        assert moved > stamp
        # The same vocabulary item, with the corrected word.
        assert words == [("ሰላም!",)]
        assert _entry(client, h, LESSON)["publish_state"] == "published"

    def test_a_section_deleted_by_hand_is_made_again(self, client: TestClient, h: dict) -> None:
        _import(client, h)
        _finish(client, h)
        _save(client, h, _choice("Which is hello?"))
        first = _publish(client, h).json()
        deleted = client.delete(
            f"/api/v1/admin/sections/{first['category_id']}?confirm=true", headers=h
        )
        assert deleted.status_code == 204, deleted.text

        again = _publish(client, h).json()

        assert again["created"] == ["section", "skill", "lesson"]
        assert again["category_id"] != first["category_id"]


class TestPlayingAPublishedLesson:
    def test_a_word_asked_about_twice_still_completes_and_counts_once(
        self, client: TestClient, h: dict, seeded: Path
    ) -> None:
        # A Workbook lesson asks about each word in more than one exercise;
        # completing it used to fail on a second progress row for the word.
        _import(client, h)
        _finish(client, h)
        _save(client, h, _choice("Which is hello?"), _choice("Hear hello"), _choice("Bye?", "W002"))
        published = _publish(client, h).json()
        missed = published["exercise_ids"][1]

        response = client.post(
            f"/api/v1/lessons/{published['lesson_id']}/complete",
            json={
                "attempt_id": str(uuid.uuid4()),
                "correct_count": 2,
                "total_count": 3,
                "time_spent_seconds": 30,
                "client_completed_at": datetime.now(UTC).isoformat(),
                "missed_exercise_ids": [missed],
            },
            headers=h,
        )

        assert response.status_code == 200, response.text
        skill = next(
            s
            for s in client.get("/api/v1/skill-tree", headers=h).json()["skills"]
            if s["id"] == published["skill_id"]
        )
        # Its only published lesson, so the skill is finished.
        assert skill["state"] == "completed"
        with sqlite3.connect(seeded) as conn:
            rows = conn.execute(
                "SELECT v.translation, p.box_level FROM user_vocab_progress p"
                " JOIN vocab_items v ON v.id = p.vocab_item_id ORDER BY v.translation"
            ).fetchall()
        assert rows == [("goodbye", 1), ("hello", 1)]
