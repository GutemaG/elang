"""Unit tests: making a take (intent 027, stories 008-011), against an
in-memory settings store, lesson lookup and Addis fake."""

from __future__ import annotations

import logging
from typing import Any

import pytest

from app.application.admin_content_use_cases import AdminContext
from app.application.voice_use_cases import MAX_GENERATE_CHARS, generate_voice
from app.domain.lesson.exceptions import (
    ContentNotFoundError,
    InvalidContentError,
    VoiceCreditExhaustedError,
    VoiceLanguageMismatchError,
    VoiceNotConfiguredError,
    VoiceTextRejectedError,
)
from app.domain.voices import VoiceSettings, default_voice_settings
from app.infrastructure.external.addis_voice_client import AddisClip

CTX = AdminContext(email="admin@example.com")
TEXT = "Maqaan koo Saaraa dha."


class Settings:
    def __init__(self) -> None:
        self.saved = {"om": VoiceSettings("om", "om-diriba", "om-obse", 40)}

    async def get(self, language: str) -> VoiceSettings:
        return self.saved.get(language) or default_voice_settings(language)

    async def list_all(self) -> list[VoiceSettings]:
        return []

    async def language_names(self) -> dict[str, str]:
        return {"am": "Amharic", "om": "Afaan Oromo", "en": "English"}

    async def save(self, language: str, **kw: Any) -> VoiceSettings:
        raise AssertionError("generating never saves settings")


class Lessons:
    async def learning_language_of_lesson(self, lesson_id: str) -> str | None:
        return {"lesson-am": "am", "lesson-en": "en"}.get(lesson_id)


class Addis:
    def __init__(self, error: Exception | None = None) -> None:
        self.calls: list[dict[str, Any]] = []
        self.error = error

    async def generate(self, text: str, *, voice_id: str, language: str, speed: int) -> AddisClip:
        self.calls.append(
            {"text": text, "voice_id": voice_id, "language": language, "speed": speed}
        )
        if self.error is not None:
            raise self.error
        return AddisClip(b"mp3", 1.83, voice_id, voice_id.split("-")[1].title(), len(text), 497.5)


async def _go(addis: Addis | None = None, **kw: Any) -> Any:
    args: dict[str, Any] = {"text": TEXT, "gender": "female", "language": "om"} | kw
    return await generate_voice(Settings(), Lessons(), addis or Addis(), CTX, **args)


# --- the voice and speed -------------------------------------------------------------


async def test_the_saved_voice_for_the_gender_and_the_saved_speed() -> None:
    addis = Addis()

    take = await _go(addis)
    await _go(addis, gender="male")

    assert addis.calls[0] == {"text": TEXT, "voice_id": "om-obse", "language": "om", "speed": 40}
    assert addis.calls[1]["voice_id"] == "om-diriba"
    assert (take.language, take.voice_id, take.clip.audio) == ("om", "om-obse", b"mp3")


async def test_a_language_never_saved_uses_the_defaults() -> None:
    addis = Addis()

    await _go(addis, language="am", gender="male", text="ሰላም")

    assert (addis.calls[0]["voice_id"], addis.calls[0]["speed"]) == ("am-yohanes-calm", 50)


async def test_speed_and_voice_can_be_overridden_for_one_take() -> None:
    addis = Addis()

    take = await _go(addis, speed=0, voice_id=" om-hawi ")

    assert (addis.calls[0]["voice_id"], addis.calls[0]["speed"]) == ("om-hawi", 0)
    assert take.voice_id == "om-hawi"


async def test_a_lesson_gives_its_course_language() -> None:
    addis = Addis()

    await _go(addis, language=None, lesson_id="lesson-am", text="ሰላም")

    assert addis.calls[0]["language"] == "am"
    assert addis.calls[0]["voice_id"] == "am-loza"


async def test_the_text_is_trimmed_and_otherwise_sent_as_typed() -> None:
    addis = Addis()

    await _go(addis, text="  Maqaan koo … dha.  ")

    assert addis.calls[0]["text"] == "Maqaan koo … dha."


