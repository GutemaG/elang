"""Reads behind the dashboard's stat sheets (013-stat-pill-interactions,
bolt `059-stat-pill-service`): the practised days with the current and
longest streak, and the recent Amole ledger entries.

Both only read rows the lesson loop already writes; neither changes
anything.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date

from app.domain.lesson.entities import AmoleTransaction
from app.domain.lesson.exceptions import InvalidRangeError
from app.domain.lesson.repositories import (
    AmoleTransactionRepository,
    LessonAttemptRepository,
    UserStreakRepository,
)
from app.domain.lesson.services import longest_streak

# About six months, both ends included: the app's calendar shows this month
# and the five before it.
STREAK_HISTORY_MAX_DAYS = 186


@dataclass(frozen=True)
class StreakHistory:
    start: date
    end: date
    practised_days: list[date]
    current_streak: int
    longest_streak: int
    joined_on: date


async def get_streak_history(
    user_id: str,
    joined_on: date,
    start: date,
    end: date,
    attempt_repo: LessonAttemptRepository,
    streak_repo: UserStreakRepository,
) -> StreakHistory:
    """The practised days in `[start, end]`, with the streak as the
    dashboard shows it and the longest run over all of the learner's days.

    Two queries whatever the range: the practised days, and the streak row.
    """
    if start > end:
        raise InvalidRangeError("`from` must not be after `to`")
    if (end - start).days + 1 > STREAK_HISTORY_MAX_DAYS:
        raise InvalidRangeError(f"The range may be at most {STREAK_HISTORY_MAX_DAYS} days")

    days = await attempt_repo.list_practised_days(user_id)
    streak = await streak_repo.get(user_id)
    current = streak.current_streak if streak is not None else 0
    return StreakHistory(
        start=start,
        end=end,
        practised_days=[day for day in days if start <= day <= end],
        current_streak=current,
        # A stored streak is never longer than a run of its own days, but
        # the two must never disagree on screen.
        longest_streak=max(longest_streak(days), current),
        joined_on=joined_on,
    )


async def get_amole_history(
    user_id: str,
    limit: int,
    amole_repo: AmoleTransactionRepository,
) -> list[AmoleTransaction]:
    """The account's newest `limit` Amole entries, newest first. One query."""
    return await amole_repo.list_recent(user_id, limit)
