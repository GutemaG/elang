"""Integration tests: the content admin API (stories
003-content-tree-and-crud-api and 004-exercise-write-validation, bolt
035-admin-content-api), over HTTP against a temp SQLite database holding the
real seeded content.
"""

from __future__ import annotations

import asyncio
import logging
import sqlite3
import uuid
from collections.abc import Callable
from pathlib import Path
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine

from app.config import Settings
from app.infrastructure.api import dependencies
from app.infrastructure.api.admin_routers import router as admin_router
from app.infrastructure.db.seed_category_content import PLACEHOLDER_AUDIO_URL
from app.infrastructure.db.seed_lesson_content import CURRICULUM, _content_id, seed
from tests.fakes import EN_AM_COURSE_ID, FakeTokenVerifier

ClientFactory = Callable[[object, object], TestClient]
ADMIN = "admin@example.com"
A = "/api/v1/admin"

GREETINGS_SKILL = _content_id(CURRICULUM[0]["slug"])
GREETINGS_SECTION = _content_id(CURRICULUM[0]["category_slug"])
FIRST_LESSON = _content_id(CURRICULUM[0]["lessons"][0]["slug"])


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


def _add_skill_progress(db: Path, skill_id: str) -> None:
    user_id = _rows(db, "SELECT id FROM users LIMIT 1")[0][0]
    with sqlite3.connect(db) as conn:
        conn.execute(
            "INSERT INTO user_skill_progress (id, user_id, skill_id, unlocked, crown_level, "
            "completed_lesson_ids_this_cycle, created_at) VALUES (?, ?, ?, 1, 0, '[]', "
            "'2026-01-01')",
            (str(uuid.uuid4()), user_id, skill_id),
        )


def _exercise_body(prompt: str = "Pick", answer: str = "a") -> dict[str, Any]:
    return {
        "type": "multiple_choice",
        "prompt": prompt,
        "content": {"choices": [{"id": "a", "text": "A"}, {"id": "b", "text": "B"}]},
        "answer_key": {"correct_choice_id": answer},
    }


class TestAccess:
    ROUTES = [
        (method, route.path.replace("{", "").replace("}", ""))
        for route in admin_router.routes
        for method in route.methods
    ]

    @pytest.mark.parametrize(("method", "path"), ROUTES)
    def test_every_admin_endpoint_refuses_a_non_admin(
        self,
        make_client: ClientFactory,
        seeded: Path,
        monkeypatch: pytest.MonkeyPatch,
        method: str,
        path: str,
    ) -> None:
        monkeypatch.setattr(dependencies, "get_settings", lambda: Settings(admin_emails=ADMIN))
        learner = make_client(
            FakeTokenVerifier(subject="sub-learner", email="learner@example.com"),
            FakeTokenVerifier(),
        )
        token = learner.post("/api/v1/auth/google", json={"id_token": "t"}).json()["session_token"]
        response = learner.request(
            method, path, headers={"Authorization": f"Bearer {token}"}, json={}
        )
        assert response.status_code == 403


class TestTree:
    def test_lists_courses_with_section_counts(self, client: TestClient, h: dict) -> None:
        courses = client.get(f"{A}/courses", headers=h).json()["courses"]
        assert len(courses) == 4
        en_am = next(c for c in courses if c["id"] == EN_AM_COURSE_ID)
        assert en_am["section_count"] > 0

    def test_tree_is_ordered_counted_and_marks_audio(
        self, client: TestClient, h: dict, seeded: Path
    ) -> None:
        tree = client.get(f"{A}/courses/{EN_AM_COURSE_ID}/tree", headers=h).json()

        sections = tree["sections"]
        assert [s["order_index"] for s in sections] == sorted(s["order_index"] for s in sections)
        assert tree["course"]["section_count"] == len(sections)
        for section in sections:
            assert section["skill_count"] == len(section["skills"])
            for skill in section["skills"]:
                assert skill["lesson_count"] == len(skill["lessons"])
                for lesson in skill["lessons"]:
                    assert lesson["exercise_count"] == len(lesson["exercises"])
                    orders = [e["order_index"] for e in lesson["exercises"]]
                    assert orders == sorted(orders)

        exercises = [
            e
            for s in sections
            for k in s["skills"]
            for lesson in k["lessons"]
            for e in lesson["exercises"]
        ]
        seeded_count = _rows(
            seeded,
            "SELECT count(*) FROM exercises e JOIN lessons l ON e.lesson_id = l.id "
            "JOIN skills k ON l.skill_id = k.id JOIN categories c ON k.category_id = c.id "
            "WHERE c.course_id = ?",
            EN_AM_COURSE_ID,
        )[0][0]
        assert len(exercises) == seeded_count
        listening = [e for e in exercises if e["type"] == "listening"]
        assert listening and all(e["audio"] == "placeholder" for e in listening)
        assert all(e["audio"] is None for e in exercises if e["type"] != "listening")

    def test_unknown_course_is_404(self, client: TestClient, h: dict) -> None:
        response = client.get(f"{A}/courses/nope/tree", headers=h)
        assert response.status_code == 404
        assert response.json()["error_code"] == "content_not_found"


