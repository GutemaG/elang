"""Unit tests: the voice settings use cases (intent 027, stories 002 and
003) against an in-memory store."""

from __future__ import annotations

import logging
from dataclasses import replace
from datetime import UTC, datetime
from typing import Any

import pytest

from app.application.admin_content_use_cases import AdminContext
from app.application.voice_use_cases import (
    MAX_VOICE_ID,
    AdminVoiceLanguage,
    list_voice_settings,
    update_voice_settings,
)
from app.domain.lesson.exceptions import (
    ContentNotFoundError,
    InvalidContentError,
    VoiceRateLimitedError,
)
from app.domain.voices import SUPPORTED_VOICE_LANGUAGES, VoiceSettings, default_voice_settings
from app.infrastructure.external.addis_voice_client import AddisVoice

CTX = AdminContext(email="admin@example.com")


class MemoryStore:
    def __init__(self, names: dict[str, str] | None = None) -> None:
        self.rows: dict[str, VoiceSettings] = {}
        self.names = {"am": "Amharic", "om": "Afaan Oromo"} if names is None else names
        self.saves = 0

    async def get(self, language: str) -> VoiceSettings:
        return self.rows.get(language) or default_voice_settings(language)

    async def list_all(self) -> list[VoiceSettings]:
        return [await self.get(code) for code in SUPPORTED_VOICE_LANGUAGES]

    async def language_names(self) -> dict[str, str]:
        return self.names

    async def save(
        self,
        language: str,
        *,
        male_voice_id: str,
        female_voice_id: str,
        speed: int,
        admin: str,
    ) -> VoiceSettings:
        self.saves += 1
        row = VoiceSettings(
            language, male_voice_id, female_voice_id, speed, admin, datetime.now(UTC)
        )
        self.rows[language] = row
        return row


async def _update(store: MemoryStore, language: str = "om", **kw: Any) -> AdminVoiceLanguage:
    args: dict[str, Any] = {
        "male_voice_id": "om-diriba",
        "female_voice_id": "om-obse",
        "speed": 50,
    } | kw
    return await update_voice_settings(store, CTX, language, **args)


async def test_listing_names_each_language_and_falls_back_to_its_code() -> None:
    result = await list_voice_settings(MemoryStore({"am": "Amharic"}), configured=True)

    assert result.configured is True
    assert [(v.settings.language, v.language_name) for v in result.languages] == [
        ("am", "Amharic"),
        ("om", "om"),
    ]


async def test_the_language_is_checked_before_the_speed() -> None:
    store = MemoryStore()

    with pytest.raises(ContentNotFoundError):
        await _update(store, "ti", speed=500)


async def test_the_speed_is_checked_before_the_voices() -> None:
    with pytest.raises(InvalidContentError) as caught:
        await _update(MemoryStore(), speed=500, male_voice_id="am-simon")

    assert caught.value.field == "speed"


async def test_the_male_voice_is_checked_before_the_female() -> None:
    with pytest.raises(InvalidContentError) as caught:
        await _update(MemoryStore(), male_voice_id="am-simon", female_voice_id="am-loza")

    assert caught.value.field == "male_voice_id"


async def test_a_voice_id_longer_than_the_column_is_refused() -> None:
    with pytest.raises(InvalidContentError) as caught:
        await _update(MemoryStore(), female_voice_id="om-" + "x" * MAX_VOICE_ID)

    assert caught.value.field == "female_voice_id"


async def test_a_refused_save_stores_nothing() -> None:
    store = MemoryStore()

    with pytest.raises(InvalidContentError):
        await _update(store, speed=-1)

    assert store.saves == 0


async def test_voices_are_trimmed_and_the_admin_recorded() -> None:
    store = MemoryStore()

    saved = await _update(store, male_voice_id="  om-bikila ", speed=0)

    assert replace(saved.settings, updated_at=None) == VoiceSettings(
        "om", "om-bikila", "om-obse", 0, "admin@example.com", None
    )
    assert saved.language_name == "Afaan Oromo"


# --- the catalog check on save (bolt 092) --------------------------------------------


def _offer(*voices: tuple[str, str]) -> Any:
    async def offered() -> list[AddisVoice]:
        return [AddisVoice(v, v, "", g, "", None, True, 0) for v, g in voices]

    return offered


OFFERED = _offer(("om-diriba", "male"), ("om-obse", "female"), ("om-hawi", "female"))


async def test_offered_voices_of_the_right_gender_are_saved() -> None:
    store = MemoryStore()

    saved = await _update(store, female_voice_id="om-hawi", voices=OFFERED)

    assert saved.settings.female_voice_id == "om-hawi"


@pytest.mark.parametrize(
    ("kw", "field", "message"),
    [
        ({"male_voice_id": "om-ghost"}, "male_voice_id", "No available male voice om-ghost"),
        ({"male_voice_id": "om-obse"}, "male_voice_id", "No available male voice om-obse"),
        (
            {"female_voice_id": "om-diriba"},
            "female_voice_id",
            "No available female voice om-diriba",
        ),
    ],
)
async def test_a_voice_not_offered_or_of_the_wrong_gender_is_refused(
    kw: dict[str, str], field: str, message: str
) -> None:
    store = MemoryStore()

    with pytest.raises(InvalidContentError) as caught:
        await _update(store, voices=OFFERED, **kw)

    assert (caught.value.field, caught.value.message) == (field, message)
    assert store.saves == 0


async def test_when_addis_cannot_be_asked_the_save_goes_ahead(
    caplog: pytest.LogCaptureFixture,
) -> None:
    async def down() -> list[Any]:
        raise VoiceRateLimitedError("busy")

    with caplog.at_level(logging.INFO, logger="app.admin"):
        saved = await _update(MemoryStore(), male_voice_id="om-ghost", voices=down)

    assert saved.settings.male_voice_id == "om-ghost"
    assert "voice_catalog_unchecked language=om code=voice_rate_limited" in caplog.text


async def test_the_catalog_is_not_asked_when_the_prefix_rule_fails() -> None:
    asked: list[bool] = []

    async def voices() -> list[Any]:
        asked.append(True)
        return []

    with pytest.raises(InvalidContentError):
        await _update(MemoryStore(), male_voice_id="am-simon", voices=voices)

    assert asked == []
