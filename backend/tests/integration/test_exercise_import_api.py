"""Integration tests: importing a lesson's exercises (bolt
056-exercise-import), over HTTP against a temp SQLite database holding the
real seeded content. Every exercise is checked, then all are saved or none.
"""

from __future__ import annotations

import asyncio
import logging
import sqlite3
from collections.abc import Callable
from pathlib import Path
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine

from app.application.admin_content_use_cases import IMPORT_MAX
from app.config import Settings
from app.infrastructure.api import dependencies
from app.infrastructure.db.seed_lesson_content import CURRICULUM, _content_id, seed
from tests.fakes import FakeTokenVerifier

ClientFactory = Callable[[object, object], TestClient]
ADMIN = "admin@example.com"
A = "/api/v1/admin"
FIRST_LESSON = _content_id(CURRICULUM[0]["lessons"][0]["slug"])
IMPORT = f"{A}/lessons/{FIRST_LESSON}/exercises/import"


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


def _choice(prompt: str, answer: str = "a") -> dict[str, Any]:
    return {
        "type": "multiple_choice",
        "prompt": prompt,
        "content": {"choices": [{"id": "a", "text": "ሰላም"}, {"id": "b", "text": "ቻው"}]},
        "answer_key": {"correct_choice_id": answer},
    }


def _spell(prompt: str) -> dict[str, Any]:
    return {
        "type": "spell_tiles",
        "prompt": prompt,
        "content": {"tiles": [{"id": "t1", "text": "ና"}, {"id": "t2", "text": "ቡ"}]},
        "answer_key": {"correct_sequence": ["t2", "t1"]},
    }


def _exercises(client: TestClient, h: dict) -> list[dict[str, Any]]:
    return client.get(f"{A}/lessons/{FIRST_LESSON}/exercises", headers=h).json()["exercises"]


def _version(db: Path) -> str:
    with sqlite3.connect(db) as conn:
        return conn.execute(
            "SELECT updated_at FROM lessons WHERE id = ?", (FIRST_LESSON,)
        ).fetchone()[0]


class TestAppend:
    def test_adds_after_the_last_exercise_in_file_order(self, client: TestClient, h: dict) -> None:
        before = _exercises(client, h)
        body = [_choice("One"), _spell("Two"), _choice("Three", "b")]

        response = client.post(IMPORT, json={"exercises": body}, headers=h)

        assert response.status_code == 201, response.json()
        after = response.json()["exercises"]
        assert [e["id"] for e in after[: len(before)]] == [e["id"] for e in before]
        added = after[len(before) :]
        assert [e["prompt"] for e in added] == ["One", "Two", "Three"]
        assert [e["order_index"] for e in after] == list(range(1, len(after) + 1))
        assert all({k: e[k] for k in body[i]} == body[i] for i, e in enumerate(added))
        assert after == _exercises(client, h)

    def test_the_prompt_is_trimmed(self, client: TestClient, h: dict) -> None:
        response = client.post(IMPORT, json={"exercises": [_choice("  Pick  ")]}, headers=h)
        assert response.json()["exercises"][-1]["prompt"] == "Pick"

    def test_moves_the_lessons_version(self, client: TestClient, h: dict, seeded: Path) -> None:
        before = _version(seeded)
        client.post(IMPORT, json={"exercises": [_choice("One")]}, headers=h)
        assert _version(seeded) > before

    def test_the_learner_sees_the_new_exercises(self, client: TestClient, h: dict) -> None:
        client.post(IMPORT, json={"exercises": [_spell("Spell coffee")]}, headers=h)

        lesson = client.get(f"/api/v1/lessons/{FIRST_LESSON}", headers=h).json()

        assert lesson["exercises"][-1]["prompt"] == "Spell coffee"
        assert lesson["exercises"][-1]["type"] == "spell_tiles"


class TestReplace:
    def test_leaves_exactly_the_imported_exercises(self, client: TestClient, h: dict) -> None:
        old = {e["id"] for e in _exercises(client, h)}
        assert old

        response = client.post(
            IMPORT,
            json={"exercises": [_choice("One"), _choice("Two")], "mode": "replace"},
            headers=h,
        )

        assert response.status_code == 201, response.json()
        after = _exercises(client, h)
        assert [e["prompt"] for e in after] == ["One", "Two"]
        assert [e["order_index"] for e in after] == [1, 2]
        assert not old & {e["id"] for e in after}

    def test_a_refused_replace_keeps_the_old_exercises(self, client: TestClient, h: dict) -> None:
        before = _exercises(client, h)

        response = client.post(
            IMPORT, json={"exercises": [_choice("One", "z")], "mode": "replace"}, headers=h
        )

        assert response.status_code == 422
        assert _exercises(client, h) == before


