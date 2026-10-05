"""Tables for the Sounds tab (`app/domain/sounds.py`): one chart per
learning language, and its letters.

`sound_charts.version` goes up on every change to a chart or its letters,
so the app (and any cache in between) can tell a chart it already holds
from a newer one without downloading it.
"""

from __future__ import annotations

import uuid
from datetime import UTC, datetime
from typing import Any

from sqlalchemy import (
    JSON,
    Boolean,
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.domain.sounds import LETTER_STATUSES
from app.infrastructure.db.models import Base

STATUS_VALUES = ", ".join(f"'{s}'" for s in LETTER_STATUSES)


def _utcnow() -> datetime:
    return datetime.now(UTC)


def _uuid_str() -> str:
    return str(uuid.uuid4())


class SoundChartModel(Base):
    """A language's chart. Hidden from learners until `enabled`."""

    __tablename__ = "sound_charts"

    language: Mapped[str] = mapped_column(String(8), ForeignKey("languages.code"), primary_key=True)
    # Display names by app language, e.g. {"en": "Fidel", "am": "ፊደል"}.
    title: Mapped[dict[str, str]] = mapped_column(JSON, nullable=False)
    # The groups in order: [{key, names, columns, column_labels}].
    groups: Mapped[list[dict[str, Any]]] = mapped_column(JSON, nullable=False)
    enabled: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    version: Mapped[int] = mapped_column(Integer, nullable=False, default=1)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )


class SoundLetterModel(Base):
    """One letter of a chart, in its group at `position`."""

    __tablename__ = "sound_letters"
    __table_args__ = (
        CheckConstraint(f"status IN ({STATUS_VALUES})", name="ck_sound_letters_status"),
        Index("ix_sound_letters_language", "language", "group_key", "position"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid_str)
    language: Mapped[str] = mapped_column(
        String(8), ForeignKey("sound_charts.language", ondelete="CASCADE"), nullable=False
    )
    group_key: Mapped[str] = mapped_column(String(32), nullable=False)
    position: Mapped[int] = mapped_column(Integer, nullable=False)
    glyph: Mapped[str] = mapped_column(String(16), nullable=False)
    romanization: Mapped[str] = mapped_column(String(32), nullable=False, default="")
    # "vowel", "consonant" or unmarked (`LETTER_KINDS`); the app colours
    # vowels.
    kind: Mapped[str | None] = mapped_column(String(16), nullable=True)
    # A tip for a hard sound, by app language.
    hint: Mapped[dict[str, str]] = mapped_column(JSON, nullable=False, default=dict)
    audio_url: Mapped[str | None] = mapped_column(String(1024), nullable=True)
    # Another letter of this chart that sounds the same; this one then plays
    # that one's recording and needs none of its own.
    same_as_id: Mapped[str | None] = mapped_column(
        String(36), ForeignKey("sound_letters.id", ondelete="SET NULL"), nullable=True
    )
    example_word: Mapped[str | None] = mapped_column(String(64), nullable=True)
    example_romanization: Mapped[str | None] = mapped_column(String(64), nullable=True)
    example_meaning: Mapped[dict[str, str]] = mapped_column(JSON, nullable=False, default=dict)
    example_audio_url: Mapped[str | None] = mapped_column(String(1024), nullable=True)
    status: Mapped[str] = mapped_column(String(16), nullable=False, default="draft")
    # The speaker, credited in the app.
    recorded_by: Mapped[str | None] = mapped_column(String(120), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )
