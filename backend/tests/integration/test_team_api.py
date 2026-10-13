"""Integration tests: the Team API (intent 028, stories 011 and 012)."""

from __future__ import annotations

import logging
from collections.abc import Callable
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app.config import Settings
from app.domain.admin import COURSE_ADMIN, SUPER_ADMIN
from app.infrastructure.api import dependencies
from tests.fakes import EN_AM_COURSE_ID, FakeTokenVerifier
from tests.team import add_member

ClientFactory = Callable[[object, object], TestClient]
Pair = tuple[TestClient, FakeTokenVerifier]
OWNER = "owner@example.com"
SECOND_OWNER = "boss@example.com"
HELPER = "helper@example.com"
T = "/api/v1/admin/team"


@pytest.fixture
def pair(make_client: ClientFactory, monkeypatch: pytest.MonkeyPatch) -> Pair:
    settings = Settings(admin_emails=f"{OWNER}, {SECOND_OWNER}")
    monkeypatch.setattr(dependencies, "get_settings", lambda: settings)
    google = FakeTokenVerifier()
    return make_client(google, FakeTokenVerifier()), google


def _sign_in(pair: Pair, email: str) -> dict[str, str]:
    client, google = pair
    google.next_subject = f"sub-{email}"
    google.next_email = email
    response = client.post("/api/v1/auth/google", json={"id_token": "t"})
    assert response.status_code == 200
    return {"Authorization": f"Bearer {response.json()['session_token']}"}


@pytest.fixture
def owner(pair: Pair) -> dict[str, str]:
    return _sign_in(pair, OWNER)


def _add(pair: Pair, h: dict, **body: object) -> dict[str, object]:
    response = pair[0].post(T, json=body, headers=h)
    assert response.status_code == 201, response.text
    result: dict[str, object] = response.json()
    return result


class TestList:
    def test_owners_come_first_then_members_by_email(
        self, pair: Pair, owner: dict, db_path: Path
    ) -> None:
        add_member(db_path, "zed@example.com", SUPER_ADMIN)
        add_member(db_path, "amy@example.com", COURSE_ADMIN, [EN_AM_COURSE_ID])

        members = pair[0].get(T, headers=owner).json()["members"]

        assert [m["email"] for m in members] == [
            SECOND_OWNER,
            OWNER,
            "amy@example.com",
            "zed@example.com",
        ]
        boss, me, amy, zed = members
        assert (me["id"], me["is_owner"], me["role"], me["courses"]) == (
            None,
            True,
            SUPER_ADMIN,
            [],
        )
        assert me["created_by"] is None
        assert amy["courses"] == [{"id": EN_AM_COURSE_ID, "title": "English to Amharic"}]
        assert zed["courses"] == [] and zed["is_owner"] is False
        assert amy["created_by"] == "owner@example.com" and amy["created_at"]

    def test_last_sign_in_is_the_newest_session_or_null(self, pair: Pair, owner: dict) -> None:
        members = {m["email"]: m for m in pair[0].get(T, headers=owner).json()["members"]}

        assert members[OWNER]["last_signed_in_at"] is not None
        assert members[SECOND_OWNER]["last_signed_in_at"] is None

    def test_a_course_admin_may_not_see_the_team(self, pair: Pair, db_path: Path) -> None:
        add_member(db_path, HELPER, COURSE_ADMIN)

        response = pair[0].get(T, headers=_sign_in(pair, HELPER))

        assert response.status_code == 403
        assert response.json()["error_code"] == "super_admin_only"


