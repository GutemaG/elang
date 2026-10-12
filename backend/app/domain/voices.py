"""Generated voices (intent 027): which Addis AI voice speaks each learning
language, and how fast.

Each language Addis AI speaks has one male and one female voice and a
default speed, set by an admin on the Voices page. Until an admin saves
them, a language uses the defaults here. A speed is Addis's own scale,
0 to 100, where 50 is its normal pace.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from datetime import datetime

from app.domain.lesson.exceptions import InvalidContentError

# The learning languages Addis AI has voices for, in the order the admin
# shows them.
SUPPORTED_VOICE_LANGUAGES = ("am", "om")

SPEED_MIN = 0
SPEED_MAX = 100
DEFAULT_SPEED = 50

# language -> (male voice, female voice), the owner's choice (2026-10-12).
DEFAULT_VOICES: dict[str, tuple[str, str]] = {
    "am": ("am-yohanes-calm", "am-loza"),
    "om": ("om-diriba", "om-obse"),
}


@dataclass(frozen=True)
class VoiceSettings:
    """A language's voices and speed. `updated_by` and `updated_at` are
    None while the language still uses the defaults."""

    language: str
    male_voice_id: str
    female_voice_id: str
    speed: int
    updated_by: str | None = None
    updated_at: datetime | None = None


# A kept take's tag, `gen-{voice id}` (bolt 099): put at the front of its
# stored name so the admin can show who spoke it, with no column for it.
GENERATED_SOURCE = re.compile(r"gen-(am|om)-[a-z0-9-]{1,40}")


def key_prefix(source: str | None) -> str:
    """What goes before a stored clip's random name: nothing for a clip
    that wasn't generated, `{source}-` for one that was."""
    if source is None:
        return ""
    if GENERATED_SOURCE.fullmatch(source) is None:
        raise InvalidContentError("source", "That is not a generated voice's tag")
    return f"{source}-"


def default_voice_settings(language: str) -> VoiceSettings:
    """The defaults for a supported language. Raises KeyError for any other."""
    male, female = DEFAULT_VOICES[language]
    return VoiceSettings(
        language=language, male_voice_id=male, female_voice_id=female, speed=DEFAULT_SPEED
    )
