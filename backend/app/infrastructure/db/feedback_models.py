"""SQLAlchemy model for learner feedback (027-learner-feedback): what a
learner sends from the app's Settings, read on the admin site. Same `Base`
as every other table.
"""

from __future__ import annotations

import uuid
from datetime import UTC, datetime

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Index, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.infrastructure.db.models import Base

CATEGORY_VALUES = "'bug', 'idea', 'content', 'other'"
STATUS_VALUES = "'open', 'resolved'"


def _utcnow() -> datetime:
    return datetime.now(UTC)


def _uuid_str() -> str:
    return str(uuid.uuid4())


class FeedbackModel(Base):
    """One message from one learner. `course_id` is the course they were
    on when they sent it, kept as a plain id so deleting a course keeps
    the message."""

    __tablename__ = "feedback"
    __table_args__ = (
        CheckConstraint(f"category IN ({CATEGORY_VALUES})", name="ck_feedback_category"),
        CheckConstraint(f"status IN ({STATUS_VALUES})", name="ck_feedback_status"),
        CheckConstraint("rating IS NULL OR rating BETWEEN 1 AND 5", name="ck_feedback_rating"),
        Index("ix_feedback_created_at", "created_at"),
        Index("ix_feedback_user_id", "user_id"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid_str)
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), nullable=False)
    category: Mapped[str] = mapped_column(String(16), nullable=False)
    # 1 to 5, or none when the learner skipped it.
    rating: Mapped[int | None] = mapped_column(Integer, nullable=True)
    message: Mapped[str] = mapped_column(Text, nullable=False)
    course_id: Mapped[str | None] = mapped_column(String(36), nullable=True)
    # `android`, `ios`, `web` and so on, as the app reports it.
    platform: Mapped[str | None] = mapped_column(String(16), nullable=True)
    status: Mapped[str] = mapped_column(String(16), nullable=False, default="open")
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )
    resolved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
