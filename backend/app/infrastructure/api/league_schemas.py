"""Response schema for `GET /api/v1/leagues/current` (023-weekly-leagues,
bolts 073 and 074)."""

from __future__ import annotations

from datetime import date, datetime

from pydantic import BaseModel


class LeagueMemberResponse(BaseModel):
    """One member of the group. Never an id, an email or a last name."""

    name: str
    initial: str
    # 0-7; the app picks the colour from its palette.
    avatar_colour: int
    weekly_xp: int
    rank: int
    is_me: bool


class LastResultResponse(BaseModel):
    """How the learner's last closed week went (bolt 074)."""

    week_start: date
    tier: str
    tier_after: str
    # `up`, `down` or `stayed`.
    movement: str
    # Null if they had switched leagues off by the time it closed.
    rank: int | None
    group_size: int
    weekly_xp: int
    reward_amole: int


class CurrentLeagueResponse(BaseModel):
    tier: str
    # `joined`, `not_joined` (no XP yet this week) or `hidden` (switched off).
    status: str
    week_ends_at: datetime
    # How many places at the top move up, and at the bottom move down.
    promote_count: int
    demote_count: int
    # Amole for 1st, 2nd and 3rd when the week closes.
    rewards: list[int]
    members: list[LeagueMemberResponse]
    # The last closed week's result, until the app marks it seen.
    last_result: LastResultResponse | None = None
