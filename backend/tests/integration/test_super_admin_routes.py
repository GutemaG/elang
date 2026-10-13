"""Integration tests: configuration, course writes, learners and feedback
are for super admins only (intent 028, story 005)."""

from __future__ import annotations

import sqlite3
from collections.abc import Callable
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from httpx import Response

from app.config import Settings
from app.domain.admin import COURSE_ADMIN, SUPER_ADMIN
from app.infrastructure.api import dependencies
from tests.fakes import EN_AM_COURSE_ID, FakeTokenVerifier
from tests.integration.admin_route_rules import SUPER_ONLY, concrete
from tests.team import add_member

ClientFactory = Callable[[object, object], TestClient]
OWNER = "owner@example.com"
HELPER = "helper@example.com"
ROUTES = sorted(SUPER_ONLY)


@pytest.fixture(autouse=True)
def owners(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(dependencies, "get_settings", lambda: Settings(admin_emails=OWNER))


@pytest.fixture
def client(make_client: ClientFactory) -> tuple[TestClient, FakeTokenVerifier]:
    google = FakeTokenVerifier()
    return make_client(google, FakeTokenVerifier()), google


def _sign_in(pair: tuple[TestClient, FakeTokenVerifier], email: str) -> dict[str, str]:
    client, google = pair
    google.next_subject = f"sub-{email}"
    google.next_email = email
    response = client.post("/api/v1/auth/google", json={"id_token": "t"})
    assert response.status_code == 200
    return {"Authorization": f"Bearer {response.json()['session_token']}"}


def _call(client: TestClient, method: str, path: str, headers: dict[str, str]) -> Response:
    body: dict[str, object] | None = None if method in ("GET", "DELETE") else {}
    return client.request(method, concrete(path), headers=headers, json=body)


@pytest.mark.parametrize(("method", "path"), ROUTES)
def test_a_course_admin_is_refused(
    client: tuple[TestClient, FakeTokenVerifier], db_path: Path, method: str, path: str
) -> None:
    add_member(db_path, HELPER, COURSE_ADMIN, [EN_AM_COURSE_ID])
    headers = _sign_in(client, HELPER)

    response = _call(client[0], method, path, headers)

    assert response.status_code == 403
    assert response.json() == {
        "error_code": "super_admin_only",
        "message": "Only a super admin can do this",
    }


@pytest.mark.parametrize(("method", "path"), ROUTES)
def test_a_stored_super_admin_is_not_refused(
    client: tuple[TestClient, FakeTokenVerifier], db_path: Path, method: str, path: str
) -> None:
    add_member(db_path, HELPER, SUPER_ADMIN)

    assert _call(client[0], method, path, _sign_in(client, HELPER)).status_code != 403


def _snapshot(db_path: Path) -> dict[str, list[tuple[object, ...]]]:
    with sqlite3.connect(db_path) as conn:
        return {
            table: sorted(conn.execute(f"SELECT * FROM {table}").fetchall(), key=repr)
            for table in ("courses", "languages", "app_config")
        }


def test_refused_writes_change_nothing(
    client: tuple[TestClient, FakeTokenVerifier], db_path: Path
) -> None:
    add_member(db_path, HELPER, COURSE_ADMIN, [EN_AM_COURSE_ID])
    headers = _sign_in(client, HELPER)
    before = _snapshot(db_path)

    responses = [
        client[0].post(
            "/api/v1/admin/courses",
            headers=headers,
            json={"learning_language": "om", "from_language": "en", "title": "English to Oromo"},
        ),
        client[0].patch(
            f"/api/v1/admin/courses/{EN_AM_COURSE_ID}", headers=headers, json={"title": "Renamed"}
        ),
        client[0].delete(f"/api/v1/admin/courses/{EN_AM_COURSE_ID}", headers=headers),
        client[0].patch(
            "/api/v1/admin/app-config", headers=headers, json={"min_build_android": 99}
        ),
        client[0].post(
            "/api/v1/admin/languages", headers=headers, json={"code": "ti", "name": "Tigrinya"}
        ),
    ]

    assert [r.status_code for r in responses] == [403] * len(responses)
    assert _snapshot(db_path) == before
