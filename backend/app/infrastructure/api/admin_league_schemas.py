"""Request and response schemas for the admin Leagues page (intent 030):
`/api/v1/admin/leagues*`."""

from __future__ import annotations

from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict

Tier = Literal["green_bean", "light_roast", "medium_roast", "dark_roast", "golden_cup"]


class AdminLeagueMemberResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    member_id: str
    user_id: str
    first_name: str | None
    shown_name: str
    email: str | None
    rank: int | None
    xp: int
    earned_xp: int
    xp_adjustment: int
    xp_adjustment_reason: str | None
    last_xp_at: datetime | None
    joined_at: datetime
    hidden: bool
    removed: bool
    removed_at: datetime | None
    removed_reason: str | None
    tier_after: Tier | None
    movement: Literal["up", "down", "stayed"] | None
    reward_amole: int | None


class AdminLeagueGroupResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    group_id: str
    tier: Tier
    status: Literal["open", "ended", "closed"]
    promote_count: int
    demote_count: int
    members: list[AdminLeagueMemberResponse]


class AdminLeagueTotalsResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    groups: int
    members: int
    removed: int
    xp: int


class AdminLeagueWeekResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    week_start: date
    week_end: datetime
    is_current: bool
    weeks: list[date]
    totals: AdminLeagueTotalsResponse
    groups: list[AdminLeagueGroupResponse]


class RemoveMemberRequest(BaseModel):
    # Checked by the use case, so a missing one gets `invalid_content`.
    reason: str | None = None


class AdjustXpRequest(BaseModel):
    adjustment: int = 0
    reason: str | None = None
