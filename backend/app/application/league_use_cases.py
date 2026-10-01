"""Weekly leagues (023-weekly-leagues): joining a week's group, reading
the current league and leaving it when "Show me in leagues" is turned off
(bolt 073); closing ended weeks and the last-week result (bolt 074). The
rules live in `app.domain.league`.

There is no scheduler: a learner's ended groups are closed the next time
they read their league or earn their first XP of a new week.
"""

from __future__ import annotations

import logging
import uuid
from collections.abc import Iterable
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any

from app.domain.entities import User
from app.domain.league import (
    LEAGUE_GROUP_SIZE,
    LEAGUE_REWARDS,
    LEAGUE_WEEK,
    LOWEST_TIER,
    GroupMember,
    LastResult,
    LeagueRepository,
    LeagueStatus,
    LeagueTier,
    Standing,
    WeeklyXp,
    avatar_colour,
    close_group,
    rank,
    shown_name,
    week_end,
    week_start,
    zone_sizes,
)
from app.domain.lesson.entities import AmoleTransaction
from app.domain.lesson.repositories import AmoleTransactionRepository
from app.domain.lesson.value_objects import AmoleSource
from app.domain.settings import ACCOUNT_SETTINGS

logger = logging.getLogger("app.league")

SHOW_IN_LEAGUES = "show_in_leagues"


def shows_in_leagues(settings: dict[str, Any]) -> bool:
    """The learner's "Show me in leagues" switch, from their stored
    settings (on unless they turned it off)."""
    return bool(ACCOUNT_SETTINGS.resolve(settings).get(SHOW_IN_LEAGUES, True))


def _standings(members: Iterable[GroupMember], xp: dict[str, WeeklyXp]) -> list[Standing]:
    return [
        Standing(
            user_id=m.user_id,
            weekly_xp=xp[m.user_id].xp if m.user_id in xp else 0,
            last_xp_at=xp[m.user_id].last_xp_at if m.user_id in xp else None,
            joined_at=m.joined_at,
        )
        for m in members
    ]


async def close_ended_weeks(
    *,
    user_id: str,
    now: datetime,
    league_repo: LeagueRepository,
    amole_repo: AmoleTransactionRepository,
) -> None:
    """Closes the learner's groups from weeks that have ended (FR-5), each
    whole group exactly once: the final XP and places are stored, the top
    moves up, the bottom moves down, and 1st to 3rd get Amole.

    `claim_group` marks a group closed only if it is still open, so of two
    requests at the same moment only one writes results; the reward's
    unique (`source`, `reference_id`) is a second guard. XP synced after a
    group closed does not change its result.
    """
    for group in await league_repo.ended_open_groups(user_id, week_start(now).date()):
        if not await league_repo.claim_group(group.group_id, now):
            continue
        members = await league_repo.list_members(group.group_id)
        start = datetime(
            group.week_start.year, group.week_start.month, group.week_start.day, tzinfo=UTC
        )
        xp = await league_repo.weekly_xp([m.user_id for m in members], start, start + LEAGUE_WEEK)
        hidden = frozenset(m.user_id for m in members if not shows_in_leagues(m.settings))
        results = close_group(group.tier, _standings(members, xp), hidden)
        await league_repo.save_results(group.group_id, results)

        member_ids = {m.user_id: m.member_id for m in members}
        for result in results:
            if result.reward_amole <= 0:
                continue
            await amole_repo.add_if_new(
                AmoleTransaction(
                    id=str(uuid.uuid4()),
                    user_id=result.user_id,
                    amount=result.reward_amole,
                    source=AmoleSource.LEAGUE_REWARD,
                    reference_id=member_ids[result.user_id],
                    created_at=start + LEAGUE_WEEK,
                )
            )
        logger.info(
            "league_group_closed group_id=%s tier=%s members=%d",
            group.group_id,
            group.tier.value,
            len(results),
        )


async def join_league_week(
    *,
    user: User,
    xp_earned: int,
    completed_at: datetime,
    now: datetime,
    league_repo: LeagueRepository,
    amole_repo: AmoleTransactionRepository,
) -> None:
    """Puts the learner in this week's league with their first XP of the
    week (FR-3), after a lesson or practice session is recorded.

    Nothing happens for no XP (a review), for XP earned in an earlier week
    (an offline lesson synced now), when the learner switched leagues off,
    or when they already joined (one query: the common case). Otherwise
    their ended weeks are closed first, so they join in the tier their last
    week gave them, in the oldest group of that tier and week with room, or
    a new one.
    """
    if xp_earned <= 0 or not shows_in_leagues(user.settings):
        return
    week = week_start(now)
    if week_start(completed_at) != week:
        return
    if await league_repo.get_membership(user.id, week.date()) is not None:
        return

    await close_ended_weeks(
        user_id=user.id, now=now, league_repo=league_repo, amole_repo=amole_repo
    )
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
    # The last closed week, until the learner has seen it (bolt 074).
    last_result: LastResult | None = None


async def get_current_league(
    *,
    user: User,
    now: datetime,
    league_repo: LeagueRepository,
    amole_repo: AmoleTransactionRepository,
) -> CurrentLeague:
    """The learner's league this week (FR-4, FR-8): their tier, whether
    they are in it, and their group ranked by the week's XP, computed from
    the attempt tables on every read. Members who have since switched
    leagues off are left out. Their ended weeks are closed first, and the
    last one's result comes with it until they have seen it."""
    await close_ended_weeks(
        user_id=user.id, now=now, league_repo=league_repo, amole_repo=amole_repo
    )
    last_result = await league_repo.last_unseen_result(user.id)
    week = week_start(now)
    ends_at = week_end(now)
    membership = await league_repo.get_membership(user.id, week.date())
    tier = (
        membership.tier
        if membership is not None
        else await league_repo.latest_tier(user.id) or LOWEST_TIER
    )

    if not shows_in_leagues(user.settings):
        return CurrentLeague(
            tier, LeagueStatus.HIDDEN, ends_at, 0, 0, LEAGUE_REWARDS, [], last_result
        )
    if membership is None:
        return CurrentLeague(
            tier, LeagueStatus.NOT_JOINED, ends_at, 0, 0, LEAGUE_REWARDS, [], last_result
        )

    members = [
        m
        for m in await league_repo.list_members(membership.group_id)
        if m.user_id == user.id or shows_in_leagues(m.settings)
    ]
    xp = await league_repo.weekly_xp([m.user_id for m in members], week, ends_at)
    names = {m.user_id: shown_name(m.first_name, m.user_id) for m in members}
    standings = rank(_standings(members, xp))
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
        tier,
        LeagueStatus.JOINED,
        ends_at,
        zones.promote,
        zones.demote,
        LEAGUE_REWARDS,
        rows,
        last_result,
    )


async def mark_last_result_seen(
    *, user_id: str, now: datetime, league_repo: LeagueRepository
) -> None:
    """The app showed the last-week result: none of the learner's closed
    weeks is offered again. Safe to repeat."""
    await league_repo.mark_results_seen(user_id, now)
