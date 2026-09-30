"""Query-count checks for bolt `059-stat-pill-service` (NFR-3): the streak
history makes the same number of queries for any range and any number of
attempts, and the Amole history makes one. Counted with a SQLAlchemy
`before_cursor_execute` listener, as in `test_lesson_performance.py`.
"""

from __future__ import annotations

from collections.abc import Generator
from datetime import UTC, date, datetime, timedelta
from typing import Any

import pytest
from sqlalchemy import event
from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession

from app.application.stat_use_cases import get_amole_history, get_streak_history
from app.infrastructure.db.lesson_models import AmoleTransactionModel, LessonAttemptModel
from app.infrastructure.db.lesson_repositories import (
    SqlAlchemyAmoleTransactionRepository,
    SqlAlchemyLessonAttemptRepository,
    SqlAlchemyUserStreakRepository,
)

USER = "user-1"
END = date(2026, 9, 30)


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


async def _seed_attempts(session: AsyncSession, count: int, prefix: str = "a") -> None:
    start = datetime(2026, 9, 30, 12, tzinfo=UTC)
    session.add_all(
        LessonAttemptModel(
            id=f"{prefix}{n}",
            user_id=USER,
            lesson_id="lesson-1",
            correct_count=1,
            total_count=1,
            xp_awarded=10,
            completed_at=start - timedelta(days=n),
            result={"is_review": n % 7 == 0},
        )
        for n in range(count)
    )
    await session.commit()


async def _count_streak_queries(
    session: AsyncSession, query_log: list[str], range_days: int
) -> int:
    query_log.clear()
    await get_streak_history(
        USER,
        date(2026, 1, 1),
        END - timedelta(days=range_days - 1),
        END,
        SqlAlchemyLessonAttemptRepository(session),
        SqlAlchemyUserStreakRepository(session),
    )
    return len(query_log)


class TestStreakHistoryQueryCount:
    async def test_the_same_for_a_one_day_and_a_186_day_range(
        self, db_session: AsyncSession, query_log: list[str]
    ) -> None:
        await _seed_attempts(db_session, 30)

        one_day = await _count_streak_queries(db_session, query_log, 1)
        half_year = await _count_streak_queries(db_session, query_log, 186)

        assert one_day == half_year == 2

    async def test_the_same_for_1_or_200_attempts(
        self, db_session: AsyncSession, query_log: list[str]
    ) -> None:
        await _seed_attempts(db_session, 1)
        few = await _count_streak_queries(db_session, query_log, 186)

        await _seed_attempts(db_session, 200, prefix="b")
        many = await _count_streak_queries(db_session, query_log, 186)

        assert few == many == 2


class TestAmoleHistoryQueryCount:
    async def test_one_query(self, db_session: AsyncSession, query_log: list[str]) -> None:
        db_session.add_all(
            AmoleTransactionModel(
                id=f"t{n}",
                user_id=USER,
                amount=10,
                source="lesson_completion",
                reference_id=f"ref-{n}",
                created_at=datetime(2026, 9, 30, 12, tzinfo=UTC) - timedelta(minutes=n),
            )
            for n in range(40)
        )
        await db_session.commit()
        query_log.clear()

        entries = await get_amole_history(
            USER, 20, SqlAlchemyAmoleTransactionRepository(db_session)
        )

        assert len(entries) == 20
        assert len(query_log) == 1
