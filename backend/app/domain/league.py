"""Weekly leagues (023-weekly-leagues, bolt 073).

Each week (Monday 00:00 to the next Monday 00:00 UTC, the streak's clock),
a learner's first XP puts them in a group of up to `LEAGUE_GROUP_SIZE`
learners of their tier, ranked by the XP they earn that week. When the week
ends, the top of each group moves up a tier, the bottom moves down, and the
top three earn Amole (closing a week is bolt 074).

Pure Python only: the rules and constants live here, like the bean and
Amole constants in `app/domain/lesson/value_objects.py`.
"""

from __future__ import annotations

import hashlib
import math
from collections.abc import Iterable
from dataclasses import dataclass
from datetime import UTC, date, datetime, timedelta
from enum import StrEnum
from typing import Any, Protocol


class LeagueTier(StrEnum):
    """The five tiers, lowest first. The app owns their display names."""

    GREEN_BEAN = "green_bean"
    LIGHT_ROAST = "light_roast"
    MEDIUM_ROAST = "medium_roast"
    DARK_ROAST = "dark_roast"
    GOLDEN_CUP = "golden_cup"


TIERS: tuple[LeagueTier, ...] = tuple(LeagueTier)
LOWEST_TIER = TIERS[0]
HIGHEST_TIER = TIERS[-1]


class LeagueStatus(StrEnum):
    """Whether the learner is in this week's league, and why not."""

    JOINED = "joined"
    NOT_JOINED = "not_joined"  # No XP yet this week.
    HIDDEN = "hidden"  # "Show me in leagues" is off.


# Most learners in one group. Checked, not locked, when joining: two
# learners taking the last seat at the same moment can make it 31.
LEAGUE_GROUP_SIZE = 30
# The share of a group that moves up, and the share that moves down, each
# rounded up.
LEAGUE_MOVE_PERCENT = 20
# A group smaller than this moves only first place up, and nobody down.
LEAGUE_SMALL_GROUP = 5
# Amole for 1st, 2nd and 3rd place when a week closes.
LEAGUE_REWARDS: tuple[int, ...] = (100, 60, 40)
# How many avatar colours there are; the app maps each to a palette role.
AVATAR_COLOURS = 8

LEAGUE_WEEK = timedelta(days=7)


def week_start(moment: datetime) -> datetime:
    """The Monday 00:00 UTC on or before `moment` (naive means UTC)."""
    utc = moment.replace(tzinfo=UTC) if moment.tzinfo is None else moment.astimezone(UTC)
    day = utc.date() - timedelta(days=utc.weekday())
    return datetime(day.year, day.month, day.day, tzinfo=UTC)


def week_end(moment: datetime) -> datetime:
    """The Monday 00:00 UTC that ends the week of `moment`."""
    return week_start(moment) + LEAGUE_WEEK


def tier_above(tier: LeagueTier) -> LeagueTier:
    return TIERS[min(TIERS.index(tier) + 1, len(TIERS) - 1)]


def tier_below(tier: LeagueTier) -> LeagueTier:
    return TIERS[max(TIERS.index(tier) - 1, 0)]


@dataclass(frozen=True)
class Zones:
    """How many places at the top move up, and at the bottom move down."""

    promote: int
    demote: int


def zone_sizes(member_count: int, tier: LeagueTier) -> Zones:
    """20% up and 20% down (each rounded up); a group under 5 moves only
    first place up. Nobody moves up from the highest tier or down from the
    lowest."""
    if member_count <= 0:
        return Zones(0, 0)
    if member_count < LEAGUE_SMALL_GROUP:
        promote, demote = 1, 0
    else:
        share = math.ceil(member_count * LEAGUE_MOVE_PERCENT / 100)
        promote, demote = share, share
    if tier == HIGHEST_TIER:
        promote = 0
    if tier == LOWEST_TIER:
        demote = 0
    return Zones(promote, demote)


@dataclass(frozen=True)
class Standing:
    """One member's week so far: the input to `rank`."""

    user_id: str
    weekly_xp: int
    # When their last XP of the week was earned; `None` with no XP.
    last_xp_at: datetime | None
    joined_at: datetime


def rank(standings: Iterable[Standing]) -> list[Standing]:
    """Most XP first. A tie goes to whoever reached their total first (the
    earlier last XP), then to whoever joined first."""
    far_future = datetime.max.replace(tzinfo=UTC)
    return sorted(
        standings,
        key=lambda s: (-s.weekly_xp, s.last_xp_at or far_future, s.joined_at, s.user_id),
    )


class Movement(StrEnum):
    UP = "up"
    DOWN = "down"
    STAYED = "stayed"


def movement(tier: LeagueTier, tier_after: LeagueTier) -> Movement:
    if TIERS.index(tier_after) > TIERS.index(tier):
        return Movement.UP
    if TIERS.index(tier_after) < TIERS.index(tier):
        return Movement.DOWN
    return Movement.STAYED


