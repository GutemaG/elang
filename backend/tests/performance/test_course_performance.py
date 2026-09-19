"""Query-count tests for bolt `024-courses-service` (NFR-2): the course list,
the course-scoped skill tree and the course-scoped Practice queries stay a
small constant number of SQL statements regardless of how many courses,
categories, skills or vocab items exist -- counted via a SQLAlchemy
`before_cursor_execute` event, same approach as `test_lesson_performance.py`.
"""

from __future__ import annotations

from collections.abc import Generator
from datetime import UTC, datetime
from typing import Any

import pytest
from sqlalchemy import event
from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession

from app.application.course_use_cases import list_courses
from app.application.lesson_use_cases import get_due_count, get_skill_tree
from app.domain.entities import User
from app.domain.value_objects import (
    AuthProvider,
    DailyXPTarget,
    LanguageCode,
    ProviderIdentity,
)
from app.infrastructure.db.lesson_models import (
    CategoryModel,
    CourseModel,
    SkillModel,
)
from app.infrastructure.db.lesson_repositories import (
    SqlAlchemyCategoryRepository,
    SqlAlchemyCourseRepository,
    SqlAlchemyLessonAttemptRepository,
    SqlAlchemyLessonRepository,
    SqlAlchemySkillRepository,
    SqlAlchemyUserBeansRepository,
    SqlAlchemyUserSkillProgressRepository,
    SqlAlchemyUserStreakRepository,
    SqlAlchemyUserVocabProgressRepository,
)
from tests.fakes import EN_AM_COURSE_ID


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


def _user() -> User:
    return User(
        id="user-x",
        provider_identity=ProviderIdentity(AuthProvider.GOOGLE, "sub-x"),
        selected_language=LanguageCode(code="am"),
        daily_xp_target=DailyXPTarget(xp_per_day=40),
        notification_enabled=True,
        created_at=datetime.now(UTC),
        active_course_id=EN_AM_COURSE_ID,
    )


async def _add_courses(db_session: AsyncSession, count: int) -> None:
    # Courses need unique language pairs; use synthetic codes (no CHECK on the
    # code set) so many can exist at once.
    db_session.add_all(
        [
            CourseModel(
                id=f"course-{i}",
                learning_language=f"l{i}",
                from_language="en",
                title=f"Course {i}",
                status="available",
                order_index=100 + i,
            )
            for i in range(count)
        ]
    )
    await db_session.commit()


class TestCourseListQueryCount:
    async def test_the_course_list_uses_three_queries_regardless_of_course_count(
        self, db_session: AsyncSession, query_log: list[str]
    ) -> None:
        await _add_courses(db_session, 30)
        query_log.clear()

        result = await list_courses(_user(), SqlAlchemyCourseRepository(db_session))

        assert len(result.courses) == 31  # 30 plus English to Amharic
        assert len(query_log) == 3


class TestCourseScopedSkillTreeQueryCount:
    async def test_the_skill_tree_stays_constant_across_many_courses_categories_and_skills(
        self, db_session: AsyncSession, query_log: list[str]
    ) -> None:
        await _add_courses(db_session, 5)
        for course_index, course_id in enumerate([EN_AM_COURSE_ID, "course-0", "course-1"]):
            for cat in range(1, 6):
                cat_id = f"cat-{course_index}-{cat}"
                db_session.add(
                    CategoryModel(
                        id=cat_id,
                        course_id=course_id,
                        title=cat_id,
                        subtitle="s",
                        order_index=cat,
                    )
                )
                db_session.add_all(
                    [
                        SkillModel(
                            id=f"{cat_id}-s{n}",
                            category_id=cat_id,
                            title="s",
                            order_index=n,
                        )
                        for n in range(1, 5)
                    ]
                )
        await db_session.commit()
        query_log.clear()

        summary = await get_skill_tree(
            "user-x",
            SqlAlchemySkillRepository(db_session),
            SqlAlchemyUserSkillProgressRepository(db_session),
            SqlAlchemyUserBeansRepository(db_session),
            SqlAlchemyUserStreakRepository(db_session),
            SqlAlchemyLessonAttemptRepository(db_session),
            SqlAlchemyLessonRepository(db_session),
            SqlAlchemyCategoryRepository(db_session),
            datetime.now(UTC),
            course_repo=SqlAlchemyCourseRepository(db_session),
            active_course_id=EN_AM_COURSE_ID,
        )

        assert len(summary.categories) == 5
        assert len(summary.entries) == 20
        assert summary.course is not None and summary.course.id == EN_AM_COURSE_ID
        # The nine of `test_lesson_performance` (bolt 021) plus one for the
        # course row -- not one per course, category or skill.
        assert len(query_log) <= 10


class TestCourseScopedPracticeQueryCount:
    async def test_due_count_is_a_single_query_even_when_scoped_to_a_course(
        self, db_session: AsyncSession, query_log: list[str]
    ) -> None:
        query_log.clear()

        count = await get_due_count(
            "user-x",
            SqlAlchemyUserVocabProgressRepository(db_session),
            datetime.now(UTC),
            course_id=EN_AM_COURSE_ID,
        )

        assert count == 0
        assert len(query_log) == 1
