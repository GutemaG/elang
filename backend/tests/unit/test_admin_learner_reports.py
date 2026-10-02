"""Unit tests: how the admin reports split time into days, weeks and
months, and when a stored streak still counts."""

from __future__ import annotations

from datetime import UTC, date, datetime

import pytest

from app.application.admin_learner_use_cases import (
    bucket_start,
    buckets,
    live_streak,
    next_bucket,
)
from app.infrastructure.db.lesson_models import UserStreakModel


@pytest.mark.parametrize(
    ("day", "period", "start"),
    [
        (date(2026, 10, 2), "day", date(2026, 10, 2)),
        (date(2026, 10, 2), "week", date(2026, 9, 28)),  # a Friday: its Monday
        (date(2026, 9, 28), "week", date(2026, 9, 28)),
        (date(2026, 10, 4), "week", date(2026, 9, 28)),  # Sunday ends the week
        (date(2026, 10, 31), "month", date(2026, 10, 1)),
    ],
)
def test_a_day_falls_in_the_bucket_that_starts(day: date, period: str, start: date) -> None:
    assert bucket_start(day, period) == start


def test_months_roll_over_into_the_next_year() -> None:
    assert next_bucket(date(2026, 12, 1), "month") == date(2027, 1, 1)
    assert next_bucket(date(2027, 1, 1), "month") == date(2027, 2, 1)
    assert buckets("month", 3, date(2027, 1, 15)) == [
        date(2026, 11, 1),
        date(2026, 12, 1),
        date(2027, 1, 1),
    ]


def test_weeks_end_with_the_one_holding_the_last_day() -> None:
    assert buckets("week", 2, date(2026, 10, 2)) == [date(2026, 9, 21), date(2026, 9, 28)]


def _streak(last: date | None, count: int = 5, freezes: int = 0) -> UserStreakModel:
    return UserStreakModel(
        user_id="u",
        current_streak=count,
        last_completed_date=last,
        active_freeze_count=freezes,
        created_at=datetime(2026, 1, 1, tzinfo=UTC),
    )


@pytest.mark.parametrize(
    ("last", "freezes", "shown"),
    [
        (date(2026, 10, 2), 0, 5),  # studied today
        (date(2026, 10, 1), 0, 5),  # yesterday: still alive until tonight
        (date(2026, 9, 30), 0, 0),  # a whole day missed
        (date(2026, 9, 30), 1, 5),  # ... unless a freeze covers it
        (date(2026, 9, 29), 1, 0),
        (None, 0, 0),
    ],
)
def test_a_stored_streak_counts_only_while_it_is_alive(
    last: date | None, freezes: int, shown: int
) -> None:
    assert live_streak(_streak(last, freezes=freezes), date(2026, 10, 2)) == shown
    assert live_streak(None, date(2026, 10, 2)) == 0
