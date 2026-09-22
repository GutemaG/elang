"""Integration tests: `/api/v1/admin/*` authorization (story
001-admin-authorization, ADR-16), through the real auth flow: sign in with a
fake Google verifier, then call the admin API with the issued session token.
"""

from __future__ import annotations

from collections.abc import Callable

import pytest
from fastapi.testclient import TestClient

from app.config import Settings
from app.infrastructure.api import dependencies
from app.infrastructure.api.admin_routers import router as admin_router
from tests.fakes import FakeTokenVerifier

ClientFactory = Callable[[object, object], TestClient]
ADMIN = "admin@example.com"


class _AllowList:
    """Stands in for the cached settings, so a test can change
    `ADMIN_EMAILS` between two requests."""

    def __init__(self, value: str) -> None:
        self.value = value

    def __call__(self) -> Settings:
        return Settings(admin_emails=self.value)


@pytest.fixture
def allow_list(monkeypatch: pytest.MonkeyPatch) -> _AllowList:
    holder = _AllowList(ADMIN)
    monkeypatch.setattr(dependencies, "get_settings", holder)
    return holder


@pytest.fixture
def google() -> FakeTokenVerifier:
    return FakeTokenVerifier()


@pytest.fixture
def client(make_client: ClientFactory, google: FakeTokenVerifier) -> TestClient:
    return make_client(google, FakeTokenVerifier())


def _sign_in(
    client: TestClient, verifier: FakeTokenVerifier, subject: str, email: str | None
) -> dict[str, str]:
    verifier.next_subject = subject
    verifier.next_email = email
    response = client.post("/api/v1/auth/google", json={"id_token": "t"})
    assert response.status_code == 200
    return {"Authorization": f"Bearer {response.json()['session_token']}"}


@pytest.mark.usefixtures("allow_list")
class TestAdminMe:
    def test_no_token_is_401(self, client: TestClient) -> None:
        assert client.get("/api/v1/admin/me").status_code == 401

    def test_unknown_token_is_401(self, client: TestClient) -> None:
        response = client.get("/api/v1/admin/me", headers={"Authorization": "Bearer nope"})
        assert response.status_code == 401

    def test_admin_gets_their_email(self, client: TestClient, google: FakeTokenVerifier) -> None:
        headers = _sign_in(client, google, "sub-admin", ADMIN)

        response = client.get("/api/v1/admin/me", headers=headers)

        assert response.status_code == 200
        assert response.json() == {"email": ADMIN}

    def test_email_matching_ignores_case(
        self, client: TestClient, google: FakeTokenVerifier
    ) -> None:
        headers = _sign_in(client, google, "sub-admin", "Admin@Example.COM")
        assert client.get("/api/v1/admin/me", headers=headers).status_code == 200

    def test_non_admin_is_403(self, client: TestClient, google: FakeTokenVerifier) -> None:
        headers = _sign_in(client, google, "sub-learner", "learner@example.com")

        response = client.get("/api/v1/admin/me", headers=headers)

        assert response.status_code == 403
        assert response.json()["error_code"] == "not_admin"

    def test_unverified_email_is_never_admin(
        self, client: TestClient, google: FakeTokenVerifier
    ) -> None:
        # The verifier drops an unverified email, so the user has none.
        headers = _sign_in(client, google, "sub-unverified", None)
        assert client.get("/api/v1/admin/me", headers=headers).status_code == 403

    def test_learner_endpoints_still_work_for_a_non_admin(
        self, client: TestClient, google: FakeTokenVerifier
    ) -> None:
        headers = _sign_in(client, google, "sub-learner", "learner@example.com")
        assert client.get("/api/v1/auth/session", headers=headers).json()["valid"] is True


class TestAllowListChanges:
    def test_removing_the_email_revokes_on_the_next_request(
        self, client: TestClient, google: FakeTokenVerifier, allow_list: _AllowList
    ) -> None:
        headers = _sign_in(client, google, "sub-admin", ADMIN)
        assert client.get("/api/v1/admin/me", headers=headers).status_code == 200

        allow_list.value = "someone-else@example.com"

        assert client.get("/api/v1/admin/me", headers=headers).status_code == 403

    @pytest.mark.parametrize("value", ["", " ", ","])
    def test_empty_allow_list_admits_nobody(
        self,
        client: TestClient,
        google: FakeTokenVerifier,
        allow_list: _AllowList,
        value: str,
    ) -> None:
        allow_list.value = value
        headers = _sign_in(client, google, "sub-admin", ADMIN)
        assert client.get("/api/v1/admin/me", headers=headers).status_code == 403

    @pytest.mark.usefixtures("allow_list")
    def test_email_changed_at_google_moves_admin_access(
        self, client: TestClient, google: FakeTokenVerifier
    ) -> None:
        # Same Google account (same sub), different verified email at the
        # next sign-in: the stored email follows it.
        before = _sign_in(client, google, "sub-moving", "learner@example.com")
        assert client.get("/api/v1/admin/me", headers=before).status_code == 403

        after = _sign_in(client, google, "sub-moving", ADMIN)

        assert client.get("/api/v1/admin/me", headers=after).status_code == 200
        # The email lives on the user, so the older session is admin too.
        assert client.get("/api/v1/admin/me", headers=before).status_code == 200


def test_every_admin_route_sits_behind_the_router_guard() -> None:
    """The guard is on the router, so no route under it can skip it."""
    assert admin_router.routes
    assert dependencies.require_admin in [d.dependency for d in admin_router.dependencies]
    assert all(route.path.startswith("/api/v1/admin") for route in admin_router.routes)
