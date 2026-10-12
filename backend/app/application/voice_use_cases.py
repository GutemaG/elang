"""The voice settings behind generated audio (intent 027, bolt 090): which
Addis AI voice speaks each language, and how fast.

Reading returns every supported language, saved or still on the defaults.
Saving changes one language and is checked here, before the table's own
speed constraint ever sees it.
"""

from __future__ import annotations

import logging
import time
from collections.abc import Awaitable, Callable
from dataclasses import dataclass
from typing import Protocol

from app.application.admin_content_use_cases import AdminContext
from app.domain.lesson.exceptions import (
    ContentNotFoundError,
    InvalidContentError,
    VoiceLanguageMismatchError,
    VoiceNotConfiguredError,
    VoiceServiceError,
    VoiceTextRejectedError,
)
from app.domain.voices import SPEED_MAX, SPEED_MIN, SUPPORTED_VOICE_LANGUAGES, VoiceSettings
from app.infrastructure.external.addis_voice_client import AddisClip, AddisUsage, AddisVoice

logger = logging.getLogger("app.admin")

# The width of the `voice_settings` voice columns.
MAX_VOICE_ID = 80
# How long a language's voice list from Addis is reused.
CATALOG_TTL_SECONDS = 600.0
# Lesson audio is a word, a phrase or a sentence. Addis allows 5000, but
# clips over 60 seconds fail.
MAX_GENERATE_CHARS = 500

AvailableVoices = Callable[[], Awaitable[list[AddisVoice]]]


def _log(ctx: AdminContext, action: str, entity: str, entity_id: str) -> None:
    logger.info(
        "admin_write action=%s entity=%s id=%s admin=%s", action, entity, entity_id, ctx.email
    )


class VoiceSettingsStore(Protocol):
    async def get(self, language: str) -> VoiceSettings: ...

    async def list_all(self) -> list[VoiceSettings]: ...

    async def language_names(self) -> dict[str, str]: ...

    async def save(
        self,
        language: str,
        *,
        male_voice_id: str,
        female_voice_id: str,
        speed: int,
        admin: str,
    ) -> VoiceSettings: ...


class VoiceSource(Protocol):
    async def list_voices(self, language: str) -> list[AddisVoice]: ...

    async def usage(self) -> AddisUsage: ...


class VoiceCatalog:
    """Each language's available voices, fetched from Addis at most once per
    `ttl` seconds in this process. A failed fetch is not kept."""

    def __init__(
        self, *, ttl: float = CATALOG_TTL_SECONDS, clock: Callable[[], float] = time.monotonic
    ) -> None:
        self._ttl = ttl
        self._clock = clock
        self._cached: dict[str, tuple[float, list[AddisVoice]]] = {}

    async def available(self, source: VoiceSource, language: str) -> list[AddisVoice]:
        now = self._clock()
        hit = self._cached.get(language)
        if hit is not None and now - hit[0] < self._ttl:
            return hit[1]
        voices = sorted(
            (v for v in await source.list_voices(language) if v.is_available),
            key=lambda v: (v.sort_order, v.name),
        )
        self._cached[language] = (now, voices)
        return voices


async def list_voice_options(
    source: VoiceSource, catalog: VoiceCatalog, language: str
) -> list[AddisVoice]:
    """The voices an admin may choose for a language."""
    if language not in SUPPORTED_VOICE_LANGUAGES:
        raise InvalidContentError("language", f"Generated voices are not available for {language}")
    return await catalog.available(source, language)


async def get_voice_usage(source: VoiceSource) -> AddisUsage:
    """What is left to spend. Never cached."""
    return await source.usage()


@dataclass(frozen=True)
class AdminVoiceLanguage:
    settings: VoiceSettings
    language_name: str


@dataclass(frozen=True)
class AdminVoiceSettings:
    """`configured`: whether this server can generate audio at all."""

    configured: bool
    languages: list[AdminVoiceLanguage]


async def list_voice_settings(repo: VoiceSettingsStore, *, configured: bool) -> AdminVoiceSettings:
    names = await repo.language_names()
    return AdminVoiceSettings(
        configured=configured,
        languages=[
            AdminVoiceLanguage(s, names.get(s.language, s.language)) for s in await repo.list_all()
        ],
    )


async def _offered(voices: AvailableVoices, language: str, *, male: str, female: str) -> None:
    try:
        offered = {(v.id, v.gender) for v in await voices()}
    except VoiceServiceError as exc:
        logger.info("voice_catalog_unchecked language=%s code=%s", language, exc.error_code)
        return
    for field, voice, gender in (
        ("male_voice_id", male, "male"),
        ("female_voice_id", female, "female"),
    ):
        if (voice, gender) not in offered:
            raise InvalidContentError(field, f"No available {gender} voice {voice}")


def _voice(field: str, value: str, language: str, name: str) -> str:
    voice = value.strip()
    if not voice.startswith(f"{language}-") or len(voice) == len(language) + 1:
        raise InvalidContentError(field, f"That is not a voice for {name}")
    if len(voice) > MAX_VOICE_ID:
        raise InvalidContentError(field, f"A voice id is at most {MAX_VOICE_ID} characters")
    return voice


async def update_voice_settings(
    repo: VoiceSettingsStore,
    ctx: AdminContext,
    language: str,
    *,
    male_voice_id: str,
    female_voice_id: str,
    speed: int,
    voices: AvailableVoices | None = None,
) -> AdminVoiceLanguage:
    """Saves one language's voices and speed. The other language is left
    as it was. With `voices` (a server that has an Addis key), each voice
    must also be offered, available and of its gender; when Addis can't be
    asked, the save goes ahead on the prefix rule alone."""
    if language not in SUPPORTED_VOICE_LANGUAGES:
        raise ContentNotFoundError(
            "No voices for this language", entity="voice_settings", id=language
        )
    if not SPEED_MIN <= speed <= SPEED_MAX:
        raise InvalidContentError(
            "speed", f"Speed is a whole number from {SPEED_MIN} to {SPEED_MAX}"
        )
    name = (await repo.language_names()).get(language, language)
    male = _voice("male_voice_id", male_voice_id, language, name)
    female = _voice("female_voice_id", female_voice_id, language, name)
    if voices is not None:
        await _offered(voices, language, male=male, female=female)
    saved = await repo.save(
        language,
        male_voice_id=male,
        female_voice_id=female,
        speed=speed,
        admin=ctx.email,
    )
    _log(ctx, "update", "voice_settings", language)
    return AdminVoiceLanguage(saved, name)


# --- generating a take (bolt 093) ------------------------------------------------------


class VoiceGenerator(Protocol):
    async def generate(
        self, text: str, *, voice_id: str, language: str, speed: int
    ) -> AddisClip: ...


class LessonLanguages(Protocol):
    async def learning_language_of_lesson(self, lesson_id: str) -> str | None: ...


@dataclass(frozen=True)
class GeneratedVoice:
    clip: AddisClip
    language: str
    voice_id: str


async def _language_of(
    lessons: LessonLanguages, language: str | None, lesson_id: str | None
) -> str:
    if language is not None and lesson_id is not None:
        raise InvalidContentError("language", "Give a language or a lesson, not both")
    if lesson_id is not None:
        found = await lessons.learning_language_of_lesson(lesson_id)
        if found is None:
            raise ContentNotFoundError("No such lesson", entity="lesson", id=lesson_id)
        return found
    if not language:
        raise InvalidContentError("language", "Give a language or a lesson")
    return language


async def generate_voice(
    settings: VoiceSettingsStore,
    lessons: LessonLanguages,
    source: VoiceGenerator | None,
    ctx: AdminContext,
    *,
    text: str,
    gender: str,
    language: str | None = None,
    lesson_id: str | None = None,
    speed: int | None = None,
    voice_id: str | None = None,
) -> GeneratedVoice:
    """A take of `text` in the language's voice for `gender`, for the admin
    to check. Every input is checked before Addis is asked, so a mistake
    costs nothing; nothing is stored."""
    code = await _language_of(lessons, language, lesson_id)
    name = (await settings.language_names()).get(code, code)
    if code not in SUPPORTED_VOICE_LANGUAGES:
        raise InvalidContentError("language", f"Generated voices are not available for {name}")
    words = text.strip()
    if not words:
        raise InvalidContentError("text", "Type the words to say")
    if len(words) > MAX_GENERATE_CHARS:
        raise InvalidContentError(
            "text", f"Up to {MAX_GENERATE_CHARS} characters: a word, a phrase or a sentence"
        )
    if speed is not None and not SPEED_MIN <= speed <= SPEED_MAX:
        raise InvalidContentError(
            "speed", f"Speed is a whole number from {SPEED_MIN} to {SPEED_MAX}"
        )
    saved = await settings.get(code)
    if voice_id is not None:
        voice = _voice("voice_id", voice_id, code, name)
    else:
        voice = saved.male_voice_id if gender == "male" else saved.female_voice_id
    if source is None:
        raise VoiceNotConfiguredError("Generated voices aren't set up on this server.")

    try:
        clip = await source.generate(
            words, voice_id=voice, language=code, speed=saved.speed if speed is None else speed
        )
    except VoiceLanguageMismatchError as exc:
        _log_failure(ctx, exc.error_code, exc.addis_code)
        raise VoiceLanguageMismatchError(
            f"That voice doesn't speak {name}", addis_code=exc.addis_code
        ) from None
    except (VoiceServiceError, VoiceTextRejectedError) as exc:
        _log_failure(ctx, exc.error_code, exc.addis_code)
        raise
    logger.info(
        "admin_write action=generate entity=voice language=%s voice=%s chars=%d "
        "seconds=%.2f admin=%s",
        code,
        voice,
        len(words),
        clip.duration_seconds,
        ctx.email,
    )
    return GeneratedVoice(clip=clip, language=code, voice_id=voice)


def _log_failure(ctx: AdminContext, code: str, addis_code: str | None) -> None:
    logger.info(
        "admin_voice_failed code=%s addis_code=%s admin=%s", code, addis_code or "-", ctx.email
    )
