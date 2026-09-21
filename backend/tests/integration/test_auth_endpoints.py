"""Integration tests: full endpoint tests for all 3 auth routes via FastAPI
`TestClient`, with `GoogleTokenVerifier`/`AppleTokenVerifier` replaced by
fakes (never a real network call to Google/Apple). Covers the acceptance
criteria from all 3 stories in `memory-bank/intents/001-auth-onboarding/
units/001-auth-service/stories/`.
"""

from __future__ import annotations

from collections.abc import Callable

from fastapi.testclient import TestClient

from app.domain.exceptions import InvalidTokenError, ProviderUnreachableError
from tests.fakes import FakeTokenVerifier

ClientFactory = Callable[[object, object], TestClient]


class TestGoogleAuthEndpoint:
    def test_new_user_via_google_with_pending_selection(self, make_client: ClientFactory) -> None:
        client = make_client(FakeTokenVerifier(subject="google-new-1"), FakeTokenVerifier())

        response = client.post(
            "/api/v1/auth/google",
            json={
                "id_token": "whatever",
                "pending_selection": {"language": "am", "daily_goal_minutes": 15},
            },
        )

        assert response.status_code == 200
        body = response.json()
        assert body["user"]["is_new_user"] is True
        assert body["user"]["selected_language"] == "am"
        assert body["user"]["daily_xp_target"] == 60
        assert body["session_token"]
        assert body["expires_at"]

    def test_new_user_via_google_with_no_pending_selection_uses_defaults(
        self, make_client: ClientFactory
    ) -> None:
        client = make_client(FakeTokenVerifier(subject="google-new-nodefault"), FakeTokenVerifier())

        response = client.post("/api/v1/auth/google", json={"id_token": "whatever"})

        assert response.status_code == 200
        body = response.json()
        assert body["user"]["is_new_user"] is True
        assert body["user"]["selected_language"] == "am"
        assert body["user"]["daily_xp_target"] == 40

    def test_returning_user_via_google_no_data_overwrite(self, make_client: ClientFactory) -> None:
        google_verifier = FakeTokenVerifier(subject="google-returning-1")
        client = make_client(google_verifier, FakeTokenVerifier())

        first = client.post(
            "/api/v1/auth/google",
            json={
                "id_token": "t1",
                "pending_selection": {"language": "am", "daily_goal_minutes": 5},
            },
        )
        assert first.status_code == 200
        first_user_id = first.json()["user"]["id"]

        second = client.post(
            "/api/v1/auth/google",
            json={
                "id_token": "t2",
                "pending_selection": {"language": "am", "daily_goal_minutes": 20},
            },
        )
        assert second.status_code == 200
        second_body = second.json()

        assert second_body["user"]["is_new_user"] is False
        assert second_body["user"]["id"] == first_user_id
        # Not overwritten to the 20-min/80xp selection sent on this call --
        # the account keeps the value it was created with.
        assert second_body["user"]["daily_xp_target"] == 20

    def test_invalid_token_returns_401(self, make_client: ClientFactory) -> None:
        client = make_client(
            FakeTokenVerifier(exception=InvalidTokenError("bad")), FakeTokenVerifier()
        )

        response = client.post("/api/v1/auth/google", json={"id_token": "bad"})

        assert response.status_code == 401
        assert response.json()["error_code"] == "invalid_token"

    def test_unsupported_pending_language_returns_400_and_creates_no_account(
        self, make_client: ClientFactory
    ) -> None:
        google_verifier = FakeTokenVerifier(subject="google-bad-lang")
        client = make_client(google_verifier, FakeTokenVerifier())

        response = client.post(
            "/api/v1/auth/google",
            json={
                "id_token": "t",
                "pending_selection": {"language": "xx", "daily_goal_minutes": 10},
            },
        )

        assert response.status_code == 400
        assert response.json()["error_code"] == "invalid_pending_selection"

        # No malformed account was left behind -- a subsequent sign-in with
        # a valid selection must still be treated as a first-time user.
        retry = client.post(
            "/api/v1/auth/google",
            json={
                "id_token": "t",
                "pending_selection": {"language": "am", "daily_goal_minutes": 10},
            },
        )
        assert retry.status_code == 200
        assert retry.json()["user"]["is_new_user"] is True

    def test_provider_unreachable_returns_502(self, make_client: ClientFactory) -> None:
        client = make_client(
            FakeTokenVerifier(exception=ProviderUnreachableError("down")), FakeTokenVerifier()
        )

        response = client.post("/api/v1/auth/google", json={"id_token": "t"})

        assert response.status_code == 502
        assert response.json()["error_code"] == "provider_unreachable"

    def test_two_devices_same_account_get_independent_sessions(
        self, make_client: ClientFactory
    ) -> None:
        google_verifier = FakeTokenVerifier(subject="google-multidevice-1")
        client = make_client(google_verifier, FakeTokenVerifier())

        first = client.post("/api/v1/auth/google", json={"id_token": "device-a"})
        second = client.post("/api/v1/auth/google", json={"id_token": "device-b"})

        assert first.status_code == second.status_code == 200
        assert first.json()["user"]["id"] == second.json()["user"]["id"]
        assert first.json()["session_token"] != second.json()["session_token"]


