"""Response schema for `GET /api/v1/leagues/current` (023-weekly-leagues,
bolt 073)."""

from __future__ import annotations

from datetime import datetime
from typing import Any

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
    # The last closed week's result, until seen (bolt 074).
    last_result: dict[str, Any] | None = None
