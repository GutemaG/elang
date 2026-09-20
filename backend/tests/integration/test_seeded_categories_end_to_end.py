"""End-to-end checks of the real seeded content (bolt `022-category-content-seed`,
story 004): every seeded lesson loads and serializes through the same
mapping the API uses, and a lesson in a new category can be fetched and
completed over HTTP, awarding XP and creating vocab progress.
"""

from __future__ import annotations

import asyncio
import sqlite3
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import pytest
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine

from app.infrastructure.api.exercise_mapping import to_exercise_response
from app.infrastructure.db.lesson_models import CategoryModel, LessonModel, SkillModel
from app.infrastructure.db.lesson_repositories import SqlAlchemyLessonRepository
from app.infrastructure.db.seed_lesson_content import seed
from tests.fakes import FakeTokenVerifier


@pytest.fixture
def seeded_real_content(db_path: Path) -> None:
    """The real seed, applied to the test database before any client opens
    it (own engine, own loop, disposed straight away).
    """

    async def _seed() -> None:
        engine = create_async_engine(f"sqlite+aiosqlite:///{db_path}")
        async with AsyncSession(engine) as session:
            await seed(session)
            await session.commit()
        await engine.dispose()

    asyncio.run(_seed())


class TestEverySeededLessonServes:
    async def test_every_lesson_loads_and_every_exercise_serializes(
        self, db_session: AsyncSession
    ) -> None:
        await seed(db_session)
        await db_session.commit()

        repo = SqlAlchemyLessonRepository(db_session)
        lesson_ids = [m.id for m in (await db_session.execute(select(LessonModel))).scalars()]
        assert len(lesson_ids) == 32

        exercise_total = 0
        for lesson_id in lesson_ids:
            lesson = await repo.get_by_id(lesson_id)
            assert lesson is not None
            for exercise in lesson.exercises:
                # Raises if the stored content/answer key does not fit the
                # exercise type's response model.
                response = to_exercise_response(exercise)
                assert response.id == exercise.id
                exercise_total += 1
        # 143 before bolt 030's gap_fill, 159 before bolt 032's spell_tiles.
        assert exercise_total == 175

    async def test_every_lesson_belongs_to_a_skill_in_a_seeded_category(
        self, db_session: AsyncSession
    ) -> None:
        await seed(db_session)
        await db_session.commit()

        category_ids = {c.id for c in (await db_session.execute(select(CategoryModel))).scalars()}
        skill_category = {
            s.id: s.category_id for s in (await db_session.execute(select(SkillModel))).scalars()
        }
        for lesson in (await db_session.execute(select(LessonModel))).scalars():
            assert skill_category[lesson.skill_id] in category_ids


def _sign_in(make_client: Any) -> tuple[Any, dict[str, str]]:
    client = make_client(FakeTokenVerifier(subject="google-user-1"), FakeTokenVerifier())
    response = client.post("/api/v1/auth/google", json={"id_token": "irrelevant"})
    assert response.status_code == 200
    return client, {"Authorization": f"Bearer {response.json()['session_token']}"}