async def test_exactly_500_characters_is_allowed() -> None:
    addis = Addis()

    await _go(addis, text="a" * MAX_GENERATE_CHARS)

    assert len(addis.calls) == 1


# --- refused before Addis is asked ---------------------------------------------------


@pytest.mark.parametrize(
    ("kw", "field", "message"),
    [
        ({"lesson_id": "lesson-am"}, "language", "Give a language or a lesson, not both"),
        ({"language": None}, "language", "Give a language or a lesson"),
        ({"language": "ti"}, "language", "Generated voices are not available for ti"),
        ({"language": "en"}, "language", "Generated voices are not available for English"),
        ({"text": "   "}, "text", "Type the words to say"),
        (
            {"text": "a" * (MAX_GENERATE_CHARS + 1)},
            "text",
            "Up to 500 characters: a word, a phrase or a sentence",
        ),
        ({"speed": 101}, "speed", "Speed is a whole number from 0 to 100"),
        ({"speed": -1}, "speed", "Speed is a whole number from 0 to 100"),
        ({"voice_id": "am-loza"}, "voice_id", "That is not a voice for Afaan Oromo"),
    ],
)
async def test_bad_input_is_refused_without_asking_addis(
    kw: dict[str, Any], field: str, message: str
) -> None:
    addis = Addis()

    with pytest.raises(InvalidContentError) as caught:
        await _go(addis, **kw)

    assert (caught.value.field, caught.value.message) == (field, message)
    assert addis.calls == []


async def test_an_unknown_lesson() -> None:
    with pytest.raises(ContentNotFoundError) as caught:
        await _go(language=None, lesson_id="nope")

    assert caught.value.details == {"entity": "lesson", "id": "nope"}


async def test_a_lesson_in_a_language_without_voices() -> None:
    with pytest.raises(InvalidContentError) as caught:
        await _go(language=None, lesson_id="lesson-en")

    assert caught.value.message == "Generated voices are not available for English"


async def test_input_is_checked_even_without_a_key() -> None:
    with pytest.raises(InvalidContentError):
        await generate_voice(
            Settings(), Lessons(), None, CTX, text="", gender="male", language="om"
        )


async def test_without_a_key() -> None:
    with pytest.raises(VoiceNotConfiguredError):
        await generate_voice(
            Settings(), Lessons(), None, CTX, text=TEXT, gender="male", language="om"
        )


# --- Addis's refusals ------------------------------------------------------------------


async def test_a_mismatch_is_told_in_our_words() -> None:
    error = VoiceLanguageMismatchError("Addis words", addis_code="VOICE_LANGUAGE_MISMATCH")

    with pytest.raises(VoiceLanguageMismatchError) as caught:
        await _go(Addis(error))

    assert caught.value.message == "That voice doesn't speak Afaan Oromo"
    assert caught.value.field == "voice_id"


@pytest.mark.parametrize(
    "error",
    [
        VoiceCreditExhaustedError("The Addis AI credit has run out.", addis_code="WALLET_EMPTY"),
        VoiceTextRejectedError("The voice service couldn't read this text", addis_code="TEXT_X"),
    ],
)
async def test_other_refusals_pass_through_and_are_logged(
    error: Exception, caplog: pytest.LogCaptureFixture
) -> None:
    with caplog.at_level(logging.INFO, logger="app.admin"), pytest.raises(type(error)):
        await _go(Addis(error))

    assert f"admin_voice_failed code={error.error_code}" in caplog.text  # type: ignore[attr-defined]
    assert "admin=admin@example.com" in caplog.text
    assert TEXT not in caplog.text


# --- the log ---------------------------------------------------------------------------


async def test_a_take_is_logged_without_its_text(caplog: pytest.LogCaptureFixture) -> None:
    with caplog.at_level(logging.INFO, logger="app.admin"):
        await _go()

    assert (
        "admin_write action=generate entity=voice language=om voice=om-obse chars=22 "
        "seconds=1.83 admin=admin@example.com"
    ) in caplog.text
    assert "Maqaan" not in caplog.text
