"""Unit tests: the voice catalog cache and reads (intent 027, stories 006
and 007)."""

from __future__ import annotations

import pytest

from app.application.voice_use_cases import (
    VoiceCatalog,
    get_voice_usage,
    list_voice_options,
)
from app.domain.lesson.exceptions import InvalidContentError, VoiceServiceFailedError
from app.infrastructure.external.addis_voice_client import AddisUsage, AddisVoice


def voice(
    vid: str, gender: str = "female", *, available: bool = True, order: int = 0
) -> AddisVoice:
    return AddisVoice(
        id=vid,
        name=vid.split("-")[1].title(),
        descriptor="",
        gender=gender,
        style="Narration",
        preview_audio_url=None,
        is_available=available,
        sort_order=order,
    )


class FakeSource:
    def __init__(self, voices: dict[str, list[AddisVoice]] | None = None) -> None:
        self.voices = voices or {}
        self.calls: list[str] = []
        self.fail = False

    async def list_voices(self, language: str) -> list[AddisVoice]:
        self.calls.append(language)
        if self.fail:
            raise VoiceServiceFailedError("down")
        return self.voices.get(language, [])

    async def usage(self) -> AddisUsage:
        return AddisUsage(997.53, "ETB", "Br 997.53", 2.5, 5000)


class Clock:
    def __init__(self) -> None:
        self.now = 0.0

    def __call__(self) -> float:
        return self.now


async def test_only_available_voices_in_addis_order() -> None:
    source = FakeSource(
        {
            "om": [
                voice("om-obse", order=80),
                voice("om-old", available=False, order=1),
                voice("om-hawi", order=30),
                voice("om-bikila", "male", order=30),
            ]
        }
    )

    voices = await VoiceCatalog().available(source, "om")

    assert [v.id for v in voices] == ["om-bikila", "om-hawi", "om-obse"]


async def test_a_language_is_fetched_once_within_ten_minutes() -> None:
    source, clock = FakeSource({"om": [voice("om-obse")]}), Clock()
    catalog = VoiceCatalog(clock=clock)

    await catalog.available(source, "om")
    clock.now = 599.0
    await catalog.available(source, "om")

    assert source.calls == ["om"]


async def test_after_ten_minutes_it_is_fetched_again() -> None:
    source, clock = FakeSource({"om": [voice("om-obse")]}), Clock()
    catalog = VoiceCatalog(clock=clock)

    await catalog.available(source, "om")
    clock.now = 600.0
    await catalog.available(source, "om")

    assert source.calls == ["om", "om"]


async def test_each_language_is_cached_on_its_own() -> None:
    source = FakeSource({"am": [voice("am-loza")], "om": [voice("om-obse")]})
    catalog = VoiceCatalog()

    am = await catalog.available(source, "am")
    om = await catalog.available(source, "om")
    await catalog.available(source, "am")

    assert ([v.id for v in am], [v.id for v in om]) == (["am-loza"], ["om-obse"])
    assert source.calls == ["am", "om"]


async def test_a_failed_fetch_is_not_kept() -> None:
    source = FakeSource({"om": [voice("om-obse")]})
    catalog = VoiceCatalog()
    source.fail = True

    with pytest.raises(VoiceServiceFailedError):
        await catalog.available(source, "om")
    source.fail = False

    assert [v.id for v in await catalog.available(source, "om")] == ["om-obse"]
    assert source.calls == ["om", "om"]


async def test_options_refuse_a_language_without_voices() -> None:
    source = FakeSource()

    with pytest.raises(InvalidContentError) as caught:
        await list_voice_options(source, VoiceCatalog(), "ti")

    assert caught.value.field == "language"
    assert source.calls == []


async def test_usage_is_passed_through() -> None:
    usage = await get_voice_usage(FakeSource())

    assert (usage.formatted_balance, usage.price_per_minute) == ("Br 997.53", 2.5)
