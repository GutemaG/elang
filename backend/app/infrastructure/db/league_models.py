"""SQLAlchemy models for weekly leagues (023-weekly-leagues, bolt 073):
`league_groups` and `league_members`. Same `Base` as every other table.

A learner's weekly XP is never stored while the week is open: it is summed
from `lesson_attempts` and `practice_attempts`. The `final_*`, `tier_after`,
`reward_amole` and `result_seen_at` columns are written when a week closes
(bolt 074).
"""

from __future__ import annotations

import uuid
from datetime import UTC, date, datetime

from sqlalchemy import (
    CheckConstraint,
    Date,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.infrastructure.db.models import Base

TIER_VALUES = "'green_bean', 'light_roast', 'medium_roast', 'dark_roast', 'golden_cup'"


def _utcnow() -> datetime:
    return datetime.now(UTC)


def _uuid_str() -> str:
    return str(uuid.uuid4())


class LeagueGroupModel(Base):
    """Up to 30 learners of one tier in one week."""

    __tablename__ = "league_groups"
    __table_args__ = (
        CheckConstraint(f"tier IN ({TIER_VALUES})", name="ck_league_groups_tier"),
        Index("ix_league_groups_week_tier", "week_start", "tier"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid_str)
    # The Monday (UTC) the week starts on.
    week_start: Mapped[date] = mapped_column(Date, nullable=False)
    tier: Mapped[str] = mapped_column(String(16), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )
    # Set once, when the week has ended and the group's results are stored.
    closed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class LeagueMemberModel(Base):
    """One learner in one week's group. A learner has at most one per week:
    the unique constraint, not only the code, guarantees it."""

    __tablename__ = "league_members"
    __table_args__ = (
        UniqueConstraint("user_id", "week_start", name="uq_league_members_user_week"),
        CheckConstraint(
            f"tier_after IS NULL OR tier_after IN ({TIER_VALUES})",
            name="ck_league_members_tier_after",
        ),
        Index("ix_league_members_group_id", "group_id"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid_str)
    group_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("league_groups.id"), nullable=False
    )
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), nullable=False)
    # The group's week, copied here so (user, week) can be unique.
    week_start: Mapped[date] = mapped_column(Date, nullable=False)
    joined_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    # Written when the week closes (bolt 074).
    final_xp: Mapped[int | None] = mapped_column(Integer, nullable=True)
    final_rank: Mapped[int | None] = mapped_column(Integer, nullable=True)
    tier_after: Mapped[str | None] = mapped_column(String(16), nullable=True)
    reward_amole: Mapped[int | None] = mapped_column(Integer, nullable=True)
    result_seen_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
