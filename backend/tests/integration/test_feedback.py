"""Integration tests: learner feedback (027-learner-feedback), sent from the
app and read and resolved on the admin site, over HTTP against a temp
SQLite database. Two clients share it: Abebe, a learner, and the admin.
"""

from __future__ import annotations

from collections.abc import Callable
from datetime import UTC, datetime, timedelta

import pytest
from fastapi.testclient import TestClient

from app.config import Settings
from app.infrastructure.api import dependencies, feedback_routers
from tests.fakes import EN_AM_COURSE_ID, FakeTokenVerifier

ClientFactory = Callable[[object, object], TestClient]
ADMIN = "admin@example.com"
SEND = "/api/v1/feedback"
ADMIN_FEEDBACK = "/api/v1/admin/feedback"
NOW = datetime(2026, 10, 2, 12, 0, tzinfo=UTC)


class Clock:
    def __init__(self) -> None:
        self.now = NOW

    def __call__(self) -> datetime:
        return self.now


@pytest.fixture
def clock() -> Clock:
    return Clock()


@pytest.fixture
def make(
    make_client: ClientFactory, monkeypatch: pytest.MonkeyPatch, clock: Clock
) -> Callable[[str, str], tuple[TestClient, dict[str, str]]]:
    monkeypatch.setattr(dependencies, "get_settings", lambda: Settings(admin_emails=ADMIN))

    def _make(subject: str, email: str) -> tuple[TestClient, dict[str, str]]:
        client = make_client(FakeTokenVerifier(subject=subject, email=email), FakeTokenVerifier())
        client.app.dependency_overrides[feedback_routers.get_now] = clock  # type: ignore[attr-defined]
        token = client.post("/api/v1/auth/google", json={"id_token": "t"}).json()["session_token"]
        return client, {"Authorization": f"Bearer {token}"}

    return _make


@pytest.fixture
def abebe(make: Callable[[str, str], tuple[TestClient, dict[str, str]]]):
    return make("sub-abebe", "abebe@example.com")


@pytest.fixture
def admin(make: Callable[[str, str], tuple[TestClient, dict[str, str]]]):
    return make("sub-admin", ADMIN)


def _send(learner: tuple[TestClient, dict[str, str]], **body: object):
    client, h = learner
    return client.post(SEND, json={"category": "bug", "message": "It froze", **body}, headers=h)


class TestSending:
    def test_a_learner_sends_feedback_with_their_course(self, abebe, admin) -> None:
        response = _send(abebe, message="  The audio cuts off  ", rating=4, platform="Android")

        assert response.status_code == 201
        assert response.json()["created_at"].startswith("2026-10-02T12:00")
        client, h = admin
        item = client.get(ADMIN_FEEDBACK, headers=h).json()["items"][0]
        assert item["message"] == "The audio cuts off"
        assert (item["category"], item["rating"], item["platform"]) == ("bug", 4, "android")
        assert item["status"] == "open"
        assert item["learner_email"] == "abebe@example.com"
        assert item["course_id"] == EN_AM_COURSE_ID
        assert item["course_title"]

    @pytest.mark.parametrize(
        "body",
        [
            {"message": "   "},
            {"message": "x" * 2001},
            {"category": "rant"},
            {"rating": 0},
            {"rating": 6},
        ],
    )
    def test_refuses_what_it_cannot_use(self, abebe, body: dict) -> None:
        response = _send(abebe, **body)

        assert response.status_code == 422
        assert response.json()["error_code"] == "invalid_feedback"

    def test_keeps_an_odd_platform_out(self, abebe, admin) -> None:
        _send(abebe, platform="<script>")

        client, h = admin
        assert client.get(ADMIN_FEEDBACK, headers=h).json()["items"][0]["platform"] is None

    def test_takes_twenty_a_day(self, abebe, clock: Clock) -> None:
        for _ in range(20):
            assert _send(abebe).status_code == 201

        response = _send(abebe)
        assert response.status_code == 429
        assert response.json()["error_code"] == "too_much_feedback"

        clock.now = NOW + timedelta(days=1, minutes=1)
        assert _send(abebe).status_code == 201

    def test_needs_a_session(self, make_client: ClientFactory) -> None:
        client = make_client(FakeTokenVerifier(), FakeTokenVerifier())

        assert client.post(SEND, json={"category": "bug", "message": "hi"}).status_code == 401


