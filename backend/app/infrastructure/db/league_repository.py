"""Implements `app.domain.league.LeagueRepository` (023-weekly-leagues,
bolts 073 and 074)."""

from __future__ import annotations

import uuid
from dataclasses import dataclass
from datetime import UTC, date, datetime
from typing import Any

from sqlalchemy import Select, delete, func, select, update
from sqlalchemy.dialects.postgresql import insert as postgres_insert
from sqlalchemy.dialects.sqlite import insert as sqlite_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.league import (
    EndedGroup,
    GroupMember,
    LastResult,
    LeagueMembership,
    LeagueTier,
    MemberResult,
    WeeklyXp,
    movement,
)
from app.infrastructure.db.league_models import LeagueGroupModel, LeagueMemberModel
from app.infrastructure.db.lesson_models import LessonAttemptModel, PracticeAttemptModel
from app.infrastructure.db.models import UserModel


def _utc(value: datetime) -> datetime:
    """SQLite hands timestamps back without a time zone; they are UTC."""
    return value.replace(tzinfo=UTC) if value.tzinfo is None else value.astimezone(UTC)


class SqlAlchemyLeagueRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_membership(self, user_id: str, week: date) -> LeagueMembership | None:
        stmt = (
            select(LeagueMemberModel, LeagueGroupModel.tier)
            .join(LeagueGroupModel, LeagueGroupModel.id == LeagueMemberModel.group_id)
            .where(LeagueMemberModel.user_id == user_id, LeagueMemberModel.week_start == week)
        )
        row = (await self._session.execute(stmt)).one_or_none()
        if row is None:
            return None
        member, tier = row
        return LeagueMembership(
            group_id=member.group_id,
            user_id=member.user_id,
            week_start=member.week_start,
            tier=LeagueTier(tier),
            joined_at=_utc(member.joined_at),
            removed=member.removed_at is not None,
        )

    async def latest_tier(self, user_id: str) -> LeagueTier | None:
        stmt = (
            select(LeagueMemberModel.tier_after, LeagueGroupModel.tier)
            .join(LeagueGroupModel, LeagueGroupModel.id == LeagueMemberModel.group_id)
            .where(LeagueMemberModel.user_id == user_id)
            .order_by(LeagueMemberModel.week_start.desc())
            .limit(1)
        )
        row = (await self._session.execute(stmt)).one_or_none()
        if row is None:
            return None
        tier_after, tier = row
        return LeagueTier(tier_after or tier)

    async def find_open_group(self, week: date, tier: LeagueTier, size: int) -> str | None:
        stmt = (
            select(LeagueGroupModel.id)
            .outerjoin(LeagueMemberModel, LeagueMemberModel.group_id == LeagueGroupModel.id)
            .where(
                LeagueGroupModel.week_start == week,
                LeagueGroupModel.tier == tier.value,
                LeagueGroupModel.closed_at.is_(None),
            )
            .group_by(LeagueGroupModel.id, LeagueGroupModel.created_at)
            .having(func.count(LeagueMemberModel.id) < size)
            .order_by(LeagueGroupModel.created_at, LeagueGroupModel.id)
            .limit(1)
        )
        return (await self._session.execute(stmt)).scalar_one_or_none()

    async def add_group(self, week: date, tier: LeagueTier, now: datetime) -> str:
        group = LeagueGroupModel(
            id=str(uuid.uuid4()), week_start=week, tier=tier.value, created_at=now
        )
        self._session.add(group)
        await self._session.flush()
        return group.id

    async def add_member_if_new(
        self, group_id: str, user_id: str, week: date, joined_at: datetime
    ) -> bool:
        # `ON CONFLICT DO NOTHING`, so a second join at the same moment
        # (two lessons finishing together) is skipped instead of failing
        # the whole request's transaction. Both databases have it; only the
        # import differs.
        dialect = self._session.get_bind().dialect.name
        insert = postgres_insert if dialect == "postgresql" else sqlite_insert
        stmt = (
            insert(LeagueMemberModel)
            .values(
                id=str(uuid.uuid4()),
                group_id=group_id,
                user_id=user_id,
                week_start=week,
                joined_at=joined_at,
            )
            .on_conflict_do_nothing(index_elements=["user_id", "week_start"])
        )
        result = await self._session.execute(stmt)
        return bool(result.rowcount)  # type: ignore[attr-defined]

    async def remove_member(self, user_id: str, week: date) -> None:
        await self._session.execute(
            delete(LeagueMemberModel).where(
                LeagueMemberModel.user_id == user_id,
                LeagueMemberModel.week_start == week,
            )
        )

    async def ended_open_groups(self, user_id: str, week: date) -> list[EndedGroup]:
        stmt = (
            select(LeagueGroupModel.id, LeagueGroupModel.week_start, LeagueGroupModel.tier)
            .join(LeagueMemberModel, LeagueMemberModel.group_id == LeagueGroupModel.id)
            .where(
                LeagueMemberModel.user_id == user_id,
                LeagueGroupModel.week_start < week,
                LeagueGroupModel.closed_at.is_(None),
            )
            .order_by(LeagueGroupModel.week_start)
        )
        rows = (await self._session.execute(stmt)).all()
        return [EndedGroup(group_id, start, LeagueTier(tier)) for group_id, start, tier in rows]

    async def claim_group(self, group_id: str, now: datetime) -> bool:
        # The conditional update is the lock: on Postgres a simultaneous
        # second request waits for this row, then finds it closed.
        result = await self._session.execute(
            update(LeagueGroupModel)
            .where(LeagueGroupModel.id == group_id, LeagueGroupModel.closed_at.is_(None))
            .values(closed_at=now)
        )
        return bool(result.rowcount)  # type: ignore[attr-defined]

    async def save_results(self, group_id: str, results: list[MemberResult]) -> None:
        for r in results:
            await self._session.execute(
                update(LeagueMemberModel)
                .where(
                    LeagueMemberModel.group_id == group_id,
                    LeagueMemberModel.user_id == r.user_id,
                )
                .values(
                    final_xp=r.final_xp,
                    final_rank=r.final_rank,
                    tier_after=r.tier_after.value,
                    reward_amole=r.reward_amole,
                )
            )

    async def last_unseen_result(self, user_id: str) -> LastResult | None:
        stmt = (
            select(LeagueMemberModel, LeagueGroupModel.tier)
            .join(LeagueGroupModel, LeagueGroupModel.id == LeagueMemberModel.group_id)
            .where(
                LeagueMemberModel.user_id == user_id,
                LeagueMemberModel.tier_after.is_not(None),
                LeagueMemberModel.result_seen_at.is_(None),
                # Intent 030: a removed member's week has no result to show.
                LeagueMemberModel.removed_at.is_(None),
            )
            .order_by(LeagueMemberModel.week_start.desc())
            .limit(1)
        )
        row = (await self._session.execute(stmt)).one_or_none()
        if row is None:
            return None
        member, tier_value = row
        size_stmt = select(func.count(LeagueMemberModel.id)).where(
            LeagueMemberModel.group_id == member.group_id,
            LeagueMemberModel.final_rank.is_not(None),
        )
        group_size = (await self._session.execute(size_stmt)).scalar_one()
        tier = LeagueTier(tier_value)
        tier_after = LeagueTier(member.tier_after)
        return LastResult(
            week_start=member.week_start,
            tier=tier,
            tier_after=tier_after,
            movement=movement(tier, tier_after),
            rank=member.final_rank,
            group_size=group_size,
            weekly_xp=member.final_xp or 0,
            reward_amole=member.reward_amole or 0,
        )

    async def mark_results_seen(self, user_id: str, now: datetime) -> None:
        await self._session.execute(
            update(LeagueMemberModel)
            .where(
                LeagueMemberModel.user_id == user_id,
                LeagueMemberModel.tier_after.is_not(None),
                LeagueMemberModel.result_seen_at.is_(None),
            )
            .values(result_seen_at=now)
        )

    async def list_members(self, group_id: str) -> list[GroupMember]:
        stmt = (
            select(
                LeagueMemberModel.id,
                LeagueMemberModel.user_id,
                UserModel.first_name,
                UserModel.settings,
                LeagueMemberModel.joined_at,
                LeagueMemberModel.removed_at,
                LeagueMemberModel.xp_adjustment,
            )
            .join(UserModel, UserModel.id == LeagueMemberModel.user_id)
            .where(LeagueMemberModel.group_id == group_id)
        )
        rows = (await self._session.execute(stmt)).all()
        return [
            GroupMember(
                member_id=member_id,
                user_id=user_id,
                first_name=first_name,
                settings=dict(settings or {}),
                joined_at=_utc(joined_at),
                removed=removed_at is not None,
                xp_adjustment=adjustment or 0,
            )
            for (
                member_id,
                user_id,
                first_name,
                settings,
                joined_at,
                removed_at,
                adjustment,
            ) in rows
        ]

    async def weekly_xp(
        self, user_ids: list[str], start: datetime, end: datetime
    ) -> dict[str, WeeklyXp]:
        totals: dict[str, WeeklyXp] = {}
        if not user_ids:
            return totals
        for model in (LessonAttemptModel, PracticeAttemptModel):
            stmt = (
                select(model.user_id, func.sum(model.xp_awarded), func.max(model.completed_at))
                .where(
                    model.user_id.in_(user_ids),
                    model.completed_at >= start,
                    model.completed_at < end,
                    # A review earns nothing, so it doesn't count as
                    # reaching a total either.
                    model.xp_awarded > 0,
                )
                .group_by(model.user_id)
            )
            for user_id, xp, last in (await self._session.execute(stmt)).all():
                last_at = _utc(last)
                before = totals.get(user_id)
                if before is None:
                    totals[user_id] = WeeklyXp(int(xp), last_at)
                else:
                    latest = max(last_at, before.last_xp_at) if before.last_xp_at else last_at
                    totals[user_id] = WeeklyXp(before.xp + int(xp), latest)
        return totals

    # --- The admin Leagues page (intent 030) ---------------------------------

    async def weeks(self) -> list[date]:
        """Every week that has a group, newest first."""
        stmt = (
            select(LeagueGroupModel.week_start)
            .distinct()
            .order_by(LeagueGroupModel.week_start.desc())
        )
        return [r[0] for r in (await self._session.execute(stmt)).all()]

    async def admin_groups(self, week: date) -> list[AdminGroupRow]:
        stmt = (
            select(LeagueGroupModel.id, LeagueGroupModel.tier, LeagueGroupModel.closed_at)
            .where(LeagueGroupModel.week_start == week)
            .order_by(LeagueGroupModel.created_at, LeagueGroupModel.id)
        )
        return [
            AdminGroupRow(group_id, LeagueTier(tier), _utc(closed) if closed else None)
            for group_id, tier, closed in (await self._session.execute(stmt)).all()
        ]

    @staticmethod
    def _admin_member_select() -> Select[Any]:
        return select(
            LeagueMemberModel, UserModel.first_name, UserModel.email, UserModel.settings
        ).join(UserModel, UserModel.id == LeagueMemberModel.user_id)

    @staticmethod
    def _admin_member(row: Any) -> AdminMemberRow:
        m, first_name, email, settings = row
        return AdminMemberRow(
            member_id=m.id,
            group_id=m.group_id,
            user_id=m.user_id,
            week_start=m.week_start,
            first_name=first_name,
            email=email,
            settings=dict(settings or {}),
            joined_at=_utc(m.joined_at),
            removed_at=_utc(m.removed_at) if m.removed_at else None,
            removed_reason=m.removed_reason,
            xp_adjustment=m.xp_adjustment or 0,
            xp_adjustment_reason=m.xp_adjustment_reason,
            final_xp=m.final_xp,
            final_rank=m.final_rank,
            tier_after=LeagueTier(m.tier_after) if m.tier_after else None,
            reward_amole=m.reward_amole,
        )

    async def admin_members(self, week: date) -> list[AdminMemberRow]:
        stmt = self._admin_member_select().where(LeagueMemberModel.week_start == week)
        return [self._admin_member(r) for r in (await self._session.execute(stmt)).all()]

    async def admin_member(self, member_id: str) -> AdminMemberRow | None:
        stmt = self._admin_member_select().where(LeagueMemberModel.id == member_id)
        row = (await self._session.execute(stmt)).one_or_none()
        return self._admin_member(row) if row is not None else None

    async def group_closed(self, group_id: str) -> bool:
        stmt = select(LeagueGroupModel.closed_at).where(LeagueGroupModel.id == group_id)
        return (await self._session.execute(stmt)).scalar_one_or_none() is not None

    async def set_removed(self, member_id: str, at: datetime | None, reason: str | None) -> None:
        await self._session.execute(
            update(LeagueMemberModel)
            .where(LeagueMemberModel.id == member_id)
            .values(removed_at=at, removed_reason=reason)
        )

    async def set_xp_adjustment(self, member_id: str, adjustment: int, reason: str | None) -> None:
        await self._session.execute(
            update(LeagueMemberModel)
            .where(LeagueMemberModel.id == member_id)
            .values(xp_adjustment=adjustment, xp_adjustment_reason=reason)
        )


@dataclass(frozen=True)
class AdminGroupRow:
    group_id: str
    tier: LeagueTier
    closed_at: datetime | None


@dataclass(frozen=True)
class AdminMemberRow:
    """A membership as the admin Leagues page needs it."""

    member_id: str
    group_id: str
    user_id: str
    week_start: date
    first_name: str | None
    email: str | None
    settings: dict[str, Any]
    joined_at: datetime
    removed_at: datetime | None
    removed_reason: str | None
    xp_adjustment: int
    xp_adjustment_reason: str | None
    final_xp: int | None
    final_rank: int | None
    tier_after: LeagueTier | None
    reward_amole: int | None
