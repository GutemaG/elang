"""Integration tests: the admin site's App updates page, over HTTP against a
temp SQLite database. `GET`/`PATCH /api/v1/admin/app-config` read and
change the app-wide values `GET /api/v1/config` sends the app.
"""

from __future__ import annotations

from collections.abc import Callable

import pytest
from fastapi.testclient import TestClient

from app.config import Settings
from app.infrastructure.api import dependencies
from tests.fakes import FakeTokenVerifier

ClientFactory = Callable[[object, object], TestClient]
ADMIN = "admin@example.com"
URL = "/api/v1/admin/app-config"

_DEFAULTS = {
    "min_build_android": 0,
    "min_build_ios": 0,
    "latest_build_ios": 0,
    "ios_store_url": "",
}


def _headers(client: TestClient) -> dict[str, str]:
    token = client.post("/api/v1/auth/google", json={"id_token": "t"}).json()["session_token"]
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
def admin(make_client: ClientFactory, monkeypatch: pytest.MonkeyPatch) -> tuple[TestClient, dict]:
    monkeypatch.setattr(dependencies, "get_settings", lambda: Settings(admin_emails=ADMIN))
    client = make_client(FakeTokenVerifier(subject="sub-admin", email=ADMIN), FakeTokenVerifier())
    return client, _headers(client)


def test_every_value_starts_at_its_default(admin: tuple[TestClient, dict]) -> None:
    client, h = admin
    response = client.get(URL, headers=h)
    assert response.status_code == 200
    assert response.json() == {"config": _DEFAULTS}


def test_a_change_is_saved_and_reaches_the_app(admin: tuple[TestClient, dict]) -> None:
    client, h = admin
    response = client.patch(URL, json={"min_build_android": 5}, headers=h)
    assert response.status_code == 200
    assert response.json()["config"] == {**_DEFAULTS, "min_build_android": 5}

    # Changed again: the row is replaced, and the other values are kept.
    client.patch(
        URL,
        json={"min_build_android": 6, "ios_store_url": "https://apps.apple.com/app/id1"},
        headers=h,
    )
    expected = {
        **_DEFAULTS,
        "min_build_android": 6,
        "ios_store_url": "https://apps.apple.com/app/id1",
    }
    assert client.get(URL, headers=h).json()["config"] == expected
    # The app's own, signed-out read sees the same.
    assert client.get("/api/v1/config").json()["config"] == expected


@pytest.mark.parametrize(
    "changes",
    [
        {"min_build_android": -1},
        {"min_build_android": "5"},
        {"min_build_android": True},
        {"ios_store_url": "http://apps.apple.com/app/id1"},
        {"unknown_key": 1},
    ],
)
def test_a_bad_value_saves_nothing(admin: tuple[TestClient, dict], changes: dict) -> None:
    client, h = admin
    response = client.patch(URL, json={"min_build_ios": 3, **changes}, headers=h)
    assert response.status_code == 422
    assert response.json()["error_code"] == "invalid_setting"
    assert client.get(URL, headers=h).json()["config"] == _DEFAULTS


def test_only_an_admin_may_read_or_change_it(
    make_client: ClientFactory, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(dependencies, "get_settings", lambda: Settings(admin_emails=ADMIN))
    client = make_client(
        FakeTokenVerifier(subject="sub-learner", email="learner@example.com"), FakeTokenVerifier()
    )
    h = _headers(client)
    assert client.get(URL, headers=h).status_code == 403
    assert client.patch(URL, json={"min_build_android": 99}, headers=h).status_code == 403
    assert client.get(URL).status_code == 401
    assert client.get("/api/v1/config").json()["config"] == _DEFAULTS