class TestAdd:
    def test_adds_a_course_admin_who_can_then_sign_in(
        self, pair: Pair, owner: dict, caplog: pytest.LogCaptureFixture
    ) -> None:
        with caplog.at_level(logging.INFO, logger="app.admin"):
            added = _add(
                pair,
                owner,
                email=" Helper@Example.com",
                role=COURSE_ADMIN,
                course_ids=[EN_AM_COURSE_ID],
            )

        assert added["email"] == HELPER and added["id"]
        assert added["courses"] == [{"id": EN_AM_COURSE_ID, "title": "English to Amharic"}]
        assert added["last_signed_in_at"] is None
        assert f"action=add entity=admin_member id={added['id']} role=course_admin courses=1" in (
            caplog.text
        )
        me = pair[0].get("/api/v1/admin/me", headers=_sign_in(pair, HELPER)).json()
        assert me["course_ids"] == [EN_AM_COURSE_ID]

    def test_a_course_admin_with_no_courses_may_be_added(self, pair: Pair, owner: dict) -> None:
        assert _add(pair, owner, email=HELPER, role=COURSE_ADMIN)["courses"] == []

    def test_adds_a_super_admin(self, pair: Pair, owner: dict) -> None:
        added = _add(pair, owner, email=HELPER, role=SUPER_ADMIN)

        assert added["role"] == SUPER_ADMIN
        me = pair[0].get("/api/v1/admin/me", headers=_sign_in(pair, HELPER)).json()
        assert me["role"] == SUPER_ADMIN and me["course_ids"] is None

    @pytest.mark.parametrize(
        ("body", "status", "code", "field", "message"),
        [
            (
                {"email": "nope", "role": COURSE_ADMIN},
                422,
                "invalid_content",
                "email",
                "Enter an email address",
            ),
            (
                {"email": "Owner@example.com", "role": COURSE_ADMIN},
                409,
                "admin_member_exists",
                "email",
                "owner@example.com is an owner already",
            ),
            (
                {"email": HELPER, "role": "editor"},
                422,
                "invalid_content",
                "role",
                "Choose super admin or course admin",
            ),
            (
                {"email": HELPER, "role": COURSE_ADMIN, "course_ids": ["gone"]},
                422,
                "invalid_content",
                "course_ids",
                "A chosen course no longer exists",
            ),
            (
                {"email": HELPER, "role": SUPER_ADMIN, "course_ids": [EN_AM_COURSE_ID]},
                422,
                "invalid_content",
                "course_ids",
                "A super admin has every course",
            ),
        ],
    )
    def test_refuses_a_bad_member(
        self,
        pair: Pair,
        owner: dict,
        body: dict,
        status: int,
        code: str,
        field: str,
        message: str,
    ) -> None:
        response = pair[0].post(T, json=body, headers=owner)

        assert response.status_code == status
        assert response.json()["error_code"] == code
        assert response.json()["message"] == message
        assert response.json()["details"]["field"] == field
        assert len(pair[0].get(T, headers=owner).json()["members"]) == 2

    def test_refuses_someone_already_on_the_team(self, pair: Pair, owner: dict) -> None:
        _add(pair, owner, email=HELPER, role=COURSE_ADMIN)

        response = pair[0].post(T, json={"email": HELPER, "role": SUPER_ADMIN}, headers=owner)

        assert response.status_code == 409
        assert response.json()["message"] == f"{HELPER} is already on the team"


class TestChange:
    def test_changes_role_and_courses(self, pair: Pair, owner: dict) -> None:
        added = _add(pair, owner, email=HELPER, role=COURSE_ADMIN, course_ids=[EN_AM_COURSE_ID])

        response = pair[0].put(f"{T}/{added['id']}", json={"role": SUPER_ADMIN}, headers=owner)

        assert response.status_code == 200, response.text
        assert response.json()["role"] == SUPER_ADMIN
        assert response.json()["courses"] == []
        assert response.json()["updated_by"] == OWNER

    def test_a_stored_super_admin_may_manage_the_team(self, pair: Pair, db_path: Path) -> None:
        add_member(db_path, "lead@example.com", SUPER_ADMIN)
        lead = _sign_in(pair, "lead@example.com")
        added = _add(pair, lead, email=HELPER, role=COURSE_ADMIN)

        response = pair[0].put(
            f"{T}/{added['id']}",
            json={"role": COURSE_ADMIN, "course_ids": [EN_AM_COURSE_ID]},
            headers=lead,
        )

        assert response.status_code == 200
        assert response.json()["updated_by"] == "lead@example.com"

    def test_nobody_changes_or_removes_themselves(self, pair: Pair, db_path: Path) -> None:
        member_id = add_member(db_path, "lead@example.com", SUPER_ADMIN)
        lead = _sign_in(pair, "lead@example.com")

        changed = pair[0].put(f"{T}/{member_id}", json={"role": COURSE_ADMIN}, headers=lead)
        removed = pair[0].delete(f"{T}/{member_id}", headers=lead)

        for response in (changed, removed):
            assert response.status_code == 409
            assert response.json()["error_code"] == "admin_member_self"
            assert response.json()["message"] == (
                "You can't change your own access. Ask another super admin."
            )

    @pytest.mark.parametrize("method", ["PUT", "DELETE"])
    def test_an_unknown_id_is_404(self, pair: Pair, owner: dict, method: str) -> None:
        body = {"role": SUPER_ADMIN} if method == "PUT" else None

        response = pair[0].request(method, f"{T}/missing", json=body, headers=owner)

        assert response.status_code == 404
        assert response.json()["details"] == {"entity": "admin_member", "id": "missing"}


class TestRemove:
    def test_removed_member_loses_access_on_the_next_request(
        self, pair: Pair, owner: dict, caplog: pytest.LogCaptureFixture
    ) -> None:
        added = _add(pair, owner, email=HELPER, role=COURSE_ADMIN)
        helper = _sign_in(pair, HELPER)
        assert pair[0].get("/api/v1/admin/me", headers=helper).status_code == 200

        with caplog.at_level(logging.INFO, logger="app.admin"):
            response = pair[0].delete(f"{T}/{added['id']}", headers=owner)

        assert response.status_code == 204
        assert "action=remove entity=admin_member" in caplog.text
        assert pair[0].get("/api/v1/admin/me", headers=helper).status_code == 403
        assert [m["email"] for m in pair[0].get(T, headers=owner).json()["members"]] == [
            SECOND_OWNER,
            OWNER,
        ]