class TestAppleAuthEndpoint:
    def test_new_user_via_apple_with_pending_selection(self, make_client: ClientFactory) -> None:
        client = make_client(FakeTokenVerifier(), FakeTokenVerifier(subject="apple-new-1"))

        response = client.post(
            "/api/v1/auth/apple",
            json={
                "identity_token": "whatever",
                "pending_selection": {"language": "am", "daily_goal_minutes": 10},
            },
        )

        assert response.status_code == 200
        body = response.json()
        assert body["user"]["is_new_user"] is True
        assert body["user"]["daily_xp_target"] == 40

    def test_returning_user_via_apple_dedup_by_stable_id(self, make_client: ClientFactory) -> None:
        """Story 003 AC2: matched correctly via the stable Apple subject id
        regardless of what the (fake) identity token payload otherwise
        contains -- `ProviderIdentity` has no email field at all, so a
        differing/absent private-relay email can never affect dedup."""
        apple_verifier = FakeTokenVerifier(subject="apple-stable-id-99")
        client = make_client(FakeTokenVerifier(), apple_verifier)

        first = client.post("/api/v1/auth/apple", json={"identity_token": "first-sign-in-token"})
        second = client.post(
            "/api/v1/auth/apple", json={"identity_token": "second-sign-in-different-token"}
        )

        assert first.status_code == second.status_code == 200
        assert first.json()["user"]["id"] == second.json()["user"]["id"]
        assert second.json()["user"]["is_new_user"] is False

    def test_invalid_token_returns_401(self, make_client: ClientFactory) -> None:
        client = make_client(
            FakeTokenVerifier(), FakeTokenVerifier(exception=InvalidTokenError("bad"))
        )

        response = client.post("/api/v1/auth/apple", json={"identity_token": "bad"})

        assert response.status_code == 401
        assert response.json()["error_code"] == "invalid_token"

    def test_provider_unreachable_returns_502(self, make_client: ClientFactory) -> None:
        client = make_client(
            FakeTokenVerifier(), FakeTokenVerifier(exception=ProviderUnreachableError("down"))
        )

        response = client.post("/api/v1/auth/apple", json={"identity_token": "t"})

        assert response.status_code == 502
        assert response.json()["error_code"] == "provider_unreachable"


class TestSessionEndpoint:
    def test_valid_session_recognized(self, make_client: ClientFactory) -> None:
        client = make_client(FakeTokenVerifier(subject="google-session-1"), FakeTokenVerifier())
        auth_response = client.post("/api/v1/auth/google", json={"id_token": "t"})
        token = auth_response.json()["session_token"]

        response = client.get("/api/v1/auth/session", headers={"Authorization": f"Bearer {token}"})

        assert response.status_code == 200
        body = response.json()
        assert body["valid"] is True
        assert body["user"]["id"] == auth_response.json()["user"]["id"]
        # A session just issued is not renewed again: it expires when sign-in
        # said it would, and the app can read that expiry from here.
        assert body["expires_at"][:19] == auth_response.json()["expires_at"][:19]

    def test_unknown_token_is_200_invalid_not_an_error(self, make_client: ClientFactory) -> None:
        client = make_client(FakeTokenVerifier(), FakeTokenVerifier())

        response = client.get(
            "/api/v1/auth/session", headers={"Authorization": "Bearer never-issued-token"}
        )

        assert response.status_code == 200
        assert response.json() == {"valid": False}

    def test_missing_authorization_header_returns_401_missing_credentials(
        self, make_client: ClientFactory
    ) -> None:
        client = make_client(FakeTokenVerifier(), FakeTokenVerifier())

        response = client.get("/api/v1/auth/session")

        assert response.status_code == 401
        assert response.json()["error_code"] == "missing_credentials"

    def test_malformed_authorization_header_returns_401(self, make_client: ClientFactory) -> None:
        client = make_client(FakeTokenVerifier(), FakeTokenVerifier())

        response = client.get("/api/v1/auth/session", headers={"Authorization": "NotBearer xyz"})

        assert response.status_code == 401
        assert response.json()["error_code"] == "missing_credentials"
