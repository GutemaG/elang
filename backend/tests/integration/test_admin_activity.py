"""Integration tests (intent 030, FR-8 and FR-9): every admin write route
has an activity label; successful changes are recorded with who, what and
where; failed or refused ones aren't; and `GET /api/v1/admin/activity`
reads the log back. Also the admin Leagues API over HTTP.
"""

from __future__ import annotations

import sqlite3
from collections.abc import Callable
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any

import pytest
from fastapi.routing import APIRoute
from fastapi.testclient import TestClient

from app.application import activity_use_cases
from app.config import Settings
from app.domain.activity import ADMIN_ACTIONS, AREAS
from app.domain.admin import COURSE_ADMIN
from app.domain.league import week_start
from app.infrastructure.api import dependencies
from app.infrastructure.db.activity_repository import SqlAlchemyActivityRepository
from app.main import create_app
from tests.fakes import EN_AM_COURSE_ID, FakeTokenVerifier
from tests.team import add_member

ClientFactory = Callable[[object, object], TestClient]
Pair = tuple[TestClient, FakeTokenVerifier]
OWNER = "owner@example.com"
HELPER = "helper@example.com"
A = "/api/v1/admin"


def _write_routes() -> set[tuple[str, str]]:
    found = set()
    for entry in create_app().routes:
        routes = entry.effective_candidates() if hasattr(entry, "effective_candidates") else [entry]
        for route in routes:
            is_api = isinstance(route, APIRoute) or hasattr(route, "dependant")
            if is_api and route.path.startswith(A):
                found |= {(m, route.path) for m in route.methods if m != "GET"}
    return found


def test_every_admin_write_route_has_an_activity_label() -> None:
    routes = _write_routes()
    assert len(routes) > 40

    assert sorted(routes - set(ADMIN_ACTIONS)) == [], "write routes with no ADMIN_ACTIONS entry"
    assert sorted(set(ADMIN_ACTIONS) - routes) == [], "ADMIN_ACTIONS entries for no route"
    assert {a.area for a in ADMIN_ACTIONS.values() if a is not None} <= set(AREAS)


@pytest.fixture
def pair(make_client: ClientFactory, monkeypatch: pytest.MonkeyPatch) -> Pair:
    monkeypatch.setattr(dependencies, "get_settings", lambda: Settings(admin_emails=OWNER))
    google = FakeTokenVerifier()
    return make_client(google, FakeTokenVerifier()), google


def _sign_in(pair: Pair, email: str, first_name: str | None = None) -> dict[str, str]:
    client, google = pair
    google.next_subject = f"sub-{email}"
    google.next_email = email
    google.next_first_name = first_name
    response = client.post("/api/v1/auth/google", json={"id_token": "t"})
    assert response.status_code == 200
    return {"Authorization": f"Bearer {response.json()['session_token']}"}


@pytest.fixture
def owner(pair: Pair) -> dict[str, str]:
    return _sign_in(pair, OWNER)


def _log(pair: Pair, h: dict[str, str], **params: str) -> dict[str, Any]:
    response = pair[0].get(f"{A}/activity", headers=h, params=params)
    assert response.status_code == 200, response.text
    body: dict[str, Any] = response.json()
    return body


def _rows(db_path: Path) -> int:
    with sqlite3.connect(db_path) as conn:
        return int(conn.execute("SELECT COUNT(*) FROM admin_activity").fetchone()[0])


