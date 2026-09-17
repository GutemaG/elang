"""Integration tests: `PATCH /api/v1/users/me` (bolt
`013-user-preferences-service`), via FastAPI `TestClient` against a real
temp-file SQLite database. Covers stories 001/002's acceptance criteria.
"""

from __future__ import annotations

from collections.abc import Callable

from fastapi.testclient import TestClient

from tests.fakes import FakeTokenVerifier

ClientFactory = Callable[[object, object], TestClient]


def _sign_up(client: TestClient, provider_user_id: str) -> str:
    """Signs up a fresh user via the existing Google auth endpoint and
    returns the raw session token -- the shortest real path to an
    authenticated user, reusing `001-auth-service`'s own flow rather than
    reaching into the DB directly.
    """
    response = client.post(
        "/api/v1/auth/google",
        json={
            "id_token": "whatever",
            "pending_selection": {"language": "am", "daily_goal_minutes": 10},
        },
    )
    assert response.status_code == 200
    return response.json()["session_token"]


class TestUpdateMyPreferencesEndpoint:
    def test_updates_language_goal_and_notification(self, make_client: ClientFactory) -> None:
        client = make_client(FakeTokenVerifier(subject=f"{__name__}-1"), FakeTokenVerifier())
        token = _sign_up(client, f"{__name__}-1")

        response = client.patch(
            "/api/v1/users/me",
            json={"language": "am", "daily_goal_minutes": 20, "notification_enabled": False},
            headers={"Authorization": f"Bearer {token}"},
        )

        assert response.status_code == 200
        body = response.json()
        assert body["selected_language"] == "am"
        assert body["daily_xp_target"] == 80
        assert body["notification_enabled"] is False

    def test_change_is_reflected_on_a_later_session_check(self, make_client: ClientFactory) -> None:
        client = make_client(FakeTokenVerifier(subject=f"{__name__}-2"), FakeTokenVerifier())
        token = _sign_up(client, f"{__name__}-2")

        client.patch(
            "/api/v1/users/me",
            json={"daily_goal_minutes": 15, "notification_enabled": False},
            headers={"Authorization": f"Bearer {token}"},
        )

        session_check = client.get(
            "/api/v1/auth/session", headers={"Authorization": f"Bearer {token}"}
        )
        assert session_check.status_code == 200
        session_body = session_check.json()
        assert session_body["valid"] is True
        assert session_body["user"]["daily_xp_target"] == 60
        assert session_body["user"]["notification_enabled"] is False

    def test_empty_body_is_a_no_op_success(self, make_client: ClientFactory) -> None:
        client = make_client(FakeTokenVerifier(subject=f"{__name__}-3"), FakeTokenVerifier())
        token = _sign_up(client, f"{__name__}-3")

        response = client.patch(
            "/api/v1/users/me", json={}, headers={"Authorization": f"Bearer {token}"}
        )

        assert response.status_code == 200
        body = response.json()
        assert body["selected_language"] == "am"
        assert body["daily_xp_target"] == 40
        assert body["notification_enabled"] is True

    def test_resubmitting_current_values_is_a_no_op_success(
        self, make_client: ClientFactory
    ) -> None:
        client = make_client(FakeTokenVerifier(subject=f"{__name__}-4"), FakeTokenVerifier())
        token = _sign_up(client, f"{__name__}-4")

        response = client.patch(
            "/api/v1/users/me",
            json={"language": "am", "daily_goal_minutes": 10, "notification_enabled": True},
            headers={"Authorization": f"Bearer {token}"},
        )

        assert response.status_code == 200

    def test_invalid_language_is_rejected_422(self, make_client: ClientFactory) -> None:
        client = make_client(FakeTokenVerifier(subject=f"{__name__}-5"), FakeTokenVerifier())
        token = _sign_up(client, f"{__name__}-5")

        response = client.patch(
            "/api/v1/users/me",
            json={"language": "xx"},
            headers={"Authorization": f"Bearer {token}"},
        )

        assert response.status_code == 422
        assert response.json()["error_code"] == "invalid_preference_value"

    def test_invalid_daily_goal_minutes_is_rejected_422(self, make_client: ClientFactory) -> None:
        client = make_client(FakeTokenVerifier(subject=f"{__name__}-6"), FakeTokenVerifier())
        token = _sign_up(client, f"{__name__}-6")

        response = client.patch(
            "/api/v1/users/me",
            json={"daily_goal_minutes": 7},
            headers={"Authorization": f"Bearer {token}"},
        )

        assert response.status_code == 422
        assert response.json()["error_code"] == "invalid_preference_value"

    def test_missing_auth_header_is_rejected_401(self, make_client: ClientFactory) -> None:
        client = make_client(FakeTokenVerifier(), FakeTokenVerifier())

        response = client.patch("/api/v1/users/me", json={"language": "am"})

        assert response.status_code == 401

    def test_unknown_session_token_is_rejected_401(self, make_client: ClientFactory) -> None:
        client = make_client(FakeTokenVerifier(), FakeTokenVerifier())

        response = client.patch(
            "/api/v1/users/me",
            json={"language": "am"},
            headers={"Authorization": "Bearer does-not-exist"},
        )

        assert response.status_code == 401

    def test_new_signup_defaults_notification_enabled_to_true(
        self, make_client: ClientFactory
    ) -> None:
        client = make_client(FakeTokenVerifier(subject=f"{__name__}-7"), FakeTokenVerifier())
        token = _sign_up(client, f"{__name__}-7")

        session_check = client.get(
            "/api/v1/auth/session", headers={"Authorization": f"Bearer {token}"}
        )
        assert session_check.json()["user"]["notification_enabled"] is True
