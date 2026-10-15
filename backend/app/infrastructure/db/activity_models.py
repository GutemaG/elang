"""SQLAlchemy model for the admin activity log (intent 030):
`admin_activity`, one row per successful admin change. Same `Base` as every
other table.

Ids are plain strings, not foreign keys: an entry outlives what it names
(a deleted lesson, a removed team member).
"""

from __future__ import annotations

import uuid
from datetime import UTC, datetime
from typing import Any

from sqlalchemy import JSON, DateTime, Index, String
from sqlalchemy.orm import Mapped, mapped_column

from app.infrastructure.db.models import Base


def _utcnow() -> datetime:
    return datetime.now(UTC)


def _uuid_str() -> str:
    return str(uuid.uuid4())


class AdminActivityModel(Base):
    __tablename__ = "admin_activity"
    __table_args__ = (
        Index("ix_admin_activity_created_at", "created_at"),
        Index("ix_admin_activity_admin_email", "admin_email"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid_str)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )
    admin_email: Mapped[str] = mapped_column(String(320), nullable=False)
    admin_role: Mapped[str] = mapped_column(String(20), nullable=False)
    method: Mapped[str] = mapped_column(String(8), nullable=False)
    # The route as FastAPI declares it, placeholders included.
    route: Mapped[str] = mapped_column(String(255), nullable=False)
    area: Mapped[str] = mapped_column(String(32), nullable=False)
    action: Mapped[str] = mapped_column(String(64), nullable=False)
    target_kind: Mapped[str | None] = mapped_column(String(32), nullable=True)
    target_id: Mapped[str | None] = mapped_column(String(255), nullable=True)
    target_name: Mapped[str | None] = mapped_column(String(255), nullable=True)
    course_id: Mapped[str | None] = mapped_column(String(36), nullable=True)
    # Where the target opens in the admin site, as it was when recorded.
    link: Mapped[str | None] = mapped_column(String(512), nullable=True)
    details: Mapped[dict[str, Any]] = mapped_column(JSON, nullable=False, default=dict)
