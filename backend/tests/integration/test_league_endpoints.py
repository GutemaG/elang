"""Integration tests (023-weekly-leagues, bolt 073, stories 001-004):
`GET /api/v1/leagues/current`, joining through the lesson and practice
completion endpoints, and "Show me in leagues" through
`PATCH /api/v1/users/me/settings`, via `TestClient` against a temp-file
SQLite database.
"""

from __future__ import annotations

import json
import sqlite3
from collections.abc import Callable
from datetime import UTC, datetime, timedelta
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session as SyncSession

from app.domain.league import week_start
from app.infrastructure.db.lesson_models import (
    ExerciseModel,
    LessonModel,
    SkillModel,
    VocabItemModel,
)
from tests.fakes import EN_AM_COURSE_ID, FakeTokenVerifier

ClientFactory = Callable[[object, object], TestClient]


@pytest.fixture
def seeded_content(db_path: Path) -> dict[str, str]:
    """One skill with one four-question lesson, and one word to practise."""
    engine = create_engine(f"sqlite:///{db_path}")
    with SyncSession(engine) as session:
        session.add(SkillModel(category_id="cat-1", id="skill-a", title="Basics", order_index=1))
        session.add(LessonModel(id="lesson-a1", skill_id="skill-a", title="Hello", order_index=1))
        session.add(
            VocabItemModel(
                id="vocab-hello", course_id=EN_AM_COURSE_ID, word="ሰላም", translation="Hello"
            )
        )
        session.add_all(
            ExerciseModel(
                id=f"ex-a1-{i}",
                lesson_id="lesson-a1",
                order_index=i,
                type="multiple_choice",
                prompt=f"Prompt {i}",
                content={"choices": [{"id": "a", "text": "ሰላም"}, {"id": "b", "text": "ደህና"}]},
                answer_key={"correct_choice_id": "a"},
            )
            for i in range(1, 5)
        )
        session.commit()
    engine.dispose()
    return {"lesson_a1": "lesson-a1"}


def _sign_in(
    make_client: ClientFactory, subject: str, first_name: str | None = None
) -> tuple[TestClient, dict[str, str], str]:
    verifier = FakeTokenVerifier(
        subject=subject, email=f"{subject}@example.com", first_name=first_name
    )
    client = make_client(verifier, FakeTokenVerifier())
    body = client.post("/api/v1/auth/google", json={"id_token": "t"}).json()
    return client, {"Authorization": f"Bearer {body['session_token']}"}, body["user"]["id"]


def _practise(client: TestClient, headers: dict[str, str], session_id: str, sessions: int) -> None:
    """`sessions` practice sessions of one correct word: 5 XP each."""
    for n in range(sessions):
        response = client.post(
            "/api/v1/practice/complete",
            headers=headers,
            json={
                "session_id": f"{session_id}-{n}",
                "results": [{"vocab_item_id": "vocab-hello", "correct": True}],
                "time_spent_seconds": 5.0,
            },
        )
        assert response.status_code == 200, response.text


def _league(client: TestClient, headers: dict[str, str]) -> dict[str, object]:
    response = client.get("/api/v1/leagues/current", headers=headers)
    assert response.status_code == 200, response.text
    body: dict[str, object] = response.json()
    return body


class TestLeagueEndpoint:
    def test_sign_in_is_required(self, make_client: ClientFactory) -> None:
        client = make_client(FakeTokenVerifier(), FakeTokenVerifier())
        assert client.get("/api/v1/leagues/current").status_code == 401

    def test_before_any_xp_the_learner_is_not_in_the_league(
        self, make_client: ClientFactory
    ) -> None:
        client, headers, _ = _sign_in(make_client, "u1", "Abebe")

        body = _league(client, headers)

        assert body["status"] == "not_joined"
        assert body["tier"] == "green_bean"
        assert body["members"] == []
        assert body["rewards"] == [100, 60, 40]
        ends = datetime.fromisoformat(str(body["week_ends_at"]))
        assert ends == week_start(datetime.now(UTC)) + timedelta(days=7)

    def test_practice_joins_and_the_group_is_ranked(
        self, make_client: ClientFactory, seeded_content: dict[str, str]
    ) -> None:
        a, a_headers, _ = _sign_in(make_client, "u1", "Abebe")
        b, b_headers, _ = _sign_in(make_client, "u2")
        _practise(a, a_headers, "a-1", 1)
        _practise(b, b_headers, "b-1", 3)

        body = _league(a, a_headers)

        assert body["status"] == "joined"
        members = body["members"]
        assert isinstance(members, list)
        assert [(m["rank"], m["weekly_xp"], m["is_me"]) for m in members] == [
            (1, 15, False),
            (2, 5, True),
        ]
        assert members[1]["name"] == "Abebe"
        assert members[0]["name"].startswith("Learner ")
        assert all(0 <= m["avatar_colour"] < 8 for m in members)
        assert (body["promote_count"], body["demote_count"]) == (1, 0)

    def test_nothing_private_about_other_learners_is_sent(
        self, make_client: ClientFactory, seeded_content: dict[str, str]
    ) -> None:
        a, a_headers, a_id = _sign_in(make_client, "u1", "Abebe")
        b, b_headers, b_id = _sign_in(make_client, "u2", "Tigist")
        _practise(a, a_headers, "a-1", 1)
        _practise(b, b_headers, "b-1", 1)

        body = _league(a, a_headers)
        text = json.dumps(body)

        for member in body["members"]:  # type: ignore[attr-defined]
            assert set(member) == {"name", "initial", "avatar_colour", "weekly_xp", "rank", "is_me"}
        for private in (a_id, b_id, "u2@example.com", "u2", "u1@example.com"):
            assert private not in text


