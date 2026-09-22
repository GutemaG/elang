"""SQLAlchemy async models mapping the `users` and `auth_sessions` tables.

Column definitions mirror `database-schema.md` at the repo root (source of
truth). Types are written to work on both SQLite (local dev/test, per
`data-stack.md`) and PostgreSQL (real deployment) via SQLAlchemy's
database-agnostic column types.
"""

from __future__ import annotations

import uuid
from datetime import UTC, datetime

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    String,
    UniqueConstraint,
)
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


def _utcnow() -> datetime:
    return datetime.now(UTC)


def _uuid_str() -> str:
    return str(uuid.uuid4())


class Base(DeclarativeBase):
    pass


class UserModel(Base):
    """Backs the `User` aggregate. One row per Buna account."""

    __tablename__ = "users"
    __table_args__ = (
        UniqueConstraint("auth_provider", "provider_user_id", name="uq_users_provider_identity"),
        CheckConstraint("auth_provider IN ('google', 'apple')", name="ck_users_auth_provider"),
        CheckConstraint("daily_xp_target > 0", name="ck_users_daily_xp_target_positive"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid_str)
    auth_provider: Mapped[str] = mapped_column(String(16), nullable=False)
    provider_user_id: Mapped[str] = mapped_column(String(255), nullable=False)
    selected_language: Mapped[str] = mapped_column(String(8), nullable=False)
    daily_xp_target: Mapped[int] = mapped_column(nullable=False)
    # New in 013-user-preferences-service. Backfilled `true` for existing
    # rows by the migration (opt-out, not opt-in) -- never null (ADR-7).
    notification_enabled: Mapped[bool] = mapped_column(nullable=False, default=True)
    # Bolt 024 (ADR-12/ADR-13): the user's active course; `selected_language`
    # mirrors its learning language and both are written only by
    # `activate_course_for_user`.
    active_course_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("courses.id"), nullable=False
    )
    # Bolt 034 (ADR-16): the provider-verified email from the latest sign-in,
    # for the `ADMIN_EMAILS` check only. Not unique -- the account key is
    # (`auth_provider`, `provider_user_id`).
    email: Mapped[str | None] = mapped_column(String(320), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )


class AuthSessionModel(Base):
    """Backs the `AuthSession` aggregate. Many rows per `users` row (multi-device)."""

    __tablename__ = "auth_sessions"
    __table_args__ = (
        UniqueConstraint("token_hash", name="uq_auth_sessions_token_hash"),
        Index("ix_auth_sessions_user_id", "user_id"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid_str)
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), nullable=False)
    # SHA-256 hex digest of the opaque session token value (ADR-1). The raw
    # token is never persisted -- only ever held in memory and returned to
    # the client once, at issuance.
    token_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    issued_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