class TestAdminList:
    def test_lists_newest_first_with_counts(self, abebe, admin, clock: Clock) -> None:
        _send(abebe, category="idea", message="Add Tigrinya", rating=5)
        clock.now = NOW + timedelta(hours=1)
        _send(abebe, category="content", message="Wrong translation", rating=2)
        clock.now = NOW + timedelta(hours=2)
        _send(abebe, category="bug", message="Crash on start")
        client, h = admin

        body = client.get(ADMIN_FEEDBACK, headers=h).json()

        assert [i["message"] for i in body["items"]] == [
            "Crash on start",
            "Wrong translation",
            "Add Tigrinya",
        ]
        assert (body["total"], body["open"], body["resolved"]) == (3, 3, 0)
        assert (body["rated"], body["average_rating"]) == (2, 3.5)
        assert body["open_by_category"] == {"bug": 1, "idea": 1, "content": 1, "other": 0}

    def test_filters_searches_and_pages(self, abebe, admin) -> None:
        _send(abebe, category="idea", message="Add Tigrinya")
        _send(abebe, category="bug", message="Crash on start")
        _send(abebe, category="bug", message="Crash in practice")
        client, h = admin

        def messages(**params: object) -> list[str]:
            response = client.get(ADMIN_FEEDBACK, params=params, headers=h)
            assert response.status_code == 200
            return sorted(i["message"] for i in response.json()["items"])

        assert messages(category="idea") == ["Add Tigrinya"]
        assert messages(search="crash") == ["Crash in practice", "Crash on start"]
        assert messages(search="abebe@") == ["Add Tigrinya", "Crash in practice", "Crash on start"]
        assert len(messages(limit=2)) == 2
        assert len(messages(limit=2, offset=2)) == 1
        assert client.get(ADMIN_FEEDBACK, params={"status": "done"}, headers=h).status_code == 422
        assert client.get(ADMIN_FEEDBACK, params={"limit": 0}, headers=h).status_code == 422

    def test_filters_by_learner(self, abebe, admin) -> None:
        _send(abebe, message="From Abebe")
        _send(admin, message="From the admin")
        client, h = admin
        abebe_id = client.get("/api/v1/admin/learners", params={"search": "abebe"}, headers=h)
        user_id = abebe_id.json()["learners"][0]["id"]

        items = client.get(ADMIN_FEEDBACK, params={"user_id": user_id}, headers=h).json()["items"]

        assert [i["message"] for i in items] == ["From Abebe"]

    def test_resolves_and_reopens(self, abebe, admin, clock: Clock) -> None:
        _send(abebe)
        client, h = admin
        item_id = client.get(ADMIN_FEEDBACK, headers=h).json()["items"][0]["id"]
        clock.now = NOW + timedelta(hours=3)

        assert (
            client.patch(
                f"{ADMIN_FEEDBACK}/{item_id}", json={"status": "resolved"}, headers=h
            ).status_code
            == 204
        )
        body = client.get(ADMIN_FEEDBACK, params={"status": "resolved"}, headers=h).json()
        assert body["items"][0]["resolved_at"].startswith("2026-10-02T15:00")
        assert (body["open"], body["resolved"]) == (0, 1)
        assert (
            client.get(ADMIN_FEEDBACK, params={"status": "open"}, headers=h).json()["items"] == []
        )

        client.patch(f"{ADMIN_FEEDBACK}/{item_id}", json={"status": "open"}, headers=h)
        item = client.get(ADMIN_FEEDBACK, headers=h).json()["items"][0]
        assert (item["status"], item["resolved_at"]) == ("open", None)

    def test_unknown_feedback_is_404(self, admin) -> None:
        client, h = admin

        response = client.patch(f"{ADMIN_FEEDBACK}/nope", json={"status": "resolved"}, headers=h)

        assert response.status_code == 404
        assert response.json()["error_code"] == "content_not_found"

    def test_only_admins_read_feedback(self, abebe) -> None:
        client, h = abebe

        assert client.get(ADMIN_FEEDBACK, headers=h).status_code == 403
        assert (
            client.patch(f"{ADMIN_FEEDBACK}/x", json={"status": "open"}, headers=h).status_code
            == 403
        )