class TestJoiningThroughLessons:
    def test_an_offline_lesson_from_last_week_and_a_review_do_not_join(
        self, make_client: ClientFactory, seeded_content: dict[str, str], db_path: Path
    ) -> None:
        client, headers, user_id = _sign_in(make_client, "u1")
        last_week = week_start(datetime.now(UTC)) - timedelta(days=2)
        with sqlite3.connect(db_path) as conn:
            conn.execute(
                "UPDATE users SET created_at = ? WHERE id = ?",
                ((last_week - timedelta(days=1)).isoformat(), user_id),
            )

        def complete(attempt_id: str, at: datetime) -> int:
            response = client.post(
                f"/api/v1/lessons/{seeded_content['lesson_a1']}/complete",
                headers=headers,
                json={
                    "attempt_id": attempt_id,
                    "correct_count": 4,
                    "total_count": 4,
                    "time_spent_seconds": 30.0,
                    "client_completed_at": at.isoformat(),
                },
            )
            assert response.status_code == 200, response.text
            xp: int = response.json()["xp_earned"]
            return xp

        # Earned last week, synced now: XP, but not this week's league.
        assert complete("offline-1", last_week) == 20
        assert _league(client, headers)["status"] == "not_joined"
        # The skill is now complete, so replaying it is a review: no XP.
        assert complete("review-1", datetime.now(UTC)) == 0
        assert _league(client, headers)["status"] == "not_joined"

    def test_a_lesson_this_week_joins(
        self, make_client: ClientFactory, seeded_content: dict[str, str]
    ) -> None:
        client, headers, _ = _sign_in(make_client, "u1")
        response = client.post(
            f"/api/v1/lessons/{seeded_content['lesson_a1']}/complete",
            headers=headers,
            json={
                "attempt_id": "online-1",
                "correct_count": 4,
                "total_count": 4,
                "time_spent_seconds": 30.0,
                "client_completed_at": datetime.now(UTC).isoformat(),
            },
        )
        assert response.status_code == 200, response.text

        body = _league(client, headers)
        assert body["status"] == "joined"
        assert body["members"][0]["weekly_xp"] == 20  # type: ignore[index]


class TestShowInLeagues:
    def test_it_is_on_by_default_in_the_session_check(self, make_client: ClientFactory) -> None:
        client, headers, _ = _sign_in(make_client, "u1")
        body = client.get("/api/v1/auth/session", headers=headers).json()
        assert body["user"]["settings"]["show_in_leagues"] is True

    def test_switching_off_leaves_the_group_and_hides_the_league(
        self, make_client: ClientFactory, seeded_content: dict[str, str]
    ) -> None:
        a, a_headers, _ = _sign_in(make_client, "u1", "Abebe")
        b, b_headers, _ = _sign_in(make_client, "u2", "Tigist")
        _practise(a, a_headers, "a-1", 1)
        _practise(b, b_headers, "b-1", 1)

        response = b.patch(
            "/api/v1/users/me/settings", headers=b_headers, json={"show_in_leagues": False}
        )
        assert response.json()["settings"]["show_in_leagues"] is False

        assert _league(b, b_headers)["status"] == "hidden"
        names = [m["name"] for m in _league(a, a_headers)["members"]]  # type: ignore[attr-defined]
        assert names == ["Abebe"]
        # More practice while off doesn't bring them back.
        _practise(b, b_headers, "b-2", 1)
        assert _league(b, b_headers)["status"] == "hidden"

    def test_switching_back_on_rejoins_with_the_next_xp(
        self, make_client: ClientFactory, seeded_content: dict[str, str]
    ) -> None:
        client, headers, _ = _sign_in(make_client, "u1")
        client.patch("/api/v1/users/me/settings", headers=headers, json={"show_in_leagues": False})
        _practise(client, headers, "p-1", 1)
        client.patch("/api/v1/users/me/settings", headers=headers, json={"show_in_leagues": True})
        assert _league(client, headers)["status"] == "not_joined"

        _practise(client, headers, "p-2", 1)

        body = _league(client, headers)
        assert body["status"] == "joined"
        assert body["members"][0]["weekly_xp"] == 10  # type: ignore[index]

    def test_a_wrong_type_is_refused(self, make_client: ClientFactory) -> None:
        client, headers, _ = _sign_in(make_client, "u1")
        response = client.patch(
            "/api/v1/users/me/settings", headers=headers, json={"show_in_leagues": "no"}
        )
        assert response.status_code == 422
        assert response.json()["error_code"] == "invalid_setting"