class TestCreateAndRename:
    def test_created_content_goes_last_and_reaches_the_learner(
        self, client: TestClient, h: dict
    ) -> None:
        section = client.post(
            f"{A}/courses/{EN_AM_COURSE_ID}/sections",
            json={"title": " New Section ", "subtitle": "Sub"},
            headers=h,
        )
        assert section.status_code == 201
        section = section.json()
        assert uuid.UUID(section["id"]).version == 4
        assert section["title"] == "New Section"
        tree = client.get(f"{A}/courses/{EN_AM_COURSE_ID}/tree", headers=h).json()
        assert tree["sections"][-1]["id"] == section["id"]

        skill = client.post(
            f"{A}/sections/{section['id']}/skills", json={"title": "New Skill"}, headers=h
        ).json()
        lesson = client.post(
            f"{A}/skills/{skill['id']}/lessons", json={"title": "New Lesson"}, headers=h
        ).json()
        exercise = client.post(
            f"{A}/lessons/{lesson['id']}/exercises", json=_exercise_body(), headers=h
        )
        assert exercise.status_code == 201
        assert exercise.json()["order_index"] == 1

        skill_tree = client.get("/api/v1/skill-tree", headers=h).json()
        assert section["id"] in [c["id"] for c in skill_tree["categories"]]
        served = client.get(f"/api/v1/lessons/{lesson['id']}", headers=h)
        assert served.status_code == 200
        assert [e["id"] for e in served.json()["exercises"]] == [exercise.json()["id"]]

    def test_rename_course_section_skill_and_lesson(self, client: TestClient, h: dict) -> None:
        assert (
            client.patch(
                f"{A}/courses/{EN_AM_COURSE_ID}", json={"title": "EN→AM"}, headers=h
            ).json()["title"]
            == "EN→AM"
        )
        section = client.patch(
            f"{A}/sections/{GREETINGS_SECTION}", json={"subtitle": "New sub"}, headers=h
        ).json()
        assert section["subtitle"] == "New sub"
        assert (
            client.patch(f"{A}/skills/{GREETINGS_SKILL}", json={"title": "Hi"}, headers=h).json()[
                "title"
            ]
            == "Hi"
        )
        assert (
            client.patch(f"{A}/lessons/{FIRST_LESSON}", json={"title": "Hey"}, headers=h).json()[
                "title"
            ]
            == "Hey"
        )

    @pytest.mark.parametrize("title", ["", "   "])
    def test_blank_title_is_refused(self, client: TestClient, h: dict, title: str) -> None:
        response = client.patch(f"{A}/skills/{GREETINGS_SKILL}", json={"title": title}, headers=h)
        assert response.status_code == 422
        assert response.json()["details"] == {"field": "title"}

    def test_there_is_no_course_create_or_delete(self, client: TestClient, h: dict) -> None:
        assert client.post(f"{A}/courses", json={}, headers=h).status_code == 405
        assert client.delete(f"{A}/courses/{EN_AM_COURSE_ID}", headers=h).status_code == 405

    def test_create_under_a_missing_parent_is_404(self, client: TestClient, h: dict) -> None:
        response = client.post(f"{A}/sections/nope/skills", json={"title": "x"}, headers=h)
        assert response.status_code == 404


