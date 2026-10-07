"""Integration tests: `DELETE /api/v1/users/me`, the in-app account deletion
both app stores require of an app with sign-in, via `TestClient` against a
temp-file SQLite database.
"""

from __future__ import annotations

import sqlite3
from collections.abc import Callable
from pathlib import Path

from fastapi.testclient import TestClient

from tests.fakes import FakeTokenVerifier

ClientFactory = Callable[[object, object], TestClient]

ACCOUNT_TABLES = (
    "auth_sessions",
    "lesson_attempts",
    "practice_attempts",
    "user_vocab_progress",
    "user_skill_progress",
    "user_streaks",
    "user_beans",
    "amole_transactions",
    "league_members",
    "feedback",
)


def _signed_in(make_client: ClientFactory, subject: str) -> tuple[TestClient, dict[str, str], str]:
    client = make_client(FakeTokenVerifier(subject=subject), FakeTokenVerifier())
    body = client.post(
        "/api/v1/auth/google",
        json={
            "id_token": "whatever",
            "pending_selection": {"language": "am", "daily_goal_minutes": 10},
        },
    ).json()
    return client, {"Authorization": f"Bearer {body['session_token']}"}, body["user"]["id"]


def _rows_for(db_path: Path, user_id: str) -> dict[str, int]:
    with sqlite3.connect(db_path) as conn:
        counts = {
            table: conn.execute(
                f"SELECT count(*) FROM {table} WHERE user_id = ?",  # noqa: S608
                (user_id,),
            ).fetchone()[0]
            for table in ACCOUNT_TABLES
        }
        counts["users"] = conn.execute(
            "SELECT count(*) FROM users WHERE id = ?", (user_id,)
        ).fetchone()[0]
    return counts


class TestDeletingAnAccount:
    def test_removes_the_account_and_everything_stored_for_it(
        self, make_client: ClientFactory, db_path: Path
    ) -> None:
        client, headers, user_id = _signed_in(make_client, f"{__name__}-leaving")
        client.post(
            "/api/v1/feedback", json={"category": "bug", "message": "It froze"}, headers=headers
        )
        client.get("/api/v1/beans", headers=headers)
        assert _rows_for(db_path, user_id)["feedback"] == 1

        response = client.delete("/api/v1/users/me", headers=headers)

        assert response.status_code == 204
        assert set(_rows_for(db_path, user_id).values()) == {0}

    def test_the_old_session_stops_working(self, make_client: ClientFactory) -> None:
        client, headers, _ = _signed_in(make_client, f"{__name__}-signed-out")

        client.delete("/api/v1/users/me", headers=headers)

        assert client.get("/api/v1/auth/session", headers=headers).json()["valid"] is False
        assert client.delete("/api/v1/users/me", headers=headers).status_code == 401

    def test_other_accounts_are_left_alone(self, make_client: ClientFactory, db_path: Path) -> None:
        leaving, leaving_headers, _ = _signed_in(make_client, f"{__name__}-a")
        staying, staying_headers, staying_id = _signed_in(make_client, f"{__name__}-b")

        leaving.delete("/api/v1/users/me", headers=leaving_headers)

        assert _rows_for(db_path, staying_id)["users"] == 1
        assert staying.get("/api/v1/auth/session", headers=staying_headers).json()["valid"]

    def test_signing_in_again_makes_a_new_empty_account(self, make_client: ClientFactory) -> None:
        client, headers, old_id = _signed_in(make_client, f"{__name__}-back")
        client.delete("/api/v1/users/me", headers=headers)

        _, _, new_id = _signed_in(make_client, f"{__name__}-back")

        assert new_id != old_id


class TestPublicPages:
    def test_privacy_terms_and_deletion_pages_need_no_sign_in(self) -> None:
        from app.main import create_app

        client = TestClient(create_app())
        for path, heading in [
            ("/privacy", "Privacy policy"),
            ("/terms", "Terms of use"),
            ("/delete-account", "Delete your account"),
        ]:
            response = client.get(path)
            assert response.status_code == 200
            assert response.headers["content-type"].startswith("text/html")
            assert f"<h1>{heading}</h1>" in response.text
            assert "birhanu.gudisa.tolosa@gmail.com" in response.text
