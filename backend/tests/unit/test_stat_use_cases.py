"""Unit tests for bolt `059-stat-pill-service`: `longest_streak`, and the
streak-history and Amole-history reads over in-memory fakes.
"""

from __future__ import annotations

from datetime import UTC, date, datetime, timedelta

import pytest

from app.application.stat_use_cases import (
    STREAK_HISTORY_MAX_DAYS,
    StreakHistory,
    get_amole_history,
    get_streak_history,
)
from app.domain.lesson.entities import AmoleTransaction, LessonAttempt, UserStreak
from app.domain.lesson.exceptions import InvalidRangeError
from app.domain.lesson.services import longest_streak
from app.domain.lesson.value_objects import LessonCompletionOutcome
from tests.fakes import (
    FakeAmoleTransactionRepository,
    FakeLessonAttemptRepository,
    FakeUserStreakRepository,
)

USER = "user-1"
JOINED = date(2026, 3, 14)


def _day(n: int) -> date:
    """`n` days into September 2026."""
    return date(2026, 9, n)


def _attempt(
    attempt_id: str,
    day: date,
    *,
    user_id: str = USER,
    hour: int = 12,
    is_review: bool = False,
) -> LessonAttempt:
    return LessonAttempt(
        id=attempt_id,
        user_id=user_id,
        lesson_id="lesson-1",
        correct_count=3,
        total_count=4,
        xp_awarded=0 if is_review else 30,
        completed_at=datetime(day.year, day.month, day.day, hour, tzinfo=UTC),
        outcome=LessonCompletionOutcome(
            xp_awarded=0 if is_review else 30,
            daily_xp_total=30,
            daily_xp_target=20,
            streak_count=1,
            streak_increased_today=not is_review,
            accuracy_percent=75,
            correct_count=3,
            total_count=4,
            time_spent_seconds=60.0,
            is_review=is_review,
        ),
    )


def _streak(current: int) -> UserStreak:
    return UserStreak(
        user_id=USER,
        current_streak=current,
        last_completed_date=_day(29),
        active_freeze_count=0,
    )


class TestLongestStreak:
    def test_no_days_is_zero(self) -> None:
        assert longest_streak([]) == 0

    def test_one_day_is_one(self) -> None:
        assert longest_streak([_day(3)]) == 1

    def test_the_longest_run_wins_across_gaps(self) -> None:
        days = [_day(1), _day(2), _day(4), _day(5), _day(6), _day(9)]
        assert longest_streak(days) == 3

    def test_order_and_repeats_do_not_matter(self) -> None:
        assert longest_streak([_day(6), _day(4), _day(5), _day(5), _day(4)]) == 3

    def test_a_run_across_a_month_end(self) -> None:
        assert longest_streak([date(2026, 8, 31), _day(1), _day(2)]) == 3


class TestGetStreakHistory:
    async def _history(
        self,
        attempts: list[LessonAttempt],
        start: date = _day(1),
        end: date = _day(30),
        streak: UserStreak | None = None,
    ) -> StreakHistory:
        return await get_streak_history(
            USER,
            JOINED,
            start,
            end,
            FakeLessonAttemptRepository(attempts),
            FakeUserStreakRepository([streak] if streak else []),
        )

    async def test_practised_days_in_the_range_sorted_once_each(self) -> None:
        history = await self._history(
            [
                _attempt("a", _day(20)),
                _attempt("b", _day(18)),
                _attempt("c", _day(18), hour=20),
                _attempt("d", date(2026, 8, 30)),
            ],
            start=_day(1),
            end=_day(30),
        )

        assert history.practised_days == [_day(18), _day(20)]
        assert history.start == _day(1)
        assert history.end == _day(30)
        assert history.joined_on == JOINED

    async def test_a_review_only_day_is_not_practised(self) -> None:
        history = await self._history(
            [_attempt("a", _day(10)), _attempt("r", _day(11), is_review=True)]
        )

        assert history.practised_days == [_day(10)]

    async def test_a_review_beside_a_lesson_keeps_the_day(self) -> None:
        history = await self._history(
            [_attempt("r", _day(11), is_review=True), _attempt("a", _day(11), hour=18)]
        )

        assert history.practised_days == [_day(11)]

    async def test_other_learners_rows_are_left_out(self) -> None:
        history = await self._history(
            [_attempt("a", _day(10)), _attempt("x", _day(12), user_id="someone-else")]
        )

        assert history.practised_days == [_day(10)]

    async def test_the_longest_run_counts_days_outside_the_range(self) -> None:
        history = await self._history(
            [_attempt(f"a{n}", _day(n)) for n in range(1, 6)] + [_attempt("b", _day(20))],
            start=_day(15),
            end=_day(30),
            streak=_streak(1),
        )

        assert history.practised_days == [_day(20)]
        assert history.longest_streak == 5
        assert history.current_streak == 1

    async def test_the_longest_is_never_less_than_the_current(self) -> None:
        history = await self._history([_attempt("a", _day(29))], streak=_streak(4))

        assert history.current_streak == 4
        assert history.longest_streak == 4

    async def test_a_learner_with_nothing_gets_empty_and_zeros(self) -> None:
        history = await self._history([])

        assert history.practised_days == []
        assert history.current_streak == 0
        assert history.longest_streak == 0

    async def test_a_single_day_range_works(self) -> None:
        history = await self._history([_attempt("a", _day(7))], start=_day(7), end=_day(7))

        assert history.practised_days == [_day(7)]

    async def test_the_longest_allowed_range_works(self) -> None:
        end = _day(30)
        start = end - timedelta(days=STREAK_HISTORY_MAX_DAYS - 1)

        history = await self._history([], start=start, end=end)

        assert history.practised_days == []

    async def test_a_range_one_day_too_long_is_rejected(self) -> None:
        end = _day(30)
        start = end - timedelta(days=STREAK_HISTORY_MAX_DAYS)

        with pytest.raises(InvalidRangeError):
            await self._history([], start=start, end=end)

    async def test_a_backwards_range_is_rejected(self) -> None:
        with pytest.raises(InvalidRangeError):
            await self._history([], start=_day(10), end=_day(9))


class TestGetAmoleHistory:
    @staticmethod
    def _entry(entry_id: str, minute: int, amount: int, user_id: str = USER) -> AmoleTransaction:
        return AmoleTransaction(
            id=entry_id,
            user_id=user_id,
            amount=amount,
            source="lesson_completion",
            reference_id=f"ref-{entry_id}",
            created_at=datetime(2026, 9, 30, 12, minute, tzinfo=UTC),
        )

    async def test_newest_first_up_to_the_limit(self) -> None:
        repo = FakeAmoleTransactionRepository([self._entry(f"e{n}", n, 10) for n in range(5)])

        entries = await get_amole_history(USER, 3, repo)

        assert [e.id for e in entries] == ["e4", "e3", "e2"]

    async def test_only_the_learners_own_entries(self) -> None:
        repo = FakeAmoleTransactionRepository(
            [self._entry("mine", 1, 10), self._entry("theirs", 2, 10, user_id="other")]
        )

        entries = await get_amole_history(USER, 20, repo)

        assert [e.id for e in entries] == ["mine"]

    async def test_no_entries_is_empty(self) -> None:
        assert await get_amole_history(USER, 20, FakeAmoleTransactionRepository()) == []
