"""Unit tests: `GoogleTokenVerifier` passes the email on only when Google
verified it (ADR-16). `verify_oauth2_token` is replaced, so no network."""

from __future__ import annotations

from typing import Any

import pytest

from app.domain.value_objects import VerifiedIdentity
from app.infrastructure.external import google_verifier as module
from app.infrastructure.external.google_verifier import GoogleTokenVerifier


def _verifier_with_claims(
    monkeypatch: pytest.MonkeyPatch, claims: dict[str, Any]
) -> GoogleTokenVerifier:
    base = {"iss": "https://accounts.google.com", "sub": "google-sub-1"}
    monkeypatch.setattr(
        module.google_id_token, "verify_oauth2_token", lambda *_a, **_k: {**base, **claims}
    )
    return GoogleTokenVerifier(client_id="client-id")


async def test_verified_email_is_passed_on(monkeypatch: pytest.MonkeyPatch) -> None:
    verifier = _verifier_with_claims(
        monkeypatch, {"email": "admin@example.com", "email_verified": True}
    )
    assert await verifier.verify("t") == VerifiedIdentity("google-sub-1", "admin@example.com")


@pytest.mark.parametrize(
    "claims",
    [
        {"email": "admin@example.com", "email_verified": False},
        {"email": "admin@example.com"},  # no verification claim at all
        {"email": "admin@example.com", "email_verified": "true"},  # only a real True counts
        {"email_verified": True},  # verified, but no email
        {},
    ],
)
async def test_unverified_or_missing_email_is_dropped(
    monkeypatch: pytest.MonkeyPatch, claims: dict[str, Any]
) -> None:
    verifier = _verifier_with_claims(monkeypatch, claims)
    assert await verifier.verify("t") == VerifiedIdentity("google-sub-1", None)
