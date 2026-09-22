"""Checks an audio link an admin pasted before it is saved (bolt
`036-admin-audio-api`).

The backend fetches a URL someone typed, so this is guarded against being
pointed at the server's own network (SSRF): https only, every address the
host resolves to must be public, and each redirect is checked again rather
than followed blindly. Residual risk: the host is resolved once here and
again by the HTTP client, so a host that changes its answer in between
(DNS rebinding) is not caught -- accepted for an admin-only endpoint.
"""

from __future__ import annotations

import asyncio
import ipaddress
import socket
from collections.abc import Awaitable, Callable
from urllib.parse import urljoin, urlsplit

import httpx

from app.domain.lesson.exceptions import InvalidAudioLinkError

Resolver = Callable[[str], Awaitable[list[str]]]

_TIMEOUT_SECONDS = 5.0
_MAX_REDIRECTS = 3


async def resolve_host(host: str) -> list[str]:
    infos = await asyncio.get_running_loop().getaddrinfo(host, 443, type=socket.SOCK_STREAM)
    return [info[4][0] for info in infos]


def _refuse(reason: str, message: str) -> InvalidAudioLinkError:
    return InvalidAudioLinkError(message, reason=reason)


class AudioLinkChecker:
    def __init__(
        self,
        *,
        transport: httpx.AsyncBaseTransport | None = None,
        resolver: Resolver = resolve_host,
    ) -> None:
        self._transport = transport
        self._resolver = resolver

    async def _check_address(self, url: str) -> None:
        parts = urlsplit(url)
        if parts.scheme != "https" or not parts.hostname:
            raise _refuse("not_https", "The link must be a full https:// address")
        try:
            addresses = await self._resolver(parts.hostname)
        except OSError:
            raise _refuse("unreachable", "That address could not be found") from None
        if not addresses or not all(ipaddress.ip_address(a).is_global for a in addresses):
            raise _refuse("private_address", "That address is not on the public internet")

    async def check(self, url: str) -> str:
        """Returns the link's audio content type, or raises
        `InvalidAudioLinkError` with `details.reason`."""
        current = url.strip()
        async with httpx.AsyncClient(
            transport=self._transport, timeout=_TIMEOUT_SECONDS, follow_redirects=False
        ) as client:
            for _ in range(_MAX_REDIRECTS + 1):
                await self._check_address(current)
                try:
                    response = await client.head(current)
                    if response.status_code in (403, 405, 501):
                        # Some hosts refuse HEAD; ask for the first byte instead.
                        response = await client.get(current, headers={"Range": "bytes=0-0"})
                except httpx.TimeoutException:
                    raise _refuse("timeout", "The link took too long to answer") from None
                except httpx.HTTPError:
                    raise _refuse("unreachable", "The link could not be reached") from None

                if response.is_redirect and "location" in response.headers:
                    current = urljoin(current, response.headers["location"])
                    continue
                if not response.is_success:
                    raise _refuse(
                        "bad_status", f"The link answered with status {response.status_code}"
                    )
                content_type = response.headers.get("content-type", "").split(";")[0].strip()
                if not content_type.lower().startswith("audio/"):
                    raise _refuse("not_audio", "The link does not point at an audio file")
                return content_type
        raise _refuse("bad_status", "The link redirects too many times")