class TestReorder:
    def _section_ids(self, client: TestClient, h: dict) -> list[str]:
        tree = client.get(f"{A}/courses/{EN_AM_COURSE_ID}/tree", headers=h).json()
        return [s["id"] for s in tree["sections"]]

    def test_reorder_applies_the_new_order(self, client: TestClient, h: dict) -> None:
        ids = self._section_ids(client, h)
        new_order = list(reversed(ids))

        response = client.put(
            f"{A}/courses/{EN_AM_COURSE_ID}/sections/order", json={"ids": new_order}, headers=h
        )

        assert response.status_code == 200
        assert [i["order_index"] for i in response.json()["items"]] == list(range(1, len(ids) + 1))
        assert self._section_ids(client, h) == new_order

    @pytest.mark.parametrize("change", ["missing", "extra", "duplicate"])
    def test_a_wrong_id_list_changes_nothing(
        self, client: TestClient, h: dict, change: str
    ) -> None:
        ids = self._section_ids(client, h)
        bad = {
            "missing": ids[1:],
            "extra": [*ids, "not-a-child"],
            "duplicate": [ids[0], *ids[:-1]],
        }[change]

        response = client.put(
            f"{A}/courses/{EN_AM_COURSE_ID}/sections/order", json={"ids": bad}, headers=h
        )

        assert response.status_code == 422
        assert response.json()["error_code"] == "invalid_order"
        assert self._section_ids(client, h) == ids

    def test_reorder_lessons_and_exercises(self, client: TestClient, h: dict) -> None:
        lessons = client.get(f"{A}/courses/{EN_AM_COURSE_ID}/tree", headers=h).json()
        skill = lessons["sections"][0]["skills"][0]
        lesson_ids = [lesson["id"] for lesson in skill["lessons"]]
        response = client.put(
            f"{A}/skills/{skill['id']}/lessons/order",
            json={"ids": list(reversed(lesson_ids))},
            headers=h,
        )
        assert response.status_code == 200

        exercises = client.get(f"{A}/lessons/{FIRST_LESSON}/exercises", headers=h).json()
        ids = [e["id"] for e in exercises["exercises"]]
        response = client.put(
            f"{A}/lessons/{FIRST_LESSON}/exercises/order",
            json={"ids": [ids[-1], *ids[:-1]]},
            headers=h,
        )
        assert response.status_code == 200
        served = client.get(f"/api/v1/lessons/{FIRST_LESSON}", headers=h).json()
        assert [e["id"] for e in served["exercises"]] == [ids[-1], *ids[:-1]]


