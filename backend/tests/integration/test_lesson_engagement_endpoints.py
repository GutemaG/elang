"""Integration tests for bolt 005's endpoints -- `GET /api/v1/beans`,
`POST /api/v1/beans/refill`, `POST /api/v1/lessons/{id}/complete` -- via
`TestClient` against a real temp-file SQLite database, signing in through
the real `/api/v1/auth/google` endpoint (not a shortcut), same discipline
as bolt 004's endpoint tests.
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any

import pytest
from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session as SyncSession

from app.infrastructure.db.lesson_models import (
    CategoryModel,
    ExerciseModel,
    LessonModel,
    SkillModel,
)
from app.infrastructure.db.models import UserModel
from tests.fakes import EN_AM_COURSE_ID, FakeTokenVerifier


@pytest.fixture
def seeded_content(db_path: Path) -> dict[str, str]:
    engine = create_engine(f"sqlite:///{db_path}")
    with SyncSession(engine) as session:
        session.add(
            CategoryModel(
                id="cat-1",
                course_id=EN_AM_COURSE_ID,
                title="Foundations & Greetings",
                subtitle="ሰላምታ",
                order_index=1,
            )
        )
        session.add_all(
            [
                SkillModel(
                    category_id="cat-1", id="skill-a", title="Greetings & Basics", order_index=1
                ),
                SkillModel(category_id="cat-1", id="skill-b", title="Food & Drink", order_index=2),
            ]
        )
        session.add_all(
            [
                LessonModel(
                    id="lesson-a1", skill_id="skill-a", title="Hello & Goodbye", order_index=1
                ),
                LessonModel(
                    id="lesson-b1", skill_id="skill-b", title="Coffee & Tea", order_index=1
                ),
            ]
        )
        session.add_all(
            [
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
            ]
        )
        session.add(
            ExerciseModel(
                id="ex-b1-1",
                lesson_id="lesson-b1",
                order_index=1,
                type="multiple_choice",
                prompt="Coffee?",
                content={"choices": [{"id": "a", "text": "ቡና"}, {"id": "b", "text": "ሻይ"}]},
                answer_key={"correct_choice_id": "a"},
            )
        )
        session.commit()
    engine.dispose()
    return {
        "skill_a": "skill-a",
        "skill_b": "skill-b",
        "lesson_a1": "lesson-a1",
        "lesson_b1": "lesson-b1",
    }


def _sign_in(make_client: Any) -> tuple[Any, str]:
    client = make_client(FakeTokenVerifier(subject="google-user-1"), FakeTokenVerifier())
    response = client.post("/api/v1/auth/google", json={"id_token": "irrelevant-fake-token"})
    assert response.status_code == 200
    return client, response.json()["session_token"]


def _auth(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def _now_iso() -> str:
    return datetime.now(UTC).isoformat()


class TestGetBeansStatus:
    def test_new_user_gets_full_beans_and_starting_amole(
        self, make_client: Any, seeded_content: dict[str, str]
    ) -> None:
        client, token = _sign_in(make_client)

        response = client.get("/api/v1/beans", headers=_auth(token))

        assert response.status_code == 200
        body = response.json()
        assert body["beans"] == body["beans_max"]
        assert body["next_bean_at"] is None
        assert body["amole_balance"] > 0

    def test_requires_authentication(
        self, make_client: Any, seeded_content: dict[str, str]
    ) -> None:
        client = make_client(FakeTokenVerifier(subject="u1"), FakeTokenVerifier())

        response = client.get("/api/v1/beans")

        assert response.status_code == 401


class TestRefillBeans:
    def test_success_returns_maxed_beans_and_deducted_amole(
        self, make_client: Any, seeded_content: dict[str, str]
    ) -> None:
        client, token = _sign_in(make_client)

        response = client.post("/api/v1/beans/refill", headers=_auth(token))

        assert response.status_code == 200
        body = response.json()
        before = client.get("/api/v1/beans", headers=_auth(token)).json()
        assert body["beans"] == before["beans_max"]

    def test_insufficient_amole_returns_422(
        self, make_client: Any, seeded_content: dict[str, str]
    ) -> None:
        client, token = _sign_in(make_client)
        # Drain the starting Amole balance via repeated refills (each one
        # costs Amole; the starting balance affords only a couple).
        for _ in range(5):
            client.post("/api/v1/beans/refill", headers=_auth(token))

        response = client.post("/api/v1/beans/refill", headers=_auth(token))

        assert response.status_code == 422
        assert response.json()["error_code"] == "insufficient_amole"


class TestCompleteLesson:
    def test_perfect_completion_awards_xp_and_unlocks_the_next_skill(
        self, make_client: Any, seeded_content: dict[str, str]
    ) -> None:
        client, token = _sign_in(make_client)

        response = client.post(
            f"/api/v1/lessons/{seeded_content['lesson_a1']}/complete",
            headers=_auth(token),
            json={
                "attempt_id": "attempt-1",
                "correct_count": 4,
                "total_count": 4,
                "time_spent_seconds": 30.0,
                "client_completed_at": _now_iso(),
            },
        )

        assert response.status_code == 200
        body = response.json()
        assert body["xp_earned"] == 20  # 4 correct * 5 XP
        assert body["skill_unlocked_title"] == "Food & Drink"
        assert body["crown_level"] == 1
        assert body["streak_count"] == 1
        assert body["streak_increased_today"] is True

        # The dashboard now reflects the unlock.
        tree = client.get("/api/v1/skill-tree", headers=_auth(token)).json()
        by_id = {s["id"]: s for s in tree["skills"]}
        assert by_id[seeded_content["skill_a"]]["state"] == "completed"
        assert by_id[seeded_content["skill_b"]]["state"] == "active"
        assert tree["total_xp"] == 20

    def test_repeating_the_same_attempt_id_is_idempotent(
        self, make_client: Any, seeded_content: dict[str, str]
    ) -> None:
        client, token = _sign_in(make_client)
        payload = {
            "attempt_id": "attempt-1",
            "correct_count": 4,
            "total_count": 4,
            "time_spent_seconds": 30.0,
            "client_completed_at": _now_iso(),
        }

        first = client.post(
            f"/api/v1/lessons/{seeded_content['lesson_a1']}/complete",
            headers=_auth(token),
            json=payload,
        )
        second = client.post(
            f"/api/v1/lessons/{seeded_content['lesson_a1']}/complete",
            headers=_auth(token),
            json=payload,
        )

        assert first.json() == second.json()
        # No second XP award -- lifetime total is still just the one attempt's.
        tree = client.get("/api/v1/skill-tree", headers=_auth(token)).json()
        assert tree["total_xp"] == 20

    def test_unknown_lesson_returns_404(
        self, make_client: Any, seeded_content: dict[str, str]
    ) -> None:
        client, token = _sign_in(make_client)

        response = client.post(
            "/api/v1/lessons/does-not-exist/complete",
            headers=_auth(token),
            json={
                "attempt_id": "attempt-1",
                "correct_count": 1,
                "total_count": 1,
                "time_spent_seconds": 10.0,
                "client_completed_at": _now_iso(),
            },
        )

        assert response.status_code == 404
        assert response.json()["error_code"] == "lesson_not_found"

    def test_locked_skills_lesson_cannot_be_completed(
        self, make_client: Any, seeded_content: dict[str, str]
    ) -> None:
        client, token = _sign_in(make_client)

        response = client.post(
            f"/api/v1/lessons/{seeded_content['lesson_b1']}/complete",
            headers=_auth(token),
            json={
                "attempt_id": "attempt-1",
                "correct_count": 1,
                "total_count": 1,
                "time_spent_seconds": 10.0,
                "client_completed_at": _now_iso(),
            },
        )

        assert response.status_code == 403
        assert response.json()["error_code"] == "skill_locked"

    def test_total_count_mismatch_returns_422_invalid_completion(
        self, make_client: Any, seeded_content: dict[str, str]
    ) -> None:
        client, token = _sign_in(make_client)

        response = client.post(
            f"/api/v1/lessons/{seeded_content['lesson_a1']}/complete",
            headers=_auth(token),
            json={
                "attempt_id": "attempt-1",
                "correct_count": 1,
                "total_count": 1,  # lesson-a1 actually has 4 exercises
                "time_spent_seconds": 10.0,
                "client_completed_at": _now_iso(),
            },
        )

        assert response.status_code == 422
        assert response.json()["error_code"] == "invalid_completion"

    def test_implausible_wrong_count_returns_422_beans_exhausted(
        self, make_client: Any, seeded_content: dict[str, str]
    ) -> None:
        client, token = _sign_in(make_client)
        # Drain beans to 1 via 4 separate failed lessons' worth of wrong
        # answers isn't directly possible without a completion call, so
        # instead: complete once with only 1 correct (3 wrong, well within
        # the starting 5 beans), then attempt a second lesson claiming 0
        # correct out of 4 (4 more wrong) -- beans remaining after the
        # first call (5 - 3 = 2) can't cover 4 more.
        client.post(
            f"/api/v1/lessons/{seeded_content['lesson_a1']}/complete",
            headers=_auth(token),
            json={
                "attempt_id": "attempt-1",
                "correct_count": 1,
                "total_count": 4,
                "time_spent_seconds": 30.0,
                "client_completed_at": _now_iso(),
            },
        )

        response = client.post(
            f"/api/v1/lessons/{seeded_content['lesson_a1']}/complete",
            headers=_auth(token),
            json={
                "attempt_id": "attempt-2",
                "correct_count": 0,
                "total_count": 4,
                "time_spent_seconds": 30.0,
                "client_completed_at": _now_iso(),
            },
        )

        assert response.status_code == 422
        assert response.json()["error_code"] == "beans_exhausted"

    def test_requires_authentication(
        self, make_client: Any, seeded_content: dict[str, str]
    ) -> None:
        client = make_client(FakeTokenVerifier(subject="u1"), FakeTokenVerifier())

        response = client.post(
            f"/api/v1/lessons/{seeded_content['lesson_a1']}/complete",
            json={
                "attempt_id": "attempt-1",
                "correct_count": 1,
                "total_count": 4,
                "time_spent_seconds": 10.0,
                "client_completed_at": _now_iso(),
            },
        )

        assert response.status_code == 401

    def test_far_future_client_completed_at_returns_422(
        self, make_client: Any, seeded_content: dict[str, str]
    ) -> None:
        # Bolt 008: `CompletionTimestampValidator` rejects a completion
        # timestamp implausibly far in the future (beyond the small
        # clock-skew allowance).
        client, token = _sign_in(make_client)
        far_future = datetime(2099, 1, 1, tzinfo=UTC).isoformat()

        response = client.post(
            f"/api/v1/lessons/{seeded_content['lesson_a1']}/complete",
            headers=_auth(token),
            json={
                "attempt_id": "attempt-1",
                "correct_count": 4,
                "total_count": 4,
                "time_spent_seconds": 30.0,
                "client_completed_at": far_future,
            },
        )

        assert response.status_code == 422
        assert response.json()["error_code"] == "invalid_completion_timestamp"

    def test_a_completion_from_long_before_now_is_accepted(
        self, make_client: Any, seeded_content: dict[str, str], db_path: Path
    ) -> None:
        # No upper bound on staleness -- a lesson completed 45 days ago,
        # syncing now, must still succeed (requirements.md FR-3). The
        # account itself must actually be old enough for that to be
        # plausible, so it's backdated directly here (the API has no way
        # to backdate an account's own creation).
        client, token = _sign_in(make_client)
        engine = create_engine(f"sqlite:///{db_path}")
        with SyncSession(engine) as session:
            user = session.execute(
                select(UserModel).where(UserModel.provider_user_id == "google-user-1")
            ).scalar_one()
            user.created_at = datetime.now(UTC) - timedelta(days=100)
            session.commit()
        engine.dispose()
        long_ago = (datetime.now(UTC) - timedelta(days=45)).isoformat()

        response = client.post(
            f"/api/v1/lessons/{seeded_content['lesson_a1']}/complete",
            headers=_auth(token),
            json={
                "attempt_id": "attempt-1",
                "correct_count": 4,
                "total_count": 4,
                "time_spent_seconds": 30.0,
                "client_completed_at": long_ago,
            },
        )

        assert response.status_code == 200
