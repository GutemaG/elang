"""Addis AI text-to-speech (intent 027, bolt 091): the one place the backend
talks to Addis AI.

Shapes are as tested against the live API on 2026-10-12 (see the intent's
requirements, "Findings"). Every request carries the key in `x-api-key`.
A generation needs a `client_request_id`: each call makes a new one and
keeps it across its own retries, so a retry replays the clip instead of
paying for a second one.

The key, the text and Addis's signed audio links are never logged or put
in an error. Failures become the voice errors in
`app/domain/lesson/exceptions.py`, with our own messages.
"""

from __future__ import annotations

import asyncio
import base64
import binascii
import logging
import uuid
from collections.abc import Awaitable, Callable
from dataclasses import dataclass
from typing import Any
from urllib.parse import urlsplit

import httpx

from app.domain.lesson.exceptions import (
    VoiceCreditExhaustedError,
    VoiceLanguageMismatchError,
    VoiceNotConfiguredError,
    VoiceRateLimitedError,
    VoiceServiceFailedError,
    VoiceServiceTimeoutError,
    VoiceTextRejectedError,
)

logger = logging.getLogger("app.voice")


class _HideQueryStrings(logging.Filter):
    """httpx logs every request's full URL at INFO, and a downloaded clip's
    URL carries Addis's signed token. Keep the line, drop the query."""

    def filter(self, record: logging.LogRecord) -> bool:
        if isinstance(record.args, tuple) and len(record.args) > 1:
            url = str(record.args[1])
            if "?" in url:
                record.args = (record.args[0], url.split("?", 1)[0] + "?…", *record.args[2:])
        return True


_HTTPX_FILTER = _HideQueryStrings()
if not any(isinstance(f, _HideQueryStrings) for f in logging.getLogger("httpx").filters):
    logging.getLogger("httpx").addFilter(_HTTPX_FILTER)

Sleep = Callable[[float], Awaitable[None]]

# Waits before each retry of a 429, 5xx, timeout or dropped connection.
RETRY_WAITS = (1.0, 2.0, 4.0)
MAX_RETRY_AFTER = 10.0
OUTPUT_FORMAT = "mp3_44100"
_ADDIS_HOST = "addisassistant.com"


@dataclass(frozen=True)
class AddisVoice:
    id: str
    name: str
    descriptor: str
    gender: str
    style: str
    preview_audio_url: str | None
    is_available: bool
    sort_order: int


@dataclass(frozen=True)
class AddisUsage:
    balance: float
    currency: str
    formatted_balance: str
    price_per_minute: float | None
    max_characters: int | None


@dataclass(frozen=True)
class AddisClip:
    audio: bytes
    duration_seconds: float
    voice_id: str
    voice_name: str
    character_count: int
    credits_remaining: float | None


def _failed(addis_code: str | None = None) -> VoiceServiceFailedError:
    return VoiceServiceFailedError("The voice service failed. Try again.", addis_code=addis_code)


def _error_code(response: httpx.Response) -> str | None:
    try:
        error = response.json().get("error")
    except ValueError:
        return None
    code = error.get("code") if isinstance(error, dict) else None
    return code if isinstance(code, str) else None


def _refusal(response: httpx.Response) -> Exception:
    """The voice error for an answer that is not a success."""
    status = response.status_code
    code = _error_code(response)
    upper = (code or "").upper()
    if status in (401, 403):
        return VoiceNotConfiguredError(
            "The voice service refused this server's key", addis_code=code
        )
    if status == 402 or any(w in upper for w in ("CREDIT", "BALANCE", "INSUFFICIENT")):
        return VoiceCreditExhaustedError("The Addis AI credit has run out.", addis_code=code)
    if upper == "VOICE_LANGUAGE_MISMATCH":
        return VoiceLanguageMismatchError("That voice doesn't speak this language", addis_code=code)
    if upper.startswith("TEXT_"):
        return VoiceTextRejectedError("The voice service couldn't read this text", addis_code=code)
    if status == 429:
        return VoiceRateLimitedError("Too many requests. Try again in a minute.", addis_code=code)
    return _failed(code)


def _data(response: httpx.Response) -> Any:
    try:
        return response.json()["data"]
    except (ValueError, KeyError, TypeError):
        raise _failed() from None


def _decode_data_url(value: str) -> bytes:
    header, _, payload = value.partition(",")
    if not header.startswith("data:") or ";base64" not in header or not payload:
        raise _failed()
    try:
        return base64.b64decode(payload, validate=True)
    except (binascii.Error, ValueError):
        raise _failed() from None


def _is_addis(url: str) -> bool:
    host = (urlsplit(url).hostname or "").lower()
    return host == _ADDIS_HOST or host.endswith("." + _ADDIS_HOST)