class TestDelete:
    def test_content_with_learner_history_is_refused(
        self, client: TestClient, h: dict, seeded: Path
    ) -> None:
        _add_skill_progress(seeded, GREETINGS_SKILL)

        for path in (
            f"{A}/sections/{GREETINGS_SECTION}?confirm=true",
            f"{A}/skills/{GREETINGS_SKILL}?confirm=true",
        ):
            response = client.delete(path, headers=h)
            assert response.status_code == 409
            assert response.json()["error_code"] == "content_in_use"
            assert response.json()["details"]["learners"] == 1
        assert _rows(seeded, "SELECT count(*) FROM skills WHERE id = ?", GREETINGS_SKILL) == [(1,)]

    def test_lesson_with_an_attempt_is_refused(
        self, client: TestClient, h: dict, seeded: Path
    ) -> None:
        user_id = _rows(seeded, "SELECT id FROM users LIMIT 1")[0][0]
        with sqlite3.connect(seeded) as conn:
            conn.execute(
                "INSERT INTO lesson_attempts (id, user_id, lesson_id, correct_count, "
                "total_count, xp_awarded, completed_at, result, created_at) VALUES ('att-1', ?, "
                "?, 1, 1, 10, '2026-01-01', '{}', '2026-01-01')",
                (user_id, FIRST_LESSON),
            )
        response = client.delete(f"{A}/lessons/{FIRST_LESSON}?confirm=true", headers=h)
        assert response.status_code == 409
        assert response.json()["details"]["learners"] == 1

    def test_unused_content_needs_confirmation_then_goes_entirely(
        self, client: TestClient, h: dict, seeded: Path
    ) -> None:
        lesson_ids = [lesson["slug"] for lesson in CURRICULUM[0]["lessons"]]
        exercise_total = sum(len(lesson["exercises"]) for lesson in CURRICULUM[0]["lessons"])

        first = client.delete(f"{A}/skills/{GREETINGS_SKILL}", headers=h)
        assert first.status_code == 409
        assert first.json()["error_code"] == "confirmation_required"
        assert first.json()["details"] == {
            "skills": 0,
            "lessons": len(lesson_ids),
            "exercises": exercise_total,
        }

        second = client.delete(f"{A}/skills/{GREETINGS_SKILL}?confirm=true", headers=h)

        assert second.status_code == 204
        assert _rows(seeded, "SELECT count(*) FROM skills WHERE id = ?", GREETINGS_SKILL) == [(0,)]
        lesson_rows = _rows(
            seeded,
            f"SELECT count(*) FROM lessons WHERE id IN ({','.join('?' * len(lesson_ids))})",
            *[_content_id(slug) for slug in lesson_ids],
        )
        assert lesson_rows == [(0,)]
        # Siblings left in the section are renumbered 1..n.
        orders = [
            r[0]
            for r in _rows(
                seeded,
                "SELECT order_index FROM skills WHERE category_id = ? ORDER BY order_index",
                GREETINGS_SECTION,
            )
        ]
        assert orders == list(range(1, len(orders) + 1))

    def test_deleting_a_section_removes_its_skills(
        self, client: TestClient, h: dict, seeded: Path
    ) -> None:
        response = client.delete(f"{A}/sections/{GREETINGS_SECTION}?confirm=true", headers=h)
        assert response.status_code == 204
        assert _rows(
            seeded, "SELECT count(*) FROM skills WHERE category_id = ?", GREETINGS_SECTION
        ) == [(0,)]
        orders = [
            r[0]
            for r in _rows(
                seeded,
                "SELECT order_index FROM categories WHERE course_id = ? ORDER BY order_index",
                EN_AM_COURSE_ID,
            )
        ]
        assert orders == list(range(1, len(orders) + 1))

    def test_deleting_an_exercise_needs_no_confirmation(self, client: TestClient, h: dict) -> None:
        ids = [
            e["id"]
            for e in client.get(f"{A}/lessons/{FIRST_LESSON}/exercises", headers=h).json()[
                "exercises"
            ]
        ]
        assert client.delete(f"{A}/exercises/{ids[0]}", headers=h).status_code == 204
        remaining = client.get(f"{A}/lessons/{FIRST_LESSON}/exercises", headers=h).json()
        assert [e["id"] for e in remaining["exercises"]] == ids[1:]
        assert [e["order_index"] for e in remaining["exercises"]] == list(range(1, len(ids)))


class TestExerciseWrites:
    def _all_seeded(self, client: TestClient, h: dict) -> list[dict[str, Any]]:
        tree = client.get(f"{A}/courses/{EN_AM_COURSE_ID}/tree", headers=h).json()
        lesson_ids = [
            lesson["id"] for s in tree["sections"] for k in s["skills"] for lesson in k["lessons"]
        ]
        return [
            e
            for lesson_id in lesson_ids
            for e in client.get(f"{A}/lessons/{lesson_id}/exercises", headers=h).json()["exercises"]
        ]

    def test_every_seeded_exercise_saves_back_unchanged(
        self, client: TestClient, h: dict, seeded: Path
    ) -> None:
        exercises = self._all_seeded(client, h)
        assert {e["type"] for e in exercises} == {
            "multiple_choice",
            "listening",
            "sentence_construction",
            "match_pairs",
            "gap_fill",
            "spell_tiles",
        }
        before = _rows(seeded, "SELECT id, prompt, content, answer_key FROM exercises ORDER BY id")

        for e in exercises:
            response = client.put(
                f"{A}/exercises/{e['id']}",
                json={k: e[k] for k in ("type", "prompt", "content", "answer_key")},
                headers=h,
            )
            assert response.status_code == 200, (e["id"], response.json())

        after = _rows(seeded, "SELECT id, prompt, content, answer_key FROM exercises ORDER BY id")
        assert after == before

    def test_a_bad_exercise_is_refused_naming_the_field(self, client: TestClient, h: dict) -> None:
        response = client.post(
            f"{A}/lessons/{FIRST_LESSON}/exercises", json=_exercise_body(answer="z"), headers=h
        )
        assert response.status_code == 422
        assert response.json()["error_code"] == "invalid_exercise"
        assert response.json()["details"] == {"field": "answer_key.correct_choice_id"}

    def test_type_cannot_change(self, client: TestClient, h: dict) -> None:
        listening = next(e for e in self._all_seeded(client, h) if e["type"] == "listening")
        response = client.put(f"{A}/exercises/{listening['id']}", json=_exercise_body(), headers=h)
        assert response.status_code == 422
        assert response.json()["details"] == {"field": "type"}

    def test_attaching_hosted_audio(self, client: TestClient, h: dict) -> None:
        listening = next(e for e in self._all_seeded(client, h) if e["type"] == "listening")
        assert listening["content"]["audio_url"] == PLACEHOLDER_AUDIO_URL
        body = {k: listening[k] for k in ("type", "prompt", "content", "answer_key")}
        body["content"] = {**body["content"], "audio_url": "https://cdn.example/am/hello.m4a"}

        assert (
            client.put(f"{A}/exercises/{listening['id']}", json=body, headers=h).status_code == 200
        )
        body["content"]["audio_url"] = "http://cdn.example/am/hello.m4a"
        refused = client.put(f"{A}/exercises/{listening['id']}", json=body, headers=h)
        assert refused.status_code == 422
        assert refused.json()["details"] == {"field": "content.audio_url"}

    def test_unknown_exercise_is_404(self, client: TestClient, h: dict) -> None:
        assert (
            client.put(f"{A}/exercises/nope", json=_exercise_body(), headers=h).status_code == 404
        )
        assert client.delete(f"{A}/exercises/nope", headers=h).status_code == 404


