"""Integration tests: who passes the admin check (intent 028, stories 003
and 004). Owners come from `ADMIN_EMAILS`; everyone else from the team
tables, read on every request."""

from __future__ import annotations

from collections.abc import Callable
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.exc import OperationalError

from app.config import Settings
from app.domain.admin import COURSE_ADMIN, SUPER_ADMIN, AdminAccess
from app.domain.exceptions import SuperAdminOnlyError
from app.infrastructure.api import dependencies
from app.infrastructure.db.admin_member_repository import SqlAlchemyAdminMemberRepository
from tests.fakes import EN_AM_COURSE_ID, FakeTokenVerifier
from tests.team import add_member, remove_member

ClientFactory = Callable[[object, object], TestClient]
OWNER = "owner@example.com"
HELPER = "helper@example.com"


@pytest.fixture(autouse=True)
def owners(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(dependencies, "get_settings", lambda: Settings(admin_emails=OWNER))


@pytest.fixture
def google() -> FakeTokenVerifier:
    return FakeTokenVerifier()


@pytest.fixture
def client(make_client: ClientFactory, google: FakeTokenVerifier) -> TestClient:
    return make_client(google, FakeTokenVerifier())


def _sign_in(client: TestClient, google: FakeTokenVerifier, email: str) -> dict[str, str]:
    google.next_subject = f"sub-{email}"
    google.next_email = email
    response = client.post("/api/v1/auth/google", json={"id_token": "t"})
    assert response.status_code == 200
    return {"Authorization": f"Bearer {response.json()['session_token']}"}


def _me(client: TestClient, headers: dict[str, str]) -> dict[str, object]:
    response = client.get("/api/v1/admin/me", headers=headers)
    assert response.status_code == 200, response.text
    body: dict[str, object] = response.json()
    return body


def test_an_owner_is_a_super_admin(client: TestClient, google: FakeTokenVerifier) -> None:
    assert _me(client, _sign_in(client, google, OWNER)) == {
        "email": OWNER,
        "role": SUPER_ADMIN,
        "is_owner": True,
        "course_ids": None,
    }


def test_an_owner_on_the_team_is_still_an_owner(
    client: TestClient, google: FakeTokenVerifier, db_path: Path
) -> None:
    add_member(db_path, OWNER, COURSE_ADMIN, [EN_AM_COURSE_ID])

    me = _me(client, _sign_in(client, google, OWNER))

    assert (me["role"], me["is_owner"], me["course_ids"]) == (SUPER_ADMIN, True, None)


def test_a_stored_super_admin_has_every_course(
    client: TestClient, google: FakeTokenVerifier, db_path: Path
) -> None:
    add_member(db_path, HELPER, SUPER_ADMIN)

    assert _me(client, _sign_in(client, google, "Helper@Example.com")) == {
        "email": HELPER,
        "role": SUPER_ADMIN,
        "is_owner": False,
        "course_ids": None,
    }


def test_a_course_admin_has_their_courses(
    client: TestClient, google: FakeTokenVerifier, db_path: Path
) -> None:
    add_member(db_path, HELPER, COURSE_ADMIN, [EN_AM_COURSE_ID])

    assert _me(client, _sign_in(client, google, HELPER)) == {
        "email": HELPER,
        "role": COURSE_ADMIN,
        "is_owner": False,
        "course_ids": [EN_AM_COURSE_ID],
    }


def test_a_course_admin_with_no_courses_can_still_sign_in(
    client: TestClient, google: FakeTokenVerifier, db_path: Path
) -> None:
    add_member(db_path, HELPER, COURSE_ADMIN)

    assert _me(client, _sign_in(client, google, HELPER))["course_ids"] == []


def test_someone_not_on_the_team_is_403(client: TestClient, google: FakeTokenVerifier) -> None:
    response = client.get("/api/v1/admin/me", headers=_sign_in(client, google, HELPER))

    assert response.status_code == 403
    assert response.json()["error_code"] == "not_admin"


def test_removing_a_member_revokes_on_the_next_request(
    client: TestClient, google: FakeTokenVerifier, db_path: Path
) -> None:
    member_id = add_member(db_path, HELPER, SUPER_ADMIN)
    headers = _sign_in(client, google, HELPER)
    assert client.get("/api/v1/admin/me", headers=headers).status_code == 200

    remove_member(db_path, member_id)

    assert client.get("/api/v1/admin/me", headers=headers).status_code == 403


def test_a_course_admin_passes_the_router_guard(
    client: TestClient, google: FakeTokenVerifier, db_path: Path
) -> None:
    # The routes themselves are restricted in bolts 103-107.
    add_member(db_path, HELPER, COURSE_ADMIN, [EN_AM_COURSE_ID])

    response = client.get("/api/v1/admin/courses", headers=_sign_in(client, google, HELPER))

    assert response.status_code == 200


def test_a_team_that_cannot_be_read_is_503_not_access(
    client: TestClient, google: FakeTokenVerifier, monkeypatch: pytest.MonkeyPatch
) -> None:
    headers = _sign_in(client, google, HELPER)

    async def broken(self: object, email: str) -> None:
        raise OperationalError("SELECT", {}, Exception("database is locked"))

    monkeypatch.setattr(SqlAlchemyAdminMemberRepository, "find_by_email", broken)
    response = client.get("/api/v1/admin/me", headers=headers)

    assert response.status_code == 503
    assert response.json()["error_code"] == "admin_access_unavailable"


def test_an_owner_needs_no_team_read(
    client: TestClient, google: FakeTokenVerifier, monkeypatch: pytest.MonkeyPatch
) -> None:
    headers = _sign_in(client, google, OWNER)

    async def broken(self: object, email: str) -> None:
        raise OperationalError("SELECT", {}, Exception("database is locked"))

    monkeypatch.setattr(SqlAlchemyAdminMemberRepository, "find_by_email", broken)

    assert client.get("/api/v1/admin/me", headers=headers).status_code == 200


async def test_super_admin_only_refuses_a_course_admin() -> None:
    access = AdminAccess(email=HELPER, role=COURSE_ADMIN, course_ids=frozenset())

    with pytest.raises(SuperAdminOnlyError) as raised:
        await dependencies.require_super_admin(access)

    assert raised.value.error_code == "super_admin_only"


async def test_super_admin_only_lets_a_super_admin_through() -> None:
    access = AdminAccess(email=HELPER, role=SUPER_ADMIN)

    assert await dependencies.require_super_admin(access) is access
