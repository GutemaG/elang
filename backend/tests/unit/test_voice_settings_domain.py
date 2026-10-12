"""Unit tests: the default voices for generated audio (intent 027, story
001)."""

from __future__ import annotations

import pytest

from app.domain.lesson.exceptions import InvalidContentError
from app.domain.voices import (
    DEFAULT_SPEED,
    DEFAULT_VOICES,
    SPEED_MAX,
    SPEED_MIN,
    SUPPORTED_VOICE_LANGUAGES,
    VoiceSettings,
    default_voice_settings,
    key_prefix,
)


def test_amharic_and_afaan_oromo_are_supported_in_that_order() -> None:
    assert SUPPORTED_VOICE_LANGUAGES == ("am", "om")
    assert set(DEFAULT_VOICES) == set(SUPPORTED_VOICE_LANGUAGES)


def test_speed_is_addis_scale_with_its_normal_pace_as_default() -> None:
    assert (SPEED_MIN, SPEED_MAX, DEFAULT_SPEED) == (0, 100, 50)


def test_the_owner_s_default_voices() -> None:
    assert default_voice_settings("am") == VoiceSettings("am", "am-yohanes-calm", "am-loza", 50)
    assert default_voice_settings("om") == VoiceSettings("om", "om-diriba", "om-obse", 50)


def test_defaults_were_never_saved() -> None:
    settings = default_voice_settings("om")

    assert settings.updated_by is None
    assert settings.updated_at is None


def test_every_default_voice_belongs_to_its_language() -> None:
    for language, voices in DEFAULT_VOICES.items():
        assert all(v.startswith(f"{language}-") for v in voices)


def test_an_unsupported_language_has_no_defaults() -> None:
    with pytest.raises(KeyError):
        default_voice_settings("ti")


# --- a generated take's tag (bolt 099) -----------------------------------------------


def test_a_clip_that_was_not_generated_has_no_prefix() -> None:
    assert key_prefix(None) == ""


@pytest.mark.parametrize("source", ["gen-om-obse", "gen-am-yohanes-calm", "gen-am-" + "a" * 40])
def test_a_generated_take_s_tag_goes_before_its_name(source: str) -> None:
    assert key_prefix(source) == f"{source}-"


@pytest.mark.parametrize(
    "source",
    [
        "",
        "om-obse",
        "gen-ti-x",
        "gen-om-",
        "gen-om-Obse",
        "gen-om-ob/se",
        "gen-om-../x",
        "gen-am-" + "a" * 41,
    ],
)
def test_anything_else_is_refused(source: str) -> None:
    with pytest.raises(InvalidContentError) as caught:
        key_prefix(source)

    assert caught.value.field == "source"