class TestRefusals:
    def test_every_bad_exercise_is_reported_and_nothing_is_saved(
        self, client: TestClient, h: dict
    ) -> None:
        before = _exercises(client, h)
        body = [_choice("Fine"), _choice("Wrong key", "z"), _choice("OK"), _choice(" ")]

        response = client.post(IMPORT, json={"exercises": body}, headers=h)

        assert response.status_code == 422
        error = response.json()
        assert error["error_code"] == "invalid_import"
        assert error["message"] == "2 of 4 exercises cannot be saved"
        rows = error["details"]["rows"]
        assert [(r["index"], r["field"]) for r in rows] == [
            (1, "answer_key.correct_choice_id"),
            (3, "prompt"),
        ]
        assert all(r["message"] for r in rows)
        assert _exercises(client, h) == before

    def test_an_unknown_type_is_reported_on_its_row(self, client: TestClient, h: dict) -> None:
        response = client.post(
            IMPORT, json={"exercises": [{**_choice("x"), "type": "essay"}]}, headers=h
        )

        assert response.status_code == 422
        assert response.json()["details"]["rows"][0]["field"] == "type"

    @pytest.mark.parametrize("count", [0, IMPORT_MAX + 1])
    def test_an_import_holds_1_to_200_exercises(
        self, client: TestClient, h: dict, count: int
    ) -> None:
        response = client.post(
            IMPORT, json={"exercises": [_choice(f"Q{i}") for i in range(count)]}, headers=h
        )

        assert response.status_code == 422
        assert response.json()["details"]["field"] == "exercises"

    def test_200_is_allowed(self, client: TestClient, h: dict) -> None:
        response = client.post(
            IMPORT, json={"exercises": [_choice(f"Q{i}") for i in range(IMPORT_MAX)]}, headers=h
        )
        assert response.status_code == 201

    def test_an_unknown_lesson_is_404(self, client: TestClient, h: dict) -> None:
        response = client.post(
            f"{A}/lessons/nope/exercises/import", json={"exercises": [_choice("x")]}, headers=h
        )
        assert response.status_code == 404

    def test_an_unknown_mode_is_refused(self, client: TestClient, h: dict) -> None:
        response = client.post(
            IMPORT, json={"exercises": [_choice("x")], "mode": "merge"}, headers=h
        )
        assert response.status_code == 422


class TestDryRun:
    def test_checks_and_writes_nothing(self, client: TestClient, h: dict, seeded: Path) -> None:
        before = _exercises(client, h)
        version = _version(seeded)

        response = client.post(
            IMPORT,
            json={"exercises": [_choice("One"), _spell("Two")], "mode": "replace", "dry_run": True},
            headers=h,
        )

        assert response.status_code == 200
        assert response.json() == {"count": 2}
        assert _exercises(client, h) == before
        assert _version(seeded) == version

    def test_reports_the_same_problems(self, client: TestClient, h: dict) -> None:
        response = client.post(
            IMPORT, json={"exercises": [_choice("x", "z")], "dry_run": True}, headers=h
        )

        assert response.status_code == 422
        assert response.json()["details"]["rows"][0]["index"] == 0


class TestAudit:
    def test_one_line_per_exercise_without_content(
        self, client: TestClient, h: dict, caplog: pytest.LogCaptureFixture
    ) -> None:
        old = [e["id"] for e in _exercises(client, h)]
        with caplog.at_level(logging.INFO, logger="app.admin"):
            client.post(IMPORT, json={"exercises": [_choice("x")], "dry_run": True}, headers=h)
            new = client.post(
                IMPORT,
                json={"exercises": [_choice("SECRET-1"), _choice("SECRET-2")], "mode": "replace"},
                headers=h,
            ).json()["exercises"]

        lines = [r.getMessage() for r in caplog.records if r.name == "app.admin"]
        assert lines == [
            *(f"admin_write action=delete entity=exercise id={i} admin={ADMIN}" for i in old),
            *(f"admin_write action=create entity=exercise id={e['id']} admin={ADMIN}" for e in new),
        ]
        assert not any("SECRET" in line for line in lines)
