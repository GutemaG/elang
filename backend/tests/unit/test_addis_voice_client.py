"""Unit tests: the Addis AI client (intent 027, story 005). Every answer
comes from `httpx.MockTransport`, so nothing reaches the network; the
shapes are the ones the live API gave on 2026-10-12."""

from __future__ import annotations

import base64
import json
import logging
from collections.abc import Callable
from typing import Any

import httpx
import pytest

from app.domain.lesson.exceptions import (
    VoiceCreditExhaustedError,
    VoiceLanguageMismatchError,
    VoiceNotConfiguredError,
    VoiceRateLimitedError,
    VoiceServiceFailedError,
    VoiceServiceTimeoutError,
    VoiceTextRejectedError,
)
from app.infrastructure.external.addis_voice_client import AddisVoiceClient

KEY = "sk_test-secret-key-never-shown"
MP3 = b"ID3\x04fake-mp3-bytes"
Handler = Callable[[httpx.Request], httpx.Response]


class Recorder:
    """A transport that answers from a list, one answer per request, and
    keeps every request it saw."""

    def __init__(self, *answers: httpx.Response | Exception | Handler) -> None:
        self.answers = list(answers)
        self.requests: list[httpx.Request] = []

    def __call__(self, request: httpx.Request) -> httpx.Response:
        self.requests.append(request)
        answer = self.answers.pop(0) if len(self.answers) > 1 else self.answers[0]
        if isinstance(answer, Exception):
            raise answer
        if callable(answer) and not isinstance(answer, httpx.Response):
            return answer(request)
        return answer


def _client(recorder: Recorder, waits: list[float] | None = None) -> AddisVoiceClient:
    async def sleep(seconds: float) -> None:
        if waits is not None:
            waits.append(seconds)

    return AddisVoiceClient(
        KEY,
        base_url="https://api.addisassistant.com",
        transport=httpx.MockTransport(recorder),
        sleep=sleep,
    )


def _error(status: int, code: str, headers: dict[str, str] | None = None) -> httpx.Response:
    body = {"error": {"code": code, "message": f"Addis says {code}", "details": []}}
    return httpx.Response(status, json=body, headers=headers)


def _clip(**overrides: Any) -> dict[str, Any]:
    data: dict[str, Any] = {
        "id": "d341fdf8",
        "voice_id": "om-obse",
        "voice_name": "Obse",
        "language": "om",
        "audio": "data:audio/mpeg;base64," + base64.b64encode(MP3).decode(),
        "audio_url": "https://cdn.addisassistant.com/audio/clips/d341fdf8.mp3?token=signed",
        "duration_seconds": 1.83,
        "character_count": 22,
        "usage": {"credits_used": 0.08, "credits_remaining": 497.5, "currency": "ETB"},
    }
    data.update(overrides)
    return {"data": data}


async def _generate(client: AddisVoiceClient) -> Any:
    return await client.generate(
        "Maqaan koo Saaraa dha.", voice_id="om-obse", language="om", speed=40
    )


# --- reading -------------------------------------------------------------------------


async def test_voices_are_read_with_the_key() -> None:
    recorder = Recorder(
        httpx.Response(
            200,
            json={
                "data": [
                    {
                        "id": "om-obse",
                        "name": "Obse",
                        "descriptor": "Clear narration",
                        "language": "om",
                        "gender": "female",
                        "style": "Narration",
                        "preview_audio_url": "https://cdn.addisassistant.com/p/om-obse.mp3",
                        "is_available": True,
                        "sort_order": 80,
                    },
                    {"id": "om-old", "gender": "male", "is_available": False},
                ]
            },
        )
    )

    voices = await _client(recorder).list_voices("om")

    request = recorder.requests[0]
    assert request.url.path == "/api/v1/voice/voices"
    assert request.url.params["language"] == "om"
    assert request.headers["x-api-key"] == KEY
    assert [(v.id, v.name, v.gender, v.is_available) for v in voices] == [
        ("om-obse", "Obse", "female", True),
        ("om-old", "om-old", "male", False),
    ]
    assert voices[0].style == "Narration"
    assert voices[0].sort_order == 80


async def test_usage_is_read() -> None:
    recorder = Recorder(
        httpx.Response(
            200,
            json={
                "data": {
                    "balance": 997.5277,
                    "currency": "ETB",
                    "formatted_balance": "Br 997.53",
                    "pricing": {"unit": "minute", "currency": "ETB", "price_per_minute": 2.5},
                    "max_tts_characters": 5000,
                }
            },
        )
    )

    usage = await _client(recorder).usage()

    assert recorder.requests[0].url.path == "/api/v1/voice/usage"
    assert (usage.balance, usage.currency, usage.formatted_balance) == (
        997.5277,
        "ETB",
        "Br 997.53",
    )
    assert (usage.price_per_minute, usage.max_characters) == (2.5, 5000)


