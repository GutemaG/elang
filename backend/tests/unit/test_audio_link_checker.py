"""Unit tests: `AudioLinkChecker` (bolt 036-admin-audio-api). No network: a
mock HTTP transport answers, and a fake resolver decides where hosts point."""

from __future__ import annotations

from collections.abc import Callable

import httpx
import pytest

from app.domain.lesson.exceptions import InvalidAudioLinkError
from app.infrastructure.external.audio_link_checker import AudioLinkChecker

PUBLIC = "93.184.216.34"
HOSTS = {
    "cdn.example": [PUBLIC],
    "inside.example": ["10.0.0.5"],
    "mixed.example": [PUBLIC, "127.0.0.1"],
    "v6local.example": ["::1"],
    "metadata.example": ["169.254.169.254"],
}


async def _resolver(host: str) -> list[str]:
    if host not in HOSTS:
        raise OSError("no such host")
    return HOSTS[host]


def _checker(handler: Callable[[httpx.Request], httpx.Response]) -> AudioLinkChecker:
    return AudioLinkChecker(transport=httpx.MockTransport(handler), resolver=_resolver)


def _audio(request: httpx.Request) -> httpx.Response:
    return httpx.Response(200, headers={"content-type": "audio/mpeg"})


async def _reason(checker: AudioLinkChecker, url: str) -> str:
    with pytest.raises(InvalidAudioLinkError) as caught:
        await checker.check(url)
    return caught.value.details["reason"]


async def test_an_https_audio_link_is_accepted() -> None:
    assert await _checker(_audio).check(" https://cdn.example/a.mp3 ") == "audio/mpeg"


async def test_content_type_parameters_are_ignored() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, headers={"content-type": "Audio/MP4; codecs=mp4a"})

    assert await _checker(handler).check("https://cdn.example/a.m4a") == "Audio/MP4"


@pytest.mark.parametrize("url", ["http://cdn.example/a.mp3", "ftp://cdn.example/a", "https://"])
async def test_not_https(url: str) -> None:
    assert await _reason(_checker(_audio), url) == "not_https"


@pytest.mark.parametrize(
    "host", ["inside.example", "mixed.example", "v6local.example", "metadata.example"]
)
async def test_private_addresses_are_refused_before_any_request(host: str) -> None:
    requests: list[httpx.Request] = []

    def handler(request: httpx.Request) -> httpx.Response:
        requests.append(request)
        return _audio(request)

    assert await _reason(_checker(handler), f"https://{host}/a.mp3") == "private_address"
    assert requests == []


async def test_literal_private_ip() -> None:
    async def resolve_literal(host: str) -> list[str]:
        return [host]

    checker = AudioLinkChecker(transport=httpx.MockTransport(_audio), resolver=resolve_literal)
    assert await _reason(checker, "https://127.0.0.1/a.mp3") == "private_address"


async def test_unknown_host_is_unreachable() -> None:
    assert await _reason(_checker(_audio), "https://nowhere.example/a.mp3") == "unreachable"


async def test_head_refused_falls_back_to_a_one_byte_get() -> None:
    seen: list[tuple[str, str | None]] = []

    def handler(request: httpx.Request) -> httpx.Response:
        seen.append((request.method, request.headers.get("range")))
        if request.method == "HEAD":
            return httpx.Response(405)
        return httpx.Response(206, headers={"content-type": "audio/ogg"})

    assert await _checker(handler).check("https://cdn.example/a.ogg") == "audio/ogg"
    assert seen == [("HEAD", None), ("GET", "bytes=0-0")]


async def test_a_safe_redirect_is_followed() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.path == "/old.mp3":
            return httpx.Response(302, headers={"location": "/new.mp3"})
        return _audio(request)

    assert await _checker(handler).check("https://cdn.example/old.mp3") == "audio/mpeg"


async def test_a_redirect_to_a_private_address_is_refused() -> None:
    requests: list[str] = []

    def handler(request: httpx.Request) -> httpx.Response:
        requests.append(str(request.url))
        return httpx.Response(302, headers={"location": "https://inside.example/secret"})

    assert await _reason(_checker(handler), "https://cdn.example/a.mp3") == "private_address"
    assert requests == ["https://cdn.example/a.mp3"]


async def test_too_many_redirects() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(302, headers={"location": "https://cdn.example/again"})

    assert await _reason(_checker(handler), "https://cdn.example/a.mp3") == "bad_status"


async def test_not_audio() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, headers={"content-type": "text/html"})

    assert await _reason(_checker(handler), "https://cdn.example/page") == "not_audio"


async def test_error_status() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(404, headers={"content-type": "audio/mpeg"})

    assert await _reason(_checker(handler), "https://cdn.example/a.mp3") == "bad_status"


async def test_timeout() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ReadTimeout("slow", request=request)

    assert await _reason(_checker(handler), "https://cdn.example/a.mp3") == "timeout"


async def test_connection_failure() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("refused", request=request)

    assert await _reason(_checker(handler), "https://cdn.example/a.mp3") == "unreachable"