@dataclass(frozen=True)
class MemberResult:
    """One member's stored result when their group closes (bolt 074)."""

    user_id: str
    final_xp: int
    # `None` for a member who switched leagues off: not ranked.
    final_rank: int | None
    tier_after: LeagueTier
    reward_amole: int


def close_group(
    tier: LeagueTier, standings: Iterable[Standing], hidden: frozenset[str] = frozenset()
) -> list[MemberResult]:
    """The final result of a group whose week has ended (FR-5).

    Members who still show in leagues are ranked as the screen ranks them;
    the top `promote` move up a tier and the bottom `demote` move down
    (`zone_sizes`: small groups and the end tiers included), everyone else
    stays, and places 1 to 3 earn `LEAGUE_REWARDS`. Members in `hidden`
    (switched off after the week ended) keep their XP but get no place, no
    move and no reward.
    """
    standings = list(standings)
    ranked = rank(s for s in standings if s.user_id not in hidden)
    zones = zone_sizes(len(ranked), tier)
    results = []
    for place, s in enumerate(ranked, start=1):
        if place <= zones.promote:
            after = tier_above(tier)
        elif place > len(ranked) - zones.demote:
            after = tier_below(tier)
        else:
            after = tier
        reward = LEAGUE_REWARDS[place - 1] if place <= len(LEAGUE_REWARDS) else 0
        results.append(MemberResult(s.user_id, s.weekly_xp, place, after, reward))
    results.extend(
        MemberResult(s.user_id, s.weekly_xp, None, tier, 0)
        for s in standings
        if s.user_id in hidden
    )
    return results


def _id_hash(user_id: str) -> int:
    return int(hashlib.sha256(user_id.encode()).hexdigest(), 16)


def shown_name(first_name: str | None, user_id: str) -> str:
    """The name other learners see: the Google first name, else "Learner"
    and four digits that stay the same for this account."""
    if first_name:
        return first_name
    return f"Learner {1000 + _id_hash(user_id) % 9000}"


def avatar_colour(user_id: str) -> int:
    """A colour index, 0 to `AVATAR_COLOURS - 1`, the same for this account."""
    return (_id_hash(user_id) // 9000) % AVATAR_COLOURS


@dataclass(frozen=True)
class LeagueMembership:
    """A learner's place in one week's group."""

    group_id: str
    user_id: str
    week_start: date
    tier: LeagueTier
    joined_at: datetime


@dataclass(frozen=True)
class EndedGroup:
    """A group of a week that has ended and isn't closed yet."""

    group_id: str
    week_start: date
    tier: LeagueTier


@dataclass(frozen=True)
class LastResult:
    """How the learner's last closed week went, until they have seen it."""

    week_start: date
    tier: LeagueTier
    tier_after: LeagueTier
    movement: Movement
    # `None` if they had switched leagues off by the time it closed.
    rank: int | None
    group_size: int
    weekly_xp: int
    reward_amole: int


@dataclass(frozen=True)
class GroupMember:
    """A member as the league screen and closing need them."""

    # The membership row's id: the reference of a league reward.
    member_id: str
    user_id: str
    first_name: str | None
    # The stored account settings, to leave out anyone who switched off.
    settings: dict[str, Any]
    joined_at: datetime


@dataclass(frozen=True)
class WeeklyXp:
    xp: int
    last_xp_at: datetime | None


class LeagueRepository(Protocol):
    """League groups and members (`league_groups`, `league_members`)."""

    async def get_membership(self, user_id: str, week: date) -> LeagueMembership | None: ...

    async def latest_tier(self, user_id: str) -> LeagueTier | None:
        """The tier the learner's latest week left them in: its tier after
        closing, else its own tier. `None` if never in a league."""
        ...

    async def find_open_group(self, week: date, tier: LeagueTier, size: int) -> str | None:
        """The oldest group of this week and tier with fewer than `size`
        members."""
        ...

    async def add_group(self, week: date, tier: LeagueTier, now: datetime) -> str: ...

    async def add_member_if_new(
        self, group_id: str, user_id: str, week: date, joined_at: datetime
    ) -> bool:
        """Adds the membership unless the learner already has one this week
        (also when a simultaneous request just added it). True if added."""
        ...

    async def remove_member(self, user_id: str, week: date) -> None: ...

    async def ended_open_groups(self, user_id: str, week: date) -> list[EndedGroup]:
        """The learner's groups from weeks before `week` not closed yet,
        oldest first."""
        ...

    async def claim_group(self, group_id: str, now: datetime) -> bool:
        """Marks the group closed unless it already is. True only for the
        one caller that closed it; that caller then saves the results."""
        ...

    async def save_results(self, group_id: str, results: list[MemberResult]) -> None: ...

    async def last_unseen_result(self, user_id: str) -> LastResult | None: ...

    async def mark_results_seen(self, user_id: str, now: datetime) -> None: ...

    async def list_members(self, group_id: str) -> list[GroupMember]: ...

    async def weekly_xp(
        self, user_ids: list[str], start: datetime, end: datetime
    ) -> dict[str, WeeklyXp]:
        """XP from lessons and practice earned in [start, end), per learner
        (learners with none are left out)."""
        ...