class AddisVoiceClient:
    def __init__(
        self,
        api_key: str,
        *,
        base_url: str = "https://api.addisassistant.com",
        timeout: float = 30.0,
        transport: httpx.AsyncBaseTransport | None = None,
        sleep: Sleep = asyncio.sleep,
    ) -> None:
        self._key = api_key
        self._base_url = base_url.rstrip("/")
        self._timeout = timeout
        self._transport = transport
        self._sleep = sleep

    def _client(self) -> httpx.AsyncClient:
        return httpx.AsyncClient(
            base_url=self._base_url, timeout=self._timeout, transport=self._transport
        )

    async def _send(self, method: str, url: str, **kwargs: Any) -> httpx.Response:
        """One request with retries. Returns a 2xx answer or raises a voice
        error."""
        headers = {"x-api-key": self._key, **kwargs.pop("headers", {})}
        async with self._client() as client:
            for attempt in range(len(RETRY_WAITS) + 1):
                last = attempt == len(RETRY_WAITS)
                try:
                    response = await client.request(method, url, headers=headers, **kwargs)
                except httpx.TimeoutException:
                    if last:
                        raise VoiceServiceTimeoutError(
                            "The voice service didn't answer. Try again."
                        ) from None
                    await self._wait(attempt, None, "timeout")
                    continue
                except httpx.TransportError:
                    if last:
                        raise _failed() from None
                    await self._wait(attempt, None, "connection")
                    continue
                if response.is_success:
                    return response
                if response.status_code == 429 or response.status_code >= 500:
                    if not last:
                        await self._wait(attempt, response, str(response.status_code))
                        continue
                raise _refusal(response)
        raise _failed()  # pragma: no cover - the loop always returns or raises

    async def _wait(self, attempt: int, response: httpx.Response | None, why: str) -> None:
        delay = RETRY_WAITS[attempt]
        after = response.headers.get("retry-after") if response is not None else None
        if after is not None:
            try:
                delay = min(max(float(after), 0.0), MAX_RETRY_AFTER)
            except ValueError:
                pass
        logger.info("addis_voice_retry status=%s attempt=%d", why, attempt + 1)
        await self._sleep(delay)

    async def list_voices(self, language: str) -> list[AddisVoice]:
        response = await self._send("GET", "/api/v1/voice/voices", params={"language": language})
        rows = _data(response)
        try:
            return [
                AddisVoice(
                    id=str(v["id"]),
                    name=str(v.get("name") or v["id"]),
                    descriptor=str(v.get("descriptor") or ""),
                    gender=str(v.get("gender") or ""),
                    style=str(v.get("style") or ""),
                    preview_audio_url=v.get("preview_audio_url") or None,
                    is_available=bool(v.get("is_available", False)),
                    sort_order=int(v.get("sort_order") or 0),
                )
                for v in rows
            ]
        except (KeyError, TypeError, ValueError):
            raise _failed() from None

    async def usage(self) -> AddisUsage:
        data = _data(await self._send("GET", "/api/v1/voice/usage"))
        try:
            pricing = data.get("pricing") or {}
            price = pricing.get("price_per_minute")
            max_chars = data.get("max_tts_characters")
            return AddisUsage(
                balance=float(data["balance"]),
                currency=str(data.get("currency") or pricing.get("currency") or ""),
                formatted_balance=str(data.get("formatted_balance") or data["balance"]),
                price_per_minute=None if price is None else float(price),
                max_characters=None if max_chars is None else int(max_chars),
            )
        except (KeyError, TypeError, ValueError, AttributeError):
            raise _failed() from None

    async def generate(self, text: str, *, voice_id: str, language: str, speed: int) -> AddisClip:
        body = {
            "text": text,
            "voice_id": voice_id,
            "language": language,
            "output_format": OUTPUT_FORMAT,
            "voice_settings": {"speed": speed},
            "client_request_id": f"buna-{uuid.uuid4().hex}",
        }
        data = _data(await self._send("POST", "/api/v1/voice/generations", json=body))
        try:
            inline = data.get("audio")
            if isinstance(inline, str) and inline:
                audio = _decode_data_url(inline)
            else:
                audio = await self._download(str(data["audio_url"]))
            usage = data.get("usage") or {}
            remaining = usage.get("credits_remaining")
            return AddisClip(
                audio=audio,
                duration_seconds=float(data.get("duration_seconds") or 0.0),
                voice_id=str(data.get("voice_id") or voice_id),
                voice_name=str(data.get("voice_name") or voice_id),
                character_count=int(data.get("character_count") or len(text)),
                credits_remaining=None if remaining is None else float(remaining),
            )
        except (KeyError, TypeError, ValueError, AttributeError):
            raise _failed() from None

    async def _download(self, url: str) -> bytes:
        """The signed clip, for a replayed generation that sent no audio.
        The key goes only to Addis's own hosts."""
        if not url.startswith("https://"):
            raise _failed()
        headers = {"x-api-key": self._key} if _is_addis(url) else {}
        async with httpx.AsyncClient(timeout=self._timeout, transport=self._transport) as client:
            try:
                response = await client.get(url, headers=headers)
            except httpx.TimeoutException:
                raise VoiceServiceTimeoutError(
                    "The voice service didn't answer. Try again."
                ) from None
            except httpx.TransportError:
                raise _failed() from None
        if not response.is_success or not response.content:
            raise _failed()
        return response.content
