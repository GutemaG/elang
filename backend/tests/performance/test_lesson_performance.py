"""Performance tests for the "no per-exercise / per-skill round trip" NFRs
(`system-context.md`, `ddd-02-technical-design.md`'s NFR Implementation).

Rather than a wall-clock smoke test, these assert the precise thing the NFR
actually requires: the number of SQL statements executed stays a small
constant regardless of how many exercises/skills exist, by counting queries
via a SQLAlchemy `before_cursor_execute` event -- a direct, deterministic
check instead of a timing-based proxy.
"""

from __future__ import annotations

from collections.abc import Generator
from datetime import UTC, datetime
from typing import Any

import pytest
from sqlalchemy import event
from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession

from app.application.lesson_use_cases import get_skill_tree
from app.infrastructure.db.lesson_models import ExerciseModel, LessonModel, SkillModel
from app.infrastructure.db.lesson_repositories import (
    SqlAlchemyLessonAttemptRepository,
    SqlAlchemyLessonRepository,
    SqlAlchemySkillRepository,
    SqlAlchemyUserBeansRepository,
    SqlAlchemyUserSkillProgressRepository,
    SqlAlchemyUserStreakRepository,
)


@pytest.fixture
def query_log(async_engine: AsyncEngine) -> Generator[list[str]]:
    queries: list[str] = []

    def _on_execute(
        conn: Any, cursor: Any, statement: str, parameters: Any, context: Any, executemany: Any
    ) -> None:
        queries.append(statement)

    event.listen(async_engine.sync_engine, "before_cursor_execute", _on_execute)
    try:
        yield queries
    finally:
        event.remove(async_engine.sync_engine, "before_cursor_execute", _on_execute)


class TestLessonContentQueryCount:
    async def test_fetching_a_lesson_uses_a_constant_number_of_queries_regardless_of_exercise_count(
        self, db_session: AsyncSession, query_log: list[str]
    ) -> None:
        db_session.add(SkillModel(id="s1", title="Big Lesson Skill", order_index=1))
        db_session.add(LessonModel(id="l1", skill_id="s1", title="Many Exercises", order_index=1))
        db_session.add_all(
            [
                ExerciseModel(
                    id=f"e{i}",
                    lesson_id="l1",
                    order_index=i,
                    type="multiple_choice",
                    prompt=f"Prompt {i}",
                    content={
                        "choices": [
                            {"id": "a", "text": "ሰላም"},
                            {"id": "b", "text": "ደህና ሁን"},
                        ]
                    },
                    answer_key={"correct_choice_id": "a"},
                )
                for i in range(1, 21)
            ]
        )
        await db_session.commit()
        query_log.clear()  # only count queries from the repository call below

        repo = SqlAlchemyLessonRepository(db_session)
        lesson = await repo.get_by_id("l1")

        assert lesson is not None
        assert len(lesson.exercises) == 20
        # selectinload issues exactly 2 statements (the lesson, then its
        # exercises in one batched query) -- never N+1 per exercise.
        assert len(query_log) <= 2


class TestSkillTreeQueryCount:
    async def test_skill_tree_uses_a_constant_number_of_queries_regardless_of_skill_count(
        self, db_session: AsyncSession, query_log: list[str]
    ) -> None:
        db_session.add_all(
            [SkillModel(id=f"s{i}", title=f"Skill {i}", order_index=i) for i in range(1, 51)]
        )
        await db_session.commit()
        query_log.clear()

        skill_repo = SqlAlchemySkillRepository(db_session)
        progress_repo = SqlAlchemyUserSkillProgressRepository(db_session)
        beans_repo = SqlAlchemyUserBeansRepository(db_session)
        streak_repo = SqlAlchemyUserStreakRepository(db_session)
        attempt_repo = SqlAlchemyLessonAttemptRepository(db_session)
        lesson_repo = SqlAlchemyLessonRepository(db_session)
        summary = await get_skill_tree(
            "user-x",
            skill_repo,
            progress_repo,
            beans_repo,
            streak_repo,
            attempt_repo,
            lesson_repo,
            datetime.now(UTC),
        )

        assert len(summary.entries) == 50
        # A small constant number of queries (skills, progress, beans,
        # streak, lifetime-XP sum, grouped next-lesson-per-skill) -- never
        # one per skill (bolt 005 added 3 more constant queries on top of
        # bolt 004's original 2; bolt 007 added 1 more, grouped rather than
        # per-skill, to avoid a real N+1).
        assert len(query_log) <= 6