class TestRecording:
    def test_an_edit_is_recorded_with_who_what_and_where(
        self, pair: Pair, owner: dict[str, str]
    ) -> None:
        response = pair[0].patch(
            f"{A}/courses/{EN_AM_COURSE_ID}", json={"title": "Amharic for you"}, headers=owner
        )
        assert response.status_code == 200, response.text

        (entry,) = _log(pair, owner)["items"]

        assert entry["admin_email"] == OWNER and entry["admin_role"] == "super_admin"
        assert (entry["area"], entry["action"]) == ("curriculum", "Edited course")
        assert entry["route"] == f"{A}/courses/{{course_id}}" and entry["method"] == "PATCH"
        assert (entry["target_kind"], entry["target_id"]) == ("course", EN_AM_COURSE_ID)
        assert entry["target_name"] == "Amharic for you"
        assert entry["course_id"] == EN_AM_COURSE_ID
        assert entry["link"] == f"/courses/{EN_AM_COURSE_ID}"

    def test_a_create_and_a_delete_keep_their_names(
        self, pair: Pair, owner: dict[str, str]
    ) -> None:
        body = {"code": "ti", "name": "Tigrinya", "native_name": "ትግርኛ"}
        assert pair[0].post(f"{A}/languages", json=body, headers=owner).status_code == 201
        assert pair[0].delete(f"{A}/languages/ti", headers=owner).status_code == 204

        deleted, added = _log(pair, owner)["items"]

        assert (added["action"], added["target_name"], added["link"]) == (
            "Added language",
            "Tigrinya (ti)",
            "/languages",
        )
        assert (deleted["action"], deleted["target_name"], deleted["link"]) == (
            "Deleted language",
            "Tigrinya",
            None,
        )

    def test_reads_failures_and_upload_links_are_not_recorded(
        self, pair: Pair, owner: dict[str, str], db_path: Path
    ) -> None:
        client = pair[0]
        assert client.get(f"{A}/courses", headers=owner).status_code == 200
        assert (
            client.patch(f"{A}/courses/missing", json={"title": "x"}, headers=owner).status_code
            == 404
        )
        bad = {"code": "not a code", "name": "X", "native_name": "X"}
        assert client.post(f"{A}/languages", json=bad, headers=owner).status_code == 422
        assert client.post(f"{A}/audio/links", json={"url": "x"}, headers=owner).status_code != 500

        assert _rows(db_path) == 0

    def test_a_refused_admin_is_not_recorded(
        self, pair: Pair, owner: dict[str, str], db_path: Path
    ) -> None:
        add_member(db_path, HELPER, COURSE_ADMIN, [EN_AM_COURSE_ID])
        helper = _sign_in(pair, HELPER)

        body = {"code": "ti", "name": "Tigrinya", "native_name": "ትግርኛ"}
        assert pair[0].post(f"{A}/languages", json=body, headers=helper).status_code == 403

        assert _rows(db_path) == 0

    def test_a_course_admins_change_is_recorded_under_their_role(
        self, pair: Pair, owner: dict[str, str], db_path: Path
    ) -> None:
        add_member(db_path, HELPER, COURSE_ADMIN, [EN_AM_COURSE_ID])
        helper = _sign_in(pair, HELPER)

        response = pair[0].post(
            f"{A}/courses/{EN_AM_COURSE_ID}/sections", json={"title": "Greetings"}, headers=helper
        )
        assert response.status_code == 201, response.text

        (entry,) = _log(pair, owner)["items"]
        assert (entry["admin_email"], entry["admin_role"]) == (HELPER, "course_admin")
        assert (entry["action"], entry["course_id"]) == ("Added section", EN_AM_COURSE_ID)

    def test_the_change_still_succeeds_if_the_entry_cant_be_written(
        self, pair: Pair, owner: dict[str, str], monkeypatch: pytest.MonkeyPatch
    ) -> None:
        async def broken(self: object, entry: object) -> None:
            raise RuntimeError("disk full")

        monkeypatch.setattr(SqlAlchemyActivityRepository, "add", broken)

        response = pair[0].patch(
            f"{A}/courses/{EN_AM_COURSE_ID}", json={"title": "Still saved"}, headers=owner
        )

        assert response.status_code == 200
        courses = pair[0].get(f"{A}/courses", headers=owner).json()["courses"]
        assert courses[0]["title"] == "Still saved"


