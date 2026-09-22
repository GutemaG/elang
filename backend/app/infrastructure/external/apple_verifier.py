"""Sign in with Apple identity token verification (story 003), per ADR-2:
raw JWT-over-JWKS -- no Apple-specific SDK. Fetches and caches Apple's
published JWKS, verifies the RS256 signature via `PyJWT` + `cryptography`,
and checks issuer/audience/expiry manually.
"""

from __future__ import annotations

import asyncio
import time
from typing import Any

import httpx
import jwt
from jwt import PyJWTError
from jwt.algorithms import RSAAlgorithm

from app.domain.exceptions import (
    ExpiredTokenError,
    InvalidTokenError,
    ProviderUnreachableError,
)
from app.domain.value_objects import VerifiedIdentity


class AppleTokenVerifier:
    """Implements the `app.domain.services.TokenVerifier` protocol.

    JWKS cache is process-local, in-memory, with a TTL (per
    `ddd-02-technical-design.md`'s Scalability NFR) plus a refetch-once
    fallback when a token's `kid` isn't found in the cached set -- this
    covers Apple's key-rotation window without hard-failing a legitimately
    signed token (ADR-2's flagged risk).
    """

    def __init__(
        self,
        jwks_url: str,
        issuer: str,
        audiences: list[str],
        cache_ttl_seconds: int = 3600,
        http_client: httpx.AsyncClient | None = None,
    ) -> None:
        self._jwks_url = jwks_url
        self._issuer = issuer
        self._audiences = [aud for aud in audiences if aud]
        self._cache_ttl_seconds = cache_ttl_seconds
        self._http_client = http_client
        self._owns_http_client = http_client is None

        self._jwks_cache: dict[str, Any] = {}
        self._jwks_cached_at: float = 0.0
        self._lock = asyncio.Lock()

    async def _get_http_client(self) -> httpx.AsyncClient:
        if self._http_client is None:
            self._http_client = httpx.AsyncClient(timeout=10.0)
        return self._http_client

    async def _fetch_jwks(self) -> dict[str, Any]:
        client = await self._get_http_client()
        try:
            response = await client.get(self._jwks_url)
            response.raise_for_status()
        except httpx.HTTPError as exc:
            raise ProviderUnreachableError("Could not reach Apple's JWKS endpoint") from exc
        return response.json()

    async def _get_jwks(self, force_refresh: bool = False) -> dict[str, Any]:
        now = time.monotonic()
        is_stale = (now - self._jwks_cached_at) > self._cache_ttl_seconds
        if force_refresh or is_stale or not self._jwks_cache:
            async with self._lock:
                # Re-check inside the lock: a concurrent request may have
                # already refreshed the cache while we were waiting.
                now = time.monotonic()
                is_stale = (now - self._jwks_cached_at) > self._cache_ttl_seconds
                if force_refresh or is_stale or not self._jwks_cache:
                    self._jwks_cache = await self._fetch_jwks()
                    self._jwks_cached_at = now
        return self._jwks_cache

    async def _find_key(self, kid: str) -> dict[str, Any] | None:
        jwks = await self._get_jwks()
        for key in jwks.get("keys", []):
            if key.get("kid") == kid:
                return key
        # Unknown kid: refetch once before giving up, in case Apple rotated
        # keys since our cache was last filled.
        jwks = await self._get_jwks(force_refresh=True)
        for key in jwks.get("keys", []):
            if key.get("kid") == kid:
                return key
        return None

    async def verify(self, token: str) -> VerifiedIdentity:
        try:
            header = jwt.get_unverified_header(token)
        except PyJWTError as exc:
            raise InvalidTokenError("Malformed Apple identity token") from exc

        kid = header.get("kid")
        if not kid:
            raise InvalidTokenError("Apple identity token missing 'kid' header")

        jwk = await self._find_key(kid)
        if jwk is None:
            raise InvalidTokenError("No matching Apple signing key found for token 'kid'")

        public_key = RSAAlgorithm.from_jwk(jwk)

        decode_options: dict[str, Any] = {"require": ["exp", "iat", "sub"]}
        decode_kwargs: dict[str, Any] = {
            "key": public_key,
            "algorithms": ["RS256"],
            "issuer": self._issuer,
        }
        if self._audiences:
            decode_kwargs["audience"] = self._audiences
        else:
            # No configured audience (e.g. local dev without real Apple
            # secrets, per .env.example) -- skip aud verification rather
            # than reject every token outright.
            decode_options["verify_aud"] = False
        decode_kwargs["options"] = decode_options

        try:
            claims = jwt.decode(token, **decode_kwargs)
        except jwt.ExpiredSignatureError as exc:
            raise ExpiredTokenError("Apple identity token has expired") from exc
        except PyJWTError as exc:
            raise InvalidTokenError("Apple identity token failed verification") from exc

        subject = claims.get("sub")
        if not subject:
            raise InvalidTokenError("Apple identity token missing 'sub' claim")
        # No email (ADR-16): Apple may hand out a private relay address, so
        # Apple accounts are never admins in v1.
        return VerifiedIdentity(subject=subject)

    async def aclose(self) -> None:
        if self._owns_http_client and self._http_client is not None:
            await self._http_client.aclose()