# --- generating ----------------------------------------------------------------------


async def test_a_generation_posts_the_voice_speed_and_a_request_id() -> None:
    recorder = Recorder(httpx.Response(201, json=_clip()))

    clip = await _generate(_client(recorder))

    body = json.loads(recorder.requests[0].content)
    assert recorder.requests[0].method == "POST"
    assert recorder.requests[0].url.path == "/api/v1/voice/generations"
    assert body["text"] == "Maqaan koo Saaraa dha."
    assert (body["voice_id"], body["language"]) == ("om-obse", "om")
    assert body["output_format"] == "mp3_44100"
    assert body["voice_settings"] == {"speed": 40}
    assert body["client_request_id"].startswith("buna-")
    assert clip.audio == MP3
    assert (clip.voice_id, clip.voice_name, clip.duration_seconds) == ("om-obse", "Obse", 1.83)
    assert (clip.character_count, clip.credits_remaining) == (22, 497.5)


async def test_each_generation_has_its_own_request_id() -> None:
    recorder = Recorder(httpx.Response(201, json=_clip()))
    client = _client(recorder)

    await _generate(client)
    await _generate(client)

    ids = [json.loads(r.content)["client_request_id"] for r in recorder.requests]
    assert len(set(ids)) == 2


async def test_a_retry_keeps_the_request_id_so_it_never_pays_twice() -> None:
    recorder = Recorder(_error(503, "UNAVAILABLE"), httpx.Response(201, json=_clip()))

    await _generate(_client(recorder))

    ids = [json.loads(r.content)["client_request_id"] for r in recorder.requests]
    assert len(ids) == 2
    assert ids[0] == ids[1]


async def test_without_inline_audio_the_clip_is_downloaded_once_with_the_key() -> None:
    def answer(request: httpx.Request) -> httpx.Response:
        if request.url.host == "cdn.addisassistant.com":
            return httpx.Response(200, content=MP3, headers={"content-type": "audio/mpeg"})
        return httpx.Response(200, json=_clip(audio=None))

    recorder = Recorder(answer)

    clip = await _generate(_client(recorder))

    assert clip.audio == MP3
    download = recorder.requests[1]
    assert download.url.host == "cdn.addisassistant.com"
    assert download.headers["x-api-key"] == KEY


async def test_the_key_is_never_sent_to_another_host() -> None:
    def answer(request: httpx.Request) -> httpx.Response:
        if request.url.host == "files.example.com":
            return httpx.Response(200, content=MP3)
        return httpx.Response(
            200, json=_clip(audio=None, audio_url="https://files.example.com/clip.mp3")
        )

    recorder = Recorder(answer)

    await _generate(_client(recorder))

    assert "x-api-key" not in recorder.requests[1].headers


@pytest.mark.parametrize(
    "clip",
    [
        _clip(audio="not-a-data-url"),
        _clip(audio="data:audio/mpeg;base64,***"),
        _clip(audio=None, audio_url="http://cdn.addisassistant.com/clip.mp3"),
        {"data": "nothing useful"},
        {"no": "data"},
    ],
)
async def test_an_unreadable_generation_is_a_failure(clip: dict[str, Any]) -> None:
    with pytest.raises(VoiceServiceFailedError):
        await _generate(_client(Recorder(httpx.Response(201, json=clip))))


async def test_a_body_that_is_not_json_is_a_failure() -> None:
    with pytest.raises(VoiceServiceFailedError):
        await _client(Recorder(httpx.Response(200, text="<html>"))).usage()


# --- retries -------------------------------------------------------------------------


async def test_a_429_is_retried_after_a_second() -> None:
    waits: list[float] = []
    recorder = Recorder(_error(429, "RATE_LIMITED"), httpx.Response(201, json=_clip()))

    await _generate(_client(recorder, waits))

    assert waits == [1.0]


async def test_retry_after_is_honoured_and_capped() -> None:
    waits: list[float] = []
    recorder = Recorder(
        _error(429, "RATE_LIMITED", {"retry-after": "3"}),
        _error(429, "RATE_LIMITED", {"retry-after": "120"}),
        httpx.Response(201, json=_clip()),
    )

    await _generate(_client(recorder, waits))

    assert waits == [3.0, 10.0]


async def test_still_rate_limited_after_three_retries() -> None:
    waits: list[float] = []
    recorder = Recorder(_error(429, "RATE_LIMITED"))

    with pytest.raises(VoiceRateLimitedError):
        await _generate(_client(recorder, waits))

    assert len(recorder.requests) == 4
    assert waits == [1.0, 2.0, 4.0]


async def test_a_server_error_four_times_is_a_failure() -> None:
    recorder = Recorder(httpx.Response(500, text="oops"))

    with pytest.raises(VoiceServiceFailedError):
        await _generate(_client(recorder))

    assert len(recorder.requests) == 4