class TestContentVersion:
    """Offline copies refetch when `content_version` moves (bolt 008)."""

    def _version(self, db: Path) -> str:
        return _rows(db, "SELECT updated_at FROM lessons WHERE id = ?", FIRST_LESSON)[0][0]

    def _exercise_ids(self, client: TestClient, h: dict) -> list[str]:
        body = client.get(f"{A}/lessons/{FIRST_LESSON}/exercises", headers=h).json()
        return [e["id"] for e in body["exercises"]]

    def test_create_moves_it(self, client: TestClient, h: dict, seeded: Path) -> None:
        before = self._version(seeded)
        client.post(f"{A}/lessons/{FIRST_LESSON}/exercises", json=_exercise_body(), headers=h)
        assert self._version(seeded) > before

    def test_delete_moves_it(self, client: TestClient, h: dict, seeded: Path) -> None:
        before = self._version(seeded)
        client.delete(f"{A}/exercises/{self._exercise_ids(client, h)[-1]}", headers=h)
        assert self._version(seeded) > before

    def test_reorder_moves_it(self, client: TestClient, h: dict, seeded: Path) -> None:
        ids = self._exercise_ids(client, h)
        before = self._version(seeded)
        client.put(
            f"{A}/lessons/{FIRST_LESSON}/exercises/order",
            json={"ids": list(reversed(ids))},
            headers=h,
        )
        assert self._version(seeded) > before


class TestAudit:
    def test_each_write_logs_one_line_without_content(
        self, client: TestClient, h: dict, caplog: pytest.LogCaptureFixture
    ) -> None:
        with caplog.at_level(logging.INFO, logger="app.admin"):
            created = client.post(
                f"{A}/lessons/{FIRST_LESSON}/exercises",
                json=_exercise_body(prompt="SECRET-PROMPT-TEXT"),
                headers=h,
            ).json()
            client.patch(f"{A}/skills/{GREETINGS_SKILL}", json={"title": "T"}, headers=h)
            client.get(f"{A}/courses", headers=h)  # a read: no line

        lines = [r.getMessage() for r in caplog.records if r.name == "app.admin"]
        assert lines == [
            f"admin_write action=create entity=exercise id={created['id']} admin={ADMIN}",
            f"admin_write action=update entity=skill id={GREETINGS_SKILL} admin={ADMIN}",
        ]
        assert not any("SECRET-PROMPT-TEXT" in line for line in lines)

    def test_a_refused_write_logs_nothing(
        self, client: TestClient, h: dict, caplog: pytest.LogCaptureFixture
    ) -> None:
        with caplog.at_level(logging.INFO, logger="app.admin"):
            client.post(
                f"{A}/lessons/{FIRST_LESSON}/exercises", json=_exercise_body(answer="z"), headers=h
            )
        assert [r for r in caplog.records if r.name == "app.admin"] == []
