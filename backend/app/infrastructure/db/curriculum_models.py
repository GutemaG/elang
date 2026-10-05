"""Tables for a course's draft curriculum (`app/domain/curriculum.py`):
the plan's entries (sections, skills, lessons), each lesson's rows (words
and sentences) and its draft exercises. Learners never read them; a
published lesson is copied into the live tables, and these remember where.
"""

from __future__ import annotations

import uuid
from datetime import UTC, datetime

from sqlalchemy import (
    JSON,
    Boolean,
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.domain.curriculum import CONFIDENCES, ENTRY_KINDS, ROW_KINDS, ROW_STATUSES
from app.infrastructure.db.models import Base


def _values(items: tuple[str, ...]) -> str:
    return ", ".join(f"'{s}'" for s in items)


def _utcnow() -> datetime:
    return datetime.now(UTC)


def _uuid_str() -> str:
    return str(uuid.uuid4())


class CurriculumEntryModel(Base):
    """A section, skill or lesson of a course's plan, found by its `ref`."""

    __tablename__ = "curriculum_entries"
    __table_args__ = (
        UniqueConstraint("course_id", "ref", name="uq_curriculum_entries_course_ref"),
        CheckConstraint(f"kind IN ({_values(ENTRY_KINDS)})", name="ck_curriculum_entries_kind"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid_str)
    course_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("courses.id", ondelete="CASCADE"), nullable=False
    )
    ref: Mapped[str] = mapped_column(String(32), nullable=False)
    kind: Mapped[str] = mapped_column(String(16), nullable=False)
    # The section of a skill, or the skill of a lesson; null for a section.
    parent_ref: Mapped[str | None] = mapped_column(String(32), nullable=True)
    # Order among its parent's children.
    position: Mapped[int] = mapped_column(Integer, nullable=False)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    # The CEFR can-do goal, and a grammar note for the course's language.
    goal: Mapped[str | None] = mapped_column(Text, nullable=True)
    grammar: Mapped[str | None] = mapped_column(Text, nullable=True)
    # Bolt 085: the category, skill or lesson published from this entry;
    # and for a lesson, the exercises it published and when.
    published_id: Mapped[str | None] = mapped_column(String(36), nullable=True)
    published_exercise_ids: Mapped[list[str]] = mapped_column(JSON, nullable=False, default=list)
    published_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )


class CurriculumRowModel(Base):
    """A word or sentence a lesson teaches, with its review and recording.
    `version` goes up on every change, so an edit made from an old copy is
    refused instead of undoing someone's work."""

    __tablename__ = "curriculum_rows"
    __table_args__ = (
        UniqueConstraint("course_id", "ref", name="uq_curriculum_rows_course_ref"),
        CheckConstraint(f"kind IN ({_values(ROW_KINDS)})", name="ck_curriculum_rows_kind"),
        CheckConstraint(f"status IN ({_values(ROW_STATUSES)})", name="ck_curriculum_rows_status"),
        CheckConstraint(
            f"confidence IS NULL OR confidence IN ({_values(CONFIDENCES)})",
            name="ck_curriculum_rows_confidence",
        ),
        Index("ix_curriculum_rows_lesson", "course_id", "lesson_ref", "position"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid_str)
    course_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("courses.id", ondelete="CASCADE"), nullable=False
    )
    ref: Mapped[str] = mapped_column(String(32), nullable=False)
    kind: Mapped[str] = mapped_column(String(16), nullable=False)
    lesson_ref: Mapped[str] = mapped_column(String(32), nullable=False)
    position: Mapped[int] = mapped_column(Integer, nullable=False)
    english: Mapped[str] = mapped_column(Text, nullable=False)
    # In the course's language (Fidel for Amharic, Qubee for Afaan Oromo);
    # null until someone writes it.
    text: Mapped[str | None] = mapped_column(Text, nullable=True)
    romanization: Mapped[str | None] = mapped_column(Text, nullable=True)
    # A sentence's word the gap-fill exercise hides, and other correct
    # translations.
    blank: Mapped[str | None] = mapped_column(Text, nullable=True)
    accepted: Mapped[list[str]] = mapped_column(JSON, nullable=False, default=list)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    confidence: Mapped[str | None] = mapped_column(String(16), nullable=True)
    status: Mapped[str] = mapped_column(String(16), nullable=False, default="to_do")
    comment: Mapped[str | None] = mapped_column(Text, nullable=True)
    audio_url: Mapped[str | None] = mapped_column(String(1024), nullable=True)
    version: Mapped[int] = mapped_column(Integer, nullable=False, default=1)
    # Bolt 085: a word's vocabulary item, made when its lesson is published.
    vocab_item_id: Mapped[str | None] = mapped_column(String(36), nullable=True)
    updated_by: Mapped[str | None] = mapped_column(String(320), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )


class CurriculumExerciseModel(Base):
    """One of a lesson's draft exercises, in the live exercise format, until
    the lesson is published. `generated` is the body it was generated as,
    so an edited one can be told apart and reset; `vocab_ref` is the word
    row it practises."""

    __tablename__ = "curriculum_exercises"
    __table_args__ = (
        Index("ix_curriculum_exercises_lesson", "course_id", "lesson_ref", "position"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid_str)
    course_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("courses.id", ondelete="CASCADE"), nullable=False
    )
    lesson_ref: Mapped[str] = mapped_column(String(32), nullable=False)
    position: Mapped[int] = mapped_column(Integer, nullable=False)
    type: Mapped[str] = mapped_column(String(32), nullable=False)
    prompt: Mapped[str] = mapped_column(Text, nullable=False)
    content: Mapped[dict] = mapped_column(JSON, nullable=False)
    answer_key: Mapped[dict] = mapped_column(JSON, nullable=False)
    vocab_ref: Mapped[str | None] = mapped_column(String(32), nullable=True)
    generated: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    edited: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )
