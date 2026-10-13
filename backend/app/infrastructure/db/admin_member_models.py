"""The team behind the Team page (`app/domain/admin.py`, intent 028): the
admins who are not owners, and the courses each course admin works on.

Owners are not stored here; they come from `ADMIN_EMAILS`. A super
admin has no course rows: they reach every course.
"""

from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.domain.admin import ADMIN_ROLES
from app.infrastructure.db.models import Base

_ROLES = ", ".join(f"'{r}'" for r in ADMIN_ROLES)


def _uuid_str() -> str:
    return str(uuid.uuid4())


class AdminMemberModel(Base):
    __tablename__ = "admin_members"
    __table_args__ = (
        UniqueConstraint("email", name="uq_admin_members_email"),
        CheckConstraint(f"role IN ({_ROLES})", name="ck_admin_members_role"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid_str)
    # Trimmed and lower-case (`normalise_email`).
    email: Mapped[str] = mapped_column(String(320), nullable=False)
    role: Mapped[str] = mapped_column(String(20), nullable=False)
    # The admins' emails who added and last changed this member.
    created_by: Mapped[str] = mapped_column(String(320), nullable=False)
    updated_by: Mapped[str] = mapped_column(String(320), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)


class AdminMemberCourseModel(Base):
    """One course a course admin works on."""

    __tablename__ = "admin_member_courses"

    member_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("admin_members.id", ondelete="CASCADE"), primary_key=True
    )
    course_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("courses.id", ondelete="CASCADE"), primary_key=True, index=True
    )