class TestNewCategoryOverHttp:
    def test_a_new_user_sees_five_categories_each_with_one_active_skill(
        self, make_client: Any, seeded_real_content: None
    ) -> None:
        client, headers = _sign_in(make_client)

        tree = client.get("/api/v1/skill-tree", headers=headers).json()

        assert len(tree["categories"]) == 5
        active_by_category: dict[str, int] = {}
        for skill in tree["skills"]:
            if skill["state"] == "active":
                active_by_category[skill["category_id"]] = (
                    active_by_category.get(skill["category_id"], 0) + 1
                )
        assert sorted(active_by_category.values()) == [1, 1, 1, 1, 1]

    def test_a_new_category_lesson_can_be_fetched_and_completed_creating_vocab_progress(
        self, make_client: Any, seeded_real_content: None, db_path: Path
    ) -> None:
        client, headers = _sign_in(make_client)
        tree = client.get("/api/v1/skill-tree", headers=headers).json()
        categories = {c["title"]: c["id"] for c in tree["categories"]}
        family_first = next(
            s
            for s in tree["skills"]
            if s["category_id"] == categories["Family & People"] and s["state"] == "active"
        )

        lesson = client.get(f"/api/v1/lessons/{family_first['lesson_id']}", headers=headers)
        assert lesson.status_code == 200
        exercises = lesson.json()["exercises"]
        assert {e["type"] for e in exercises} >= {
            "multiple_choice",
            "listening",
            "sentence_construction",
        }

        done = client.post(
            f"/api/v1/lessons/{family_first['lesson_id']}/complete",
            headers=headers,
            json={
                "attempt_id": "attempt-family-1",
                "correct_count": len(exercises),
                "total_count": len(exercises),
                "time_spent_seconds": 30.0,
                "client_completed_at": datetime.now(UTC).isoformat(),
            },
        )
        assert done.status_code == 200, done.text
        assert done.json()["xp_earned"] > 0

        with sqlite3.connect(db_path) as conn:
            vocab_rows = conn.execute("SELECT COUNT(*) FROM user_vocab_progress").fetchone()[0]
        # The lesson has two vocab-linked multiple-choice exercises.
        assert vocab_rows == 2

    def test_finishing_a_skill_unlocks_only_its_own_categorys_next_skill(
        self, make_client: Any, seeded_real_content: None
    ) -> None:
        client, headers = _sign_in(make_client)
        tree = client.get("/api/v1/skill-tree", headers=headers).json()
        categories = {c["title"]: c["id"] for c in tree["categories"]}
        numbers = [s for s in tree["skills"] if s["category_id"] == categories["Numbers & Time"]]
        first, second = numbers[0], numbers[1]
        assert (first["state"], second["state"]) == ("active", "locked")

        # Complete both lessons of the first Numbers skill.
        for _ in range(2):
            current = next(
                s
                for s in client.get("/api/v1/skill-tree", headers=headers).json()["skills"]
                if s["id"] == first["id"]
            )
            lesson = client.get(f"/api/v1/lessons/{current['lesson_id']}", headers=headers).json()
            count = len(lesson["exercises"])
            response = client.post(
                f"/api/v1/lessons/{current['lesson_id']}/complete",
                headers=headers,
                json={
                    "attempt_id": f"attempt-{current['lesson_id']}",
                    "correct_count": count,
                    "total_count": count,
                    "time_spent_seconds": 30.0,
                    "client_completed_at": datetime.now(UTC).isoformat(),
                },
            )
            assert response.status_code == 200, response.text

        states = {
            s["title"]: s["state"]
            for s in client.get("/api/v1/skill-tree", headers=headers).json()["skills"]
        }
        assert states["Numbers"] == "completed"
        assert states["Time"] == "active"
        # Other categories' second skills stay locked.
        assert states["People"] == "locked"
        assert states["Getting There"] == "locked"
        assert states["Body & Health"] == "locked"
        assert states["Food & Drink"] == "locked"

    def test_words_learned_in_a_new_category_appear_in_practice_when_due(
        self, make_client: Any, seeded_real_content: None, db_path: Path
    ) -> None:
        client, headers = _sign_in(make_client)
        tree = client.get("/api/v1/skill-tree", headers=headers).json()
        categories = {c["title"]: c["id"] for c in tree["categories"]}
        first = next(
            s
            for s in tree["skills"]
            if s["category_id"] == categories["Travel & Places"] and s["state"] == "active"
        )
        lesson = client.get(f"/api/v1/lessons/{first['lesson_id']}", headers=headers).json()
        count = len(lesson["exercises"])
        done = client.post(
            f"/api/v1/lessons/{first['lesson_id']}/complete",
            headers=headers,
            json={
                "attempt_id": "attempt-travel-1",
                "correct_count": count,
                "total_count": count,
                "time_spent_seconds": 30.0,
                "client_completed_at": datetime.now(UTC).isoformat(),
            },
        )
        assert done.status_code == 200, done.text
        assert client.get("/api/v1/practice/due-count", headers=headers).json()["due_count"] == 0

        # Time passes: back-date the new rows so they are due.
        with sqlite3.connect(db_path) as conn:
            conn.execute(
                "UPDATE user_vocab_progress SET next_review_at = ?", ("2000-01-01 00:00:00",)
            )

        assert client.get("/api/v1/practice/due-count", headers=headers).json()["due_count"] == 2
        items = client.get("/api/v1/practice/due-items", headers=headers).json()
        assert len(items["items"] if isinstance(items, dict) else items) == 2
