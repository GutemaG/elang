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


# 023-weekly-leagues (bolt 073): Google's `given_name` becomes the first
# name other learners see in a league.


async def test_the_given_name_is_passed_on(monkeypatch: pytest.MonkeyPatch) -> None:
    verifier = _verifier_with_claims(monkeypatch, {"given_name": "  Abebe  "})
    assert (await verifier.verify("t")).first_name == "Abebe"


@pytest.mark.parametrize(
    ("claims", "expected"),
    [
        ({}, None),
        ({"given_name": "   "}, None),
        ({"given_name": 42}, None),
        ({"given_name": "A" * 150}, "A" * 100),
        ({"given_name": "Tigist", "name": "Tigist Haile"}, "Tigist"),
    ],
)
async def test_a_missing_blank_or_odd_given_name(
    monkeypatch: pytest.MonkeyPatch, claims: dict[str, Any], expected: str | None
) -> None:
    verifier = _verifier_with_claims(monkeypatch, claims)
    assert (await verifier.verify("t")).first_name == expected


async def test_a_few_seconds_of_clock_difference_is_allowed(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """A machine whose clock is a little slow must still accept a fresh
    token, which google-auth refuses as "used too early" with no skew."""
    seen: dict[str, Any] = {}

    def fake(*_a: Any, **kwargs: Any) -> dict[str, Any]:
        seen.update(kwargs)
        return {"iss": "https://accounts.google.com", "sub": "google-sub-1"}

    monkeypatch.setattr(module.google_id_token, "verify_oauth2_token", fake)
    await GoogleTokenVerifier(client_id="client-id").verify("t")

    assert seen["clock_skew_in_seconds"] == module.CLOCK_SKEW_SECONDS == 10