async def test_a_client_error_is_not_retried() -> None:
    recorder = Recorder(_error(400, "BAD_REQUEST"))

    with pytest.raises(VoiceServiceFailedError):
        await _generate(_client(recorder))

    assert len(recorder.requests) == 1


async def test_a_timeout_is_retried_then_reported() -> None:
    recorder = Recorder(httpx.ReadTimeout("slow"))

    with pytest.raises(VoiceServiceTimeoutError):
        await _generate(_client(recorder))

    assert len(recorder.requests) == 4


async def test_a_timeout_then_success_works() -> None:
    recorder = Recorder(httpx.ConnectTimeout("slow"), httpx.Response(201, json=_clip()))

    clip = await _generate(_client(recorder))

    assert clip.audio == MP3


async def test_a_dropped_connection_is_retried_then_a_failure() -> None:
    recorder = Recorder(httpx.ConnectError("refused"))

    with pytest.raises(VoiceServiceFailedError):
        await _client(recorder).usage()

    assert len(recorder.requests) == 4


# --- refusals ------------------------------------------------------------------------


@pytest.mark.parametrize(
    ("answer", "error"),
    [
        (_error(401, "UNAUTHORIZED"), VoiceNotConfiguredError),
        (_error(403, "FORBIDDEN"), VoiceNotConfiguredError),
        (_error(402, "PAYMENT_REQUIRED"), VoiceCreditExhaustedError),
        (_error(422, "INSUFFICIENT_CREDITS"), VoiceCreditExhaustedError),
        (_error(409, "WALLET_BALANCE_TOO_LOW"), VoiceCreditExhaustedError),
        (_error(422, "VOICE_LANGUAGE_MISMATCH"), VoiceLanguageMismatchError),
        (_error(422, "TEXT_REQUIRED"), VoiceTextRejectedError),
        (_error(422, "TEXT_TOO_LONG"), VoiceTextRejectedError),
        (_error(422, "CLIENT_REQUEST_ID_REQUIRED"), VoiceServiceFailedError),
        (httpx.Response(404, text="not json"), VoiceServiceFailedError),
    ],
)
async def test_each_refusal_becomes_its_voice_error(
    answer: httpx.Response, error: type[Exception]
) -> None:
    with pytest.raises(error) as caught:
        await _generate(_client(Recorder(answer)))

    assert "Addis says" not in str(caught.value)


async def test_the_fields_of_input_refusals() -> None:
    with pytest.raises(VoiceTextRejectedError) as text:
        await _generate(_client(Recorder(_error(422, "TEXT_REQUIRED"))))
    with pytest.raises(VoiceLanguageMismatchError) as voice:
        await _generate(_client(Recorder(_error(422, "VOICE_LANGUAGE_MISMATCH"))))

    assert (text.value.field, text.value.addis_code) == ("text", "TEXT_REQUIRED")
    assert voice.value.field == "voice_id"


async def test_addis_s_code_is_kept_for_the_log_but_not_in_details() -> None:
    with pytest.raises(VoiceCreditExhaustedError) as caught:
        await _generate(_client(Recorder(_error(402, "WALLET_EMPTY"))))

    assert caught.value.addis_code == "WALLET_EMPTY"
    assert caught.value.details == {}


# --- the key stays secret ------------------------------------------------------------


async def test_the_key_text_and_signed_link_are_never_logged_or_in_an_error(
    caplog: pytest.LogCaptureFixture,
) -> None:
    raised: list[str] = []
    answers = [
        _error(429, "RATE_LIMITED"),
        _error(401, "UNAUTHORIZED"),
        _error(402, "PAYMENT_REQUIRED"),
        _error(422, "TEXT_REQUIRED"),
        httpx.Response(500, text=KEY),
        httpx.ReadTimeout(KEY),
        httpx.ConnectError(KEY),
    ]
    with caplog.at_level(logging.DEBUG):
        await _generate(_client(Recorder(_error(429, "x"), httpx.Response(201, json=_clip()))))
        for answer in answers:
            try:
                await _generate(_client(Recorder(answer)))
            except Exception as exc:  # noqa: BLE001 - every error is inspected
                raised.append(f"{exc!s} {exc!r}")

    text = caplog.text + " ".join(raised)
    assert raised
    assert KEY not in text
    assert "Maqaan koo" not in text
    assert "token=signed" not in text


async def test_the_signed_link_of_a_downloaded_clip_is_not_logged(
    caplog: pytest.LogCaptureFixture,
) -> None:
    def answer(request: httpx.Request) -> httpx.Response:
        if request.url.host == "cdn.addisassistant.com":
            return httpx.Response(200, content=MP3)
        return httpx.Response(200, json=_clip(audio=None))

    with caplog.at_level(logging.DEBUG):
        await _generate(_client(Recorder(answer)))

    assert "token=signed" not in caplog.text