class TestReading:
    def _make_entries(self, pair: Pair, owner: dict[str, str], db_path: Path) -> None:
        for title in ("One", "Two", "Three"):
            pair[0].patch(f"{A}/courses/{EN_AM_COURSE_ID}", json={"title": title}, headers=owner)
        body = {"code": "ti", "name": "Tigrinya", "native_name": "ትግርኛ"}
        pair[0].post(f"{A}/languages", json=body, headers=owner)

    def test_filters_and_facets(self, pair: Pair, owner: dict[str, str], db_path: Path) -> None:
        self._make_entries(pair, owner, db_path)

        everything = _log(pair, owner)
        assert everything["total"] == 4
        assert everything["admins"] == [OWNER]
        assert everything["areas"] == ["curriculum", "languages"]
        assert everything["courses"] == [{"id": EN_AM_COURSE_ID, "title": "Three"}]
        assert _log(pair, owner, area="languages")["total"] == 1
        assert _log(pair, owner, course_id=EN_AM_COURSE_ID)["total"] == 3
        assert _log(pair, owner, search="tigr")["total"] == 1
        assert _log(pair, owner, admin="nobody@example.com")["total"] == 0
        today = datetime.now(UTC).date()
        assert _log(pair, owner, since=today.isoformat(), until=today.isoformat())["total"] == 4
        assert _log(pair, owner, until=(today - timedelta(days=1)).isoformat())["total"] == 0

    def test_pages_follow_the_cursor(
        self, pair: Pair, owner: dict[str, str], db_path: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        self._make_entries(pair, owner, db_path)
        monkeypatch.setattr(activity_use_cases, "PAGE_SIZE", 3)

        first = _log(pair, owner)
        second = _log(pair, owner, cursor=first["next_cursor"])

        assert len(first["items"]) == 3 and first["next_cursor"]
        assert len(second["items"]) == 1 and second["next_cursor"] is None
        ids = [e["id"] for e in first["items"] + second["items"]]
        assert len(set(ids)) == 4
        assert first["items"][0]["action"] == "Added language"

    @pytest.mark.parametrize(
        ("params", "field"),
        [
            ({"cursor": "nonsense"}, "cursor"),
            ({"since": "13/10"}, "since"),
            ({"area": "x"}, "area"),
        ],
    )
    def test_bad_filters_are_invalid_content(
        self, pair: Pair, owner: dict[str, str], params: dict[str, str], field: str
    ) -> None:
        response = pair[0].get(f"{A}/activity", headers=owner, params=params)

        assert response.status_code == 422
        assert response.json()["details"] == {"field": field}


def _league_member(db_path: Path, user_email: str, xp: int) -> str:
    """Puts the learner signed in as `user_email` in this week's league
    with `xp` from one practice session; returns the membership id."""
    now = datetime.now(UTC).isoformat()
    week = week_start(datetime.now(UTC)).date().isoformat()
    with sqlite3.connect(db_path) as conn:
        (user_id,) = conn.execute("SELECT id FROM users WHERE email = ?", (user_email,)).fetchone()
        group = conn.execute(
            "SELECT id FROM league_groups WHERE week_start = ?", (week,)
        ).fetchone()
        if group is None:
            conn.execute(
                "INSERT INTO league_groups (id, week_start, tier, created_at)"
                " VALUES ('g1', ?, 'green_bean', ?)",
                (week, now),
            )
        member_id = f"m-{user_id}"
        conn.execute(
            "INSERT INTO league_members (id, group_id, user_id, week_start, joined_at)"
            " VALUES (?, 'g1', ?, ?, ?)",
            (member_id, user_id, week, now),
        )
        conn.execute(
            "INSERT INTO practice_attempts (id, user_id, correct_count, total_count, xp_awarded,"
            " amole_awarded, completed_at, created_at) VALUES (?, ?, 1, 1, ?, 0, ?, ?)",
            (f"p-{user_id}", user_id, xp, now, now),
        )
    return member_id


class TestLeaguesApi:
    def test_the_week_and_a_removal_through_http(
        self, pair: Pair, owner: dict[str, str], db_path: Path
    ) -> None:
        _sign_in(pair, "abebe@example.com", "Abebe")
        _sign_in(pair, "sara@example.com", "Sara")
        cheat = _league_member(db_path, "abebe@example.com", 90)
        _league_member(db_path, "sara@example.com", 20)

        week = pair[0].get(f"{A}/leagues", headers=owner).json()
        (group,) = week["groups"]
        assert [(m["first_name"], m["email"], m["rank"]) for m in group["members"]] == [
            ("Abebe", "abebe@example.com", 1),
            ("Sara", "sara@example.com", 2),
        ]
        assert week["is_current"] and week["totals"]["xp"] == 110

        removed = pair[0].post(
            f"{A}/leagues/members/{cheat}/remove", json={"reason": "Bot XP"}, headers=owner
        )
        assert removed.status_code == 200, removed.text
        assert removed.json()["removed"] and removed.json()["rank"] is None

        (entry,) = _log(pair, owner, area="leagues")["items"]
        assert entry["action"] == "Removed learner from league"
        assert entry["target_name"] == "Abebe · abebe@example.com"
        assert entry["details"]["reason"] == "Bot XP"
        assert entry["link"] == f"/leagues?week={week['week_start']}"

    def test_errors(self, pair: Pair, owner: dict[str, str], db_path: Path) -> None:
        _sign_in(pair, "abebe@example.com", "Abebe")
        member = _league_member(db_path, "abebe@example.com", 90)
        client = pair[0]

        missing = client.post(
            f"{A}/leagues/members/x/remove", json={"reason": "Bot"}, headers=owner
        )
        no_reason = client.post(f"{A}/leagues/members/{member}/remove", json={}, headers=owner)
        bad_week = client.get(f"{A}/leagues", params={"week": "soon"}, headers=owner)

        assert (missing.status_code, missing.json()["error_code"]) == (
            404,
            "league_member_not_found",
        )
        assert (no_reason.status_code, no_reason.json()["details"]) == (422, {"field": "reason"})
        assert (bad_week.status_code, bad_week.json()["details"]) == (422, {"field": "week"})

    def test_adjusting_xp_through_http(
        self, pair: Pair, owner: dict[str, str], db_path: Path
    ) -> None:
        _sign_in(pair, "abebe@example.com", "Abebe")
        member = _league_member(db_path, "abebe@example.com", 90)

        response = pair[0].put(
            f"{A}/leagues/members/{member}/xp",
            json={"adjustment": -40, "reason": "Farmed"},
            headers=owner,
        )

        assert response.status_code == 200, response.text
        assert (response.json()["xp"], response.json()["earned_xp"]) == (50, 90)
        (entry,) = _log(pair, owner, area="leagues")["items"]
        assert entry["details"] == {
            "week": week_start(datetime.now(UTC)).date().isoformat(),
            "adjustment_before": 0,
            "adjustment": -40,
            "reason": "Farmed",
        }
