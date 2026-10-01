"""Weekly leagues (023-weekly-leagues, bolt 073): joining a week's group,
reading the current league, and leaving it when "Show me in leagues" is
turned off. The rules live in `app.domain.league`; closing a week is bolt
074.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from datetime import datetime
from typing import Any

from app.domain.entities import User
from app.domain.league import (
    LEAGUE_GROUP_SIZE,
    LEAGUE_REWARDS,
    LOWEST_TIER,
    LeagueRepository,
    LeagueStatus,
    LeagueTier,
    Standing,
    avatar_colour,
    rank,
    shown_name,
    week_end,
    week_start,
    zone_sizes,
)
from app.domain.settings import ACCOUNT_SETTINGS

logger = logging.getLogger("app.league")

SHOW_IN_LEAGUES = "show_in_leagues"


def shows_in_leagues(settings: dict[str, Any]) -> bool:
    """The learner's "Show me in leagues" switch, from their stored
    settings (on unless they turned it off)."""
    return bool(ACCOUNT_SETTINGS.resolve(settings).get(SHOW_IN_LEAGUES, True))


async def join_league_week(
    *,
    user: User,
    xp_earned: int,
    completed_at: datetime,
    now: datetime,
    league_repo: LeagueRepository,
) -> None:
    """Puts the learner in this week's league with their first XP of the
    week (FR-3), after a lesson or practice session is recorded.

    Nothing happens for no XP (a review), for XP earned in an earlier week
    (an offline lesson synced now), when the learner switched leagues off,
    or when they already joined (one query: the common case). Otherwise
    they go into the oldest group of their tier and week with room, or a
    new one.
    """
    if xp_earned <= 0 or not shows_in_leagues(user.settings):
        return
    week = week_start(now)
    if week_start(completed_at) != week:
        return
    if await league_repo.get_membership(user.id, week.date()) is not None:
        return

    tier = await league_repo.latest_tier(user.id) or LOWEST_TIER
    group_id = await league_repo.find_open_group(week.date(), tier, LEAGUE_GROUP_SIZE)
    if group_id is None:
        group_id = await league_repo.add_group(week.date(), tier, now)
    if await league_repo.add_member_if_new(group_id, user.id, week.date(), now):
        logger.info("league_joined user_id=%s tier=%s", user.id, tier.value)


async def apply_league_visibility(
    *, user: User, settings: dict[str, Any], now: datetime, league_repo: LeagueRepository
) -> None:
    """After a settings change (FR-7): switched off, the learner leaves this
    week's group at once, so the others stop seeing them. Their tier is
    kept, since it comes from weeks already closed."""
    if shows_in_leagues(settings):
        return
    await league_repo.remove_member(user.id, week_start(now).date())


@dataclass(frozen=True)
class LeagueRow:
    """One member as other learners see them: never an id or an email."""

    name: str
    initial: str
    avatar_colour: int
    weekly_xp: int
    rank: int
    is_me: bool


@dataclass(frozen=True)
class CurrentLeague:
    tier: LeagueTier
    status: LeagueStatus
    week_ends_at: datetime
    promote_count: int
    demote_count: int
    rewards: tuple[int, ...]
    members: list[LeagueRow]


async def get_current_league(
    *, user: User, now: datetime, league_repo: LeagueRepository
) -> CurrentLeague:
    """The learner's league this week (FR-4, FR-8): their tier, whether
    they are in it, and their group ranked by the week's XP, computed from
    the attempt tables on every read. Members who have since switched
    leagues off are left out."""
    week = week_start(now)
    ends_at = week_end(now)
    membership = await league_repo.get_membership(user.id, week.date())
    tier = (
        membership.tier
        if membership is not None
        else await league_repo.latest_tier(user.id) or LOWEST_TIER
    )

    if not shows_in_leagues(user.settings):
        return CurrentLeague(tier, LeagueStatus.HIDDEN, ends_at, 0, 0, LEAGUE_REWARDS, [])
    if membership is None:
        return CurrentLeague(tier, LeagueStatus.NOT_JOINED, ends_at, 0, 0, LEAGUE_REWARDS, [])

    members = [
        m
        for m in await league_repo.list_members(membership.group_id)
        if m.user_id == user.id or shows_in_leagues(m.settings)
    ]
    xp = await league_repo.weekly_xp([m.user_id for m in members], week, ends_at)
    names = {m.user_id: shown_name(m.first_name, m.user_id) for m in members}
    standings = rank(
        Standing(
            user_id=m.user_id,
            weekly_xp=xp[m.user_id].xp if m.user_id in xp else 0,
            last_xp_at=xp[m.user_id].last_xp_at if m.user_id in xp else None,
            joined_at=m.joined_at,
        )
        for m in members
    )
    zones = zone_sizes(len(standings), tier)
    rows = [
        LeagueRow(
            name=names[s.user_id],
            initial=names[s.user_id][:1].upper(),
            avatar_colour=avatar_colour(s.user_id),
            weekly_xp=s.weekly_xp,
            rank=place,
            is_me=s.user_id == user.id,
        )
        for place, s in enumerate(standings, start=1)
    ]
    return CurrentLeague(
        tier, LeagueStatus.JOINED, ends_at, zones.promote, zones.demote, LEAGUE_REWARDS, rows
    )
