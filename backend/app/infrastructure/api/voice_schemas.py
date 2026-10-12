"""Request and response bodies for the voice settings admin API
(`voice_routers.py`)."""

from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, StrictInt


class AdminVoiceLanguageResponse(BaseModel):
    language: str
    language_name: str
    male_voice_id: str
    female_voice_id: str
    speed: int
    # Null while the language still uses the default voices.
    updated_by: str | None
    updated_at: datetime | None


class AdminVoiceSettingsResponse(BaseModel):
    # Whether this server can generate audio (an Addis AI key is set).
    configured: bool
    languages: list[AdminVoiceLanguageResponse]


class UpdateVoiceSettingsRequest(BaseModel):
    male_voice_id: str
    female_voice_id: str
    # Whole numbers only: 40.5 or "40" are refused rather than rounded.
    speed: StrictInt


class AdminVoiceOption(BaseModel):
    id: str
    name: str
    descriptor: str
    gender: str
    style: str
    preview_audio_url: str | None


class AdminVoiceCatalogResponse(BaseModel):
    language: str
    # Available voices only, in Addis's order.
    voices: list[AdminVoiceOption]


class AdminVoiceUsageResponse(BaseModel):
    balance: float
    currency: str
    # Addis's own rendering, e.g. "Br 997.53".
    formatted_balance: str
    price_per_minute: float | None
    max_characters: int | None


class GenerateVoiceRequest(BaseModel):
    """One of `language` or `lesson_id`. `speed` and `voice_id` override the
    language's settings for this take only (the Voices page's Try it)."""

    text: str
    gender: Literal["male", "female"]
    language: str | None = None
    lesson_id: str | None = None
    speed: StrictInt | None = None
    voice_id: str | None = None
