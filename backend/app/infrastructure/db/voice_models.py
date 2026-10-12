"""The table behind the Voices page (`app/domain/voices.py`): a saved row
per language. A language without a row uses the defaults in code.

`language` is an Addis AI language code, not a foreign key to
`languages`, so a database without that course language can still keep
its voices.
"""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import CheckConstraint, DateTime, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.domain.voices import SPEED_MAX, SPEED_MIN
from app.infrastructure.db.models import Base


class VoiceSettingsModel(Base):
    __tablename__ = "voice_settings"
    __table_args__ = (
        CheckConstraint(
            f"speed BETWEEN {SPEED_MIN} AND {SPEED_MAX}", name="ck_voice_settings_speed"
        ),
    )

    language: Mapped[str] = mapped_column(String(8), primary_key=True)
    male_voice_id: Mapped[str] = mapped_column(String(80), nullable=False)
    female_voice_id: Mapped[str] = mapped_column(String(80), nullable=False)
    speed: Mapped[int] = mapped_column(Integer, nullable=False)
    # The admin's email, and when they saved.
    updated_by: Mapped[str | None] = mapped_column(String(320), nullable=True)
    updated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
