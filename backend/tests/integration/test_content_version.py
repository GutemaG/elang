"""Integration tests for bolt 008's content-version signal (story
001-content-version-signal), against a real (temp-file) SQLite database --
`SqlAlchemyLessonRepository.get_content_version` /
`list_content_versions_by_skills`.
"""

from __future__ import annotations

from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.infrastructure.db.lesson_models import ExerciseModel, LessonModel, SkillModel
from app.infrastructure.db.lesson_repositories import SqlAlchemyLessonRepository


async def _seed(session: AsyncSession) -> None:
    session.add_all(
        [
            SkillModel(id="s1", title="Greetings & Basics", order_index=1),
            SkillModel(id="s2", title="Food & Drink", order_index=2),
        ]
    )
    session.add_all(
        [
            LessonModel(id="l1", skill_id="s1", title="Hello & Goodbye", order_index=1),
            LessonModel(id="l2", skill_id="s2", title="Coffee & Tea", order_index=1),
        ]
    )
    session.add(
        ExerciseModel(
            id="e1",
            lesson_id="l1",
            order_index=1,
            type="multiple_choice",
            prompt="How do you say 'Hello'?",
            content={"choices": [{"id": "a", "text": "ሰላም"}, {"id": "b", "text": "ደህና"}]},
            answer_key={"correct_choice_id": "a"},
        )
    )
    await session.commit()


class TestGetContentVersion:
    async def test_returns_lesson_updated_at_when_no_exercises(
        self, db_session: AsyncSession
    ) -> None:
        db_session.add(SkillModel(id="s1", title="Greetings & Basics", order_index=1))
        db_session.add(LessonModel(id="l1", skill_id="s1", title="Empty Lesson", order_index=1))
        await db_session.commit()

        repo = SqlAlchemyLessonRepository(db_session)
        version = await repo.get_content_version("l1")

        assert version is not None
        assert version.tzinfo is not None

    async def test_returns_none_for_unknown_lesson(self, db_session: AsyncSession) -> None:
        repo = SqlAlchemyLessonRepository(db_session)
        assert await repo.get_content_version("does-not-exist") is None

    async def test_reflects_the_most_recent_exercise_update(
        self, db_session: AsyncSession
    ) -> None:
        await _seed(db_session)
        repo = SqlAlchemyLessonRepository(db_session)
        version_before = await repo.get_content_version("l1")

        # Mutate the exercise (a real content edit) and force its
        # `updated_at` forward explicitly -- SQLite's clock resolution is
        # too coarse to trust a bare `commit()` alone to advance it within
        # a fast test run.
        exercise = (
            await db_session.execute(select(ExerciseModel).where(ExerciseModel.id == "e1"))
        ).scalar_one()
        exercise.prompt = "How do you say 'Hi'?"
        exercise.updated_at = datetime.now(UTC).replace(microsecond=999999)
        await db_session.commit()

        version_after = await repo.get_content_version("l1")

        assert version_after is not None
        assert version_before is not None
        assert version_after > version_before

    async def test_is_stable_across_repeated_fetches_with_no_change(
        self, db_session: AsyncSession
    ) -> None:
        await _seed(db_session)
        repo = SqlAlchemyLessonRepository(db_session)

        first = await repo.get_content_version("l1")
        second = await repo.get_content_version("l1")

        assert first == second


class TestListContentVersionsBySkills:
    async def test_groups_by_skill_not_by_lesson(self, db_session: AsyncSession) -> None:
        await _seed(db_session)
        repo = SqlAlchemyLessonRepository(db_session)

        versions = await repo.list_content_versions_by_skills(["s1", "s2"])

        assert "s1" in versions
        # s2's lesson (l2) has no exercises but still has its own
        # `updated_at` -- still present with a real value.
        assert "s2" in versions

    async def test_omits_a_skill_with_no_lessons(self, db_session: AsyncSession) -> None:
        await _seed(db_session)
        db_session.add(SkillModel(id="s3", title="Empty Skill", order_index=3))
        await db_session.commit()
        repo = SqlAlchemyLessonRepository(db_session)

        versions = await repo.list_content_versions_by_skills(["s1", "s2", "s3"])

        assert "s3" not in versions

    async def test_returns_empty_dict_for_empty_input(self, db_session: AsyncSession) -> None:
        repo = SqlAlchemyLessonRepository(db_session)
        assert await repo.list_content_versions_by_skills([]) == {}
