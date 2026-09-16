"""Unit tests for `StreakPolicy` (bolt 005): daily-streak increment,
reset, and freeze-protected gap handling. Calendar day = UTC throughout
(Technical Design Decision 5).
"""

from __future__ import annotations

from datetime import date

from app.domain.lesson.entities import UserStreak
from app.domain.lesson.services import StreakPolicy


def _streak(current: int, last_completed: date | None, freezes: int = 0) -> UserStreak:
    return UserStreak(
        user_id="u1",
        current_streak=current,
        last_completed_date=last_completed,
        active_freeze_count=freezes,
    )


class TestEvaluate:
    def test_brand_new_streak_starts_at_one(self) -> None:
        result = StreakPolicy().evaluate(_streak(0, None), date(2026, 9, 16))

        assert result.new_streak_count == 1
        assert result.increased_today is True
        assert result.freeze_consumed is False

    def test_same_day_completion_does_not_increment_again(self) -> None:
        today = date(2026, 9, 16)
        result = StreakPolicy().evaluate(_streak(3, today), today)

        assert result.new_streak_count == 3
        assert result.increased_today is False

    def test_next_day_completion_increments_by_one(self) -> None:
        result = StreakPolicy().evaluate(_streak(3, date(2026, 9, 15)), date(2026, 9, 16))

        assert result.new_streak_count == 4
        assert result.increased_today is True
        assert result.freeze_consumed is False

    def test_one_missed_day_with_a_freeze_available_continues_the_streak(self) -> None:
        # last completed 2 days ago -- exactly one full day missed.
        result = StreakPolicy().evaluate(
            _streak(5, date(2026, 9, 14), freezes=1), date(2026, 9, 16)
        )

        assert result.new_streak_count == 6
        assert result.freeze_consumed is True
        assert result.increased_today is True

    def test_one_missed_day_with_no_freeze_available_resets_to_one(self) -> None:
        result = StreakPolicy().evaluate(
            _streak(5, date(2026, 9, 14), freezes=0), date(2026, 9, 16)
        )

        assert result.new_streak_count == 1
        assert result.freeze_consumed is False

    def test_two_or_more_missed_days_resets_even_with_a_freeze_available(self) -> None:
        # A freeze covers exactly one missed day, not two.
        result = StreakPolicy().evaluate(
            _streak(5, date(2026, 9, 10), freezes=1), date(2026, 9, 16)
        )

        assert result.new_streak_count == 1
        assert result.freeze_consumed is False

    def test_a_completion_date_before_last_completed_is_treated_as_same_day(self) -> None:
        # Clock/replay oddity -- never decrement or double-count.
        result = StreakPolicy().evaluate(_streak(3, date(2026, 9, 16)), date(2026, 9, 15))

        assert result.new_streak_count == 3
        assert result.increased_today is False
