"""Reads and writes the voice settings (`voice_models.py`). Hands back
domain `VoiceSettings`, the defaults for a language with no saved row.

No checks here: the use case validates, and the table's check constraint
refuses a speed outside 0 to 100 whatever happens.
"""

from __future__ import annotations

from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.voices import SUPPORTED_VOICE_LANGUAGES, VoiceSettings, default_voice_settings
from app.infrastructure.db.lesson_models import LanguageModel
from app.infrastructure.db.voice_models import VoiceSettingsModel


def _utc(value: datetime | None) -> datetime | None:
    """SQLite hands timestamps back without a zone; they were saved in UTC."""
    if value is None:
        return None
    return value.replace(tzinfo=UTC) if value.tzinfo is None else value.astimezone(UTC)


def _settings(row: VoiceSettingsModel) -> VoiceSettings:
    return VoiceSettings(
        language=row.language,
        male_voice_id=row.male_voice_id,
        female_voice_id=row.female_voice_id,
        speed=row.speed,
        updated_by=row.updated_by,
        updated_at=_utc(row.updated_at),
    )


class SqlAlchemyVoiceSettingsRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get(self, language: str) -> VoiceSettings:
        """The saved settings, or the defaults. `language` must be supported."""
        row = await self._session.get(VoiceSettingsModel, language)
        return _settings(row) if row is not None else default_voice_settings(language)

    async def list_all(self) -> list[VoiceSettings]:
        """Every supported language, in order, in one query."""
        stmt = select(VoiceSettingsModel).where(
            VoiceSettingsModel.language.in_(SUPPORTED_VOICE_LANGUAGES)
        )
        saved = {row.language: row for row in (await self._session.execute(stmt)).scalars()}
        return [
            _settings(saved[code]) if code in saved else default_voice_settings(code)
            for code in SUPPORTED_VOICE_LANGUAGES
        ]

    async def language_names(self) -> dict[str, str]:
        """code -> English name, for the supported languages the languages
        table has. A missing one is left out; callers show its code."""
        stmt = select(LanguageModel.code, LanguageModel.name).where(
            LanguageModel.code.in_(SUPPORTED_VOICE_LANGUAGES)
        )
        return {code: name for code, name in (await self._session.execute(stmt)).all()}

    async def save(
        self,
        language: str,
        *,
        male_voice_id: str,
        female_voice_id: str,
        speed: int,
        admin: str,
    ) -> VoiceSettings:
        """Inserts the language's row the first time, updates it after."""
        row = await self._session.get(VoiceSettingsModel, language)
        if row is None:
            row = VoiceSettingsModel(language=language)
            self._session.add(row)
        row.male_voice_id = male_voice_id
        row.female_voice_id = female_voice_id
        row.speed = speed
        row.updated_by = admin
        row.updated_at = datetime.now(UTC)
        await self._session.flush()
        return _settings(row)
