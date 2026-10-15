"""The admin Leagues page (intent 030): every group of a week, with members
ranked exactly as the app ranks them, and two corrections for the current
week: taking a member out, and adjusting their weekly XP.

Open and ended groups are ranked live from the attempt tables (`rank`,
`zone_sizes`, the same functions the app's league uses); closed groups show
what closing stored.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from datetime import UTC, date, datetime

from app.application.league_use_cases import shows_in_leagues
from app.domain.activity import note_activity
from app.domain.league import (
    LEAGUE_WEEK,
    TIERS,
    LeagueTier,
    Movement,
    Standing,
    WeeklyXp,
    league_xp,
    movement,
    rank,
    shown_name,
    week_start,
    zone_sizes,
)
from app.domain.lesson.exceptions import (
    InvalidContentError,
    LeagueMemberNotFoundError,
    LeagueWeekClosedError,
)
from app.infrastructure.db.league_repository import (
    AdminGroupRow,
    AdminMemberRow,
    SqlAlchemyLeagueRepository,
)

logger = logging.getLogger("app.admin")

REASON_MIN = 3
REASON_MAX = 200
ADJUSTMENT_LIMIT = 100_000


@dataclass(frozen=True)
class AdminLeagueMember:
    member_id: str
    user_id: str
    first_name: str | None
    shown_name: str
    email: str | None
    # Place in the group; None for a removed or hidden member.
    rank: int | None
    # What ranks: earned plus the adjustment, never below 0. For a closed
    # group, the XP closing stored.
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
    # A closed group's stored result.
    tier_after: LeagueTier | None
    movement: Movement | None
    reward_amole: int | None


@dataclass(frozen=True)
class AdminLeagueGroup:
    group_id: str
    tier: LeagueTier
    # `open` (this week), `ended` (waiting to close) or `closed`.
    status: str
    promote_count: int
    demote_count: int
    members: list[AdminLeagueMember]


@dataclass(frozen=True)
class AdminLeagueTotals:
    groups: int
    members: int
    removed: int
    xp: int


@dataclass(frozen=True)
class AdminLeagueWeek:
    week_start: date
    week_end: datetime
    is_current: bool
    weeks: list[date]
    totals: AdminLeagueTotals
    groups: list[AdminLeagueGroup]


def _start(week: date) -> datetime:
    return datetime(week.year, week.month, week.day, tzinfo=UTC)


def _group(
    group: AdminGroupRow,
    members: list[AdminMemberRow],
    xp: dict[str, WeeklyXp],
    status: str,
) -> AdminLeagueGroup:
    def earned(m: AdminMemberRow) -> int:
        return xp[m.user_id].xp if m.user_id in xp else 0

    def last(m: AdminMemberRow) -> datetime | None:
        return xp[m.user_id].last_xp_at if m.user_id in xp else None

    def row(m: AdminMemberRow, place: int | None, total: int) -> AdminLeagueMember:
        closed = status == "closed"
        return AdminLeagueMember(
            member_id=m.member_id,
            user_id=m.user_id,
            first_name=m.first_name,
            shown_name=shown_name(m.first_name, m.user_id),
            email=m.email,
            rank=m.final_rank if closed else place,
            xp=(m.final_xp or 0) if closed else total,
            earned_xp=earned(m),
            xp_adjustment=m.xp_adjustment,
            xp_adjustment_reason=m.xp_adjustment_reason,
            last_xp_at=last(m),
            joined_at=m.joined_at,
            hidden=not shows_in_leagues(m.settings),
            removed=m.removed_at is not None,
            removed_at=m.removed_at,
            removed_reason=m.removed_reason,
            tier_after=m.tier_after if closed else None,
            movement=movement(group.tier, m.tier_after) if closed and m.tier_after else None,
            reward_amole=m.reward_amole if closed else None,
        )

    ranked_members = [m for m in members if m.removed_at is None and shows_in_leagues(m.settings)]
    ranked_ids = {m.member_id for m in ranked_members}
    others = [m for m in members if m.member_id not in ranked_ids]
    standings = rank(
        Standing(
            user_id=m.user_id,
            weekly_xp=league_xp(earned(m), m.xp_adjustment),
            last_xp_at=last(m),
            joined_at=m.joined_at,
        )
        for m in ranked_members
    )
    by_user = {m.user_id: m for m in ranked_members}
    rows = [
        row(by_user[s.user_id], place, s.weekly_xp) for place, s in enumerate(standings, start=1)
    ]
    rows += [
        row(m, None, league_xp(earned(m), m.xp_adjustment))
        for m in sorted(others, key=lambda m: m.joined_at)
    ]
    if status == "closed":
        rows.sort(key=lambda r: (r.rank is None, r.rank or 0, r.joined_at))
    zones = zone_sizes(len(ranked_members), group.tier)
    return AdminLeagueGroup(
        group_id=group.group_id,
        tier=group.tier,
        status=status,
        promote_count=zones.promote,
        demote_count=zones.demote,
        members=rows,
    )


async def _groups(
    repo: SqlAlchemyLeagueRepository, week: date, current: date
) -> list[AdminLeagueGroup]:
    groups = await repo.admin_groups(week)
    members = await repo.admin_members(week)
    start = _start(week)
    xp = await repo.weekly_xp(sorted({m.user_id for m in members}), start, start + LEAGUE_WEEK)
    result = []
    for g in groups:
        status = "closed" if g.closed_at else ("open" if week == current else "ended")
        result.append(_group(g, [m for m in members if m.group_id == g.group_id], xp, status))
    # Highest tier first; within a tier, as they were made.
    order = {t: i for i, t in enumerate(reversed(TIERS))}
    return sorted(result, key=lambda g: order[g.tier])


async def get_league_week(
    repo: SqlAlchemyLeagueRepository, *, week: date | None, now: datetime
) -> AdminLeagueWeek:
    current = week_start(now).date()
    chosen = week_start(_start(week)).date() if week is not None else current
    if chosen > current:
        raise InvalidContentError("week", "That week hasn't started yet")
    weeks = await repo.weeks()
    if current not in weeks:
        weeks = [current, *weeks]
    groups = await _groups(repo, chosen, current)
    members = [m for g in groups for m in g.members]
    return AdminLeagueWeek(
        week_start=chosen,
        week_end=_start(chosen) + LEAGUE_WEEK,
        is_current=chosen == current,
        weeks=weeks,
        totals=AdminLeagueTotals(
            groups=len(groups),
            members=len(members),
            removed=sum(1 for m in members if m.removed),
            xp=sum(m.xp for m in members if not m.removed),
        ),
        groups=groups,
    )


async def _editable(
    repo: SqlAlchemyLeagueRepository, member_id: str, now: datetime
) -> AdminMemberRow:
    member = await repo.admin_member(member_id)
    if member is None:
        raise LeagueMemberNotFoundError("No league member has this id")
    if member.week_start != week_start(now).date() or await repo.group_closed(member.group_id):
        raise LeagueWeekClosedError("Only this week's leagues can be changed")
    return member


def _reason(reason: str | None, *, required: bool = True) -> str | None:
    text = " ".join((reason or "").split())
    if not text and not required:
        return None
    if not REASON_MIN <= len(text) <= REASON_MAX:
        raise InvalidContentError(
            "reason", f"Write a reason of {REASON_MIN} to {REASON_MAX} characters"
        )
    return text


async def _member_now(
    repo: SqlAlchemyLeagueRepository, member: AdminMemberRow, now: datetime
) -> AdminLeagueMember:
    current = week_start(now).date()
    for group in await _groups(repo, current, current):
        for m in group.members:
            if m.member_id == member.member_id:
                return m
    raise LeagueMemberNotFoundError("No league member has this id")


def _log(action: str, member: AdminMemberRow, email: str, **extra: object) -> None:
    logger.info(
        "admin_write action=%s entity=league_member id=%s admin=%s %s",
        action,
        member.member_id,
        email,
        " ".join(f"{k}={v}" for k, v in extra.items()),
    )


async def remove_member(
    repo: SqlAlchemyLeagueRepository,
    member_id: str,
    *,
    reason: str | None,
    admin_email: str,
    now: datetime,
) -> AdminLeagueMember:
    member = await _editable(repo, member_id, now)
    text = _reason(reason)
    await repo.set_removed(member_id, now, text)
    note_activity(reason=text, week=member.week_start.isoformat())
    _log("remove", member, admin_email)
    return await _member_now(repo, member, now)


async def restore_member(
    repo: SqlAlchemyLeagueRepository, member_id: str, *, admin_email: str, now: datetime
) -> AdminLeagueMember:
    member = await _editable(repo, member_id, now)
    await repo.set_removed(member_id, None, None)
    note_activity(week=member.week_start.isoformat(), was_removed_for=member.removed_reason)
    _log("restore", member, admin_email)
    return await _member_now(repo, member, now)


async def adjust_xp(
    repo: SqlAlchemyLeagueRepository,
    member_id: str,
    *,
    adjustment: int,
    reason: str | None,
    admin_email: str,
    now: datetime,
) -> AdminLeagueMember:
    member = await _editable(repo, member_id, now)
    if not -ADJUSTMENT_LIMIT <= adjustment <= ADJUSTMENT_LIMIT:
        raise InvalidContentError(
            "adjustment", f"Use a number from -{ADJUSTMENT_LIMIT} to {ADJUSTMENT_LIMIT}"
        )
    text = _reason(reason) if adjustment != 0 else None
    await repo.set_xp_adjustment(member_id, adjustment, text)
    note_activity(
        week=member.week_start.isoformat(),
        adjustment_before=member.xp_adjustment,
        adjustment=adjustment,
        reason=text,
    )
    _log("adjust_xp", member, admin_email, adjustment=adjustment)
    return await _member_now(repo, member, now)
