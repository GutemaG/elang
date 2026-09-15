"""Lightweight performance smoke tests.

No dedicated numeric NFR targets exist for this bolt beyond
`ddd-02-technical-design.md`'s qualitative NFR Implementation notes (one
outbound verification call + one DB round trip per auth; a single indexed
lookup for session validation). These tests make a real, measured
assertion that repeated authentication and session-validation calls
complete in bounded time against the temp-file SQLite DB used in
local/test -- catching an accidental O(n^2) regression -- rather than
fabricating a load test against infrastructure this bolt doesn't
provision (no separate perf environment exists yet for this service).
"""

from __future__ import annotations

import time
from collections.abc import Callable

from fastapi.testclient import TestClient

from tests.fakes import FakeTokenVerifier

ClientFactory = Callable[[object, object], TestClient]

_REQUEST_COUNT = 50
_MAX_TOTAL_SECONDS = 5.0  # generous local-SQLite bound, not a production SLA


def test_repeated_google_auth_requests_complete_within_bound(make_client: ClientFactory) -> None:
    google_verifier = FakeTokenVerifier(subject="perf-user")
    client = make_client(google_verifier, FakeTokenVerifier())

    start = time.perf_counter()
    for _ in range(_REQUEST_COUNT):
        response = client.post("/api/v1/auth/google", json={"id_token": "perf-token"})
        assert response.status_code == 200
    elapsed = time.perf_counter() - start

    assert elapsed < _MAX_TOTAL_SECONDS, (
        f"{_REQUEST_COUNT} sequential auth requests took {elapsed:.2f}s, "
        f"expected under {_MAX_TOTAL_SECONDS}s"
    )


def test_session_validation_stays_fast_as_sessions_accumulate(make_client: ClientFactory) -> None:
    google_verifier = FakeTokenVerifier(subject="perf-user-2")
    client = make_client(google_verifier, FakeTokenVerifier())

    tokens = []
    for _ in range(_REQUEST_COUNT):
        response = client.post("/api/v1/auth/google", json={"id_token": "perf-token-2"})
        tokens.append(response.json()["session_token"])

    # Validate the FIRST-ever issued token last -- if the lookup degraded
    # to a linear scan that slowed down as more rows were added, this call
    # is the one that would show it.
    start = time.perf_counter()
    response = client.get("/api/v1/auth/session", headers={"Authorization": f"Bearer {tokens[0]}"})
    elapsed = time.perf_counter() - start

    assert response.status_code == 200
    assert response.json()["valid"] is True
    assert elapsed < 1.0
