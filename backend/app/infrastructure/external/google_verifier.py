"""Google ID token verification (story 002), per ADR/Technical Design's
Security Design: the official `google-auth` package's
`google.oauth2.id_token.verify_oauth2_token`, checking signature, issuer,
audience (our OAuth client ID), and expiry. The verified `sub` claim becomes
`provider_user_id`. Never trusts a client-asserted user ID.
"""

from __future__ import annotations

import asyncio

from google.auth.exceptions import GoogleAuthError, TransportError
from google.auth.transport import requests as google_auth_requests
from google.oauth2 import id_token as google_id_token

from app.domain.exceptions import (
    ExpiredTokenError,
    InvalidTokenError,
    ProviderUnreachableError,
)

_VALID_ISSUERS = ("accounts.google.com", "https://accounts.google.com")


class GoogleTokenVerifier:
    """Implements the `app.domain.services.TokenVerifier` protocol."""

    def __init__(self, client_id: str) -> None:
        self._client_id = client_id
        # google-auth's Request wraps its own HTTP session; reused across
        # calls so certificate fetches can be cached by the library itself.
        self._transport_request = google_auth_requests.Request()

    async def verify(self, token: str) -> str:
        # verify_oauth2_token is a synchronous, blocking call (it may fetch
        # Google's public certs over HTTP) -- run it off the event loop.
        try:
            claims = await asyncio.to_thread(
                google_id_token.verify_oauth2_token,
                token,
                self._transport_request,
                self._client_id or None,
            )
        except TransportError as exc:
            raise ProviderUnreachableError(
                "Could not reach Google's token verification endpoint"
            ) from exc
        except ValueError as exc:
            # google-auth raises plain ValueError for essentially all
            # verification failures (bad signature, wrong audience, expired
            # token, malformed token) -- there is no distinct exception type
            # per failure mode, so we inspect the message to separate an
            # expired token from every other invalid-token case. This is a
            # pragmatic judgment call: it's the only signal google-auth gives.
            if "expired" in str(exc).lower():
                raise ExpiredTokenError("Google ID token has expired") from exc
            raise InvalidTokenError("Google ID token failed verification") from exc
        except GoogleAuthError as exc:
            raise InvalidTokenError("Google ID token failed verification") from exc

        issuer = claims.get("iss")
        if issuer not in _VALID_ISSUERS:
            raise InvalidTokenError("Unexpected issuer in Google ID token")

        subject = claims.get("sub")
        if not subject:
            raise InvalidTokenError("Google ID token missing 'sub' claim")
        return subject
