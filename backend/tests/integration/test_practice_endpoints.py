"""Integration tests for bolt 019 (008-srs-and-practice): `GET
/api/v1/practice/due-count`, `GET /api/v1/practice/due-items`, and
`complete_lesson`'s vocab-progress side effect (ADR-10's
`missed_exercise_ids`) -- via `TestClient` against a real temp-file SQLite
database, same discipline as `test_lesson_engagement_endpoints.py`.
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import Session as SyncSession

from app.infrastructure.db.lesson_models import (
    ExerciseModel,
    LessonModel,
    SkillModel,
    UserVocabProgressModel,
    VocabItemModel,
)
from tests.fakes import FakeTokenVerifier


@pytest.fixture
def seeded_content(db_path: Path) -> dict[str, str]:
    engine = create_engine(f"sqlite:///{db_path}")
    with SyncSession(engine) as session:
        session.add(
            SkillModel(category_id="cat-1", id="skill-a", title="Greetings & Basics", order_index=1)
        )
        session.add(
            LessonModel(id="lesson-a1", skill_id="skill-a", title="Hello & Goodbye", order_index=1)
        )
        session.add(VocabItemModel(id="vocab-hello", word="ሰላም", translation="Hello"))
        session.add_all(
            [
                ExerciseModel(
                    id="ex-a1-1",
                    lesson_id="lesson-a1",
                    order_index=1,
                    type="multiple_choice",
                    prompt="How do you say 'Hello'?",
                    content={"choices": [{"id": "a", "text": "ሰላም"}, {"id": "b", "text": "ደህና"}]},
                    answer_key={"correct_choice_id": "a"},
                    vocab_item_id="vocab-hello",
                ),
                *[
                    ExerciseModel(
                        id=f"ex-a1-{i}",
                        lesson_id="lesson-a1",
                        order_index=i,
                        type="multiple_choice",
                        prompt=f"Prompt {i}",
                        content={
                            "choices": [{"id": "a", "text": "ሰላም"}, {"id": "b", "text": "ደህና"}]
                        },
                        answer_key={"correct_choice_id": "a"},
                    )
                    for i in range(2, 5)
                ],
            ]
        )
        session.commit()
    engine.dispose()
    return {"lesson_a1": "lesson-a1", "vocab_hello": "vocab-hello"}


def _sign_in(make_client: Any) -> tuple[Any, str, str]:
    client = make_client(FakeTokenVerifier(subject="google-user-1"), FakeTokenVerifier())
    response = client.post("/api/v1/auth/google", json={"id_token": "irrelevant-fake-token"})
    assert response.status_code == 200
    body = response.json()
    return client, body["session_token"], body["user"]["id"]


def _auth(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def _now_iso() -> str:
    return datetime.now(UTC).isoformat()


def _complete_lesson(
    client: Any, token: str, lesson_id: str, attempt_id: str, missed_exercise_ids: list[str]
) -> Any:
    return client.post(
        f"/api/v1/lessons/{lesson_id}/complete",
        headers=_auth(token),
        json={
            "attempt_id": attempt_id,
            "correct_count": 4,
            "total_count": 4,
            "time_spent_seconds": 30.0,
            "client_completed_at": _now_iso(),
            "missed_exercise_ids": missed_exercise_ids,
        },
    )


class TestDueCountEndpoint:
    def test_zero_for_a_brand_new_user(
        self, make_client: Any, seeded_content: dict[str, str]
    ) -> None:
        client, token, _ = _sign_in(make_client)

        response = client.get("/api/v1/practice/due-count", headers=_auth(token))

        assert response.status_code == 200
        assert response.json()["due_count"] == 0

    def test_requires_authentication(
        self, make_client: Any, seeded_content: dict[str, str]
    ) -> None:
        client = make_client(FakeTokenVerifier(subject="u1"), FakeTokenVerifier())

        response = client.get("/api/v1/practice/due-count")

        assert response.status_code == 401

    def test_reflects_a_due_vocab_item_after_lesson_completion(
        self, make_client: Any, seeded_content: dict[str, str], db_path: Path
    ) -> None:
        client, token, user_id = _sign_in(make_client)

        _complete_lesson(client, token, seeded_content["lesson_a1"], "attempt-1", [])

        # First appearance's next_review_at is 1 day out -- not due yet.
        response = client.get("/api/v1/practice/due-count", headers=_auth(token))
        assert response.json()["due_count"] == 0

        # Force it due by backdating next_review_at directly.
        engine = create_engine(f"sqlite:///{db_path}")
        with SyncSession(engine) as session:
            row = session.get(UserVocabProgressModel, (user_id, seeded_content["vocab_hello"]))
            row.next_review_at = datetime.now(UTC) - timedelta(hours=1)
            session.commit()
        engine.dispose()

        response = client.get("/api/v1/practice/due-count", headers=_auth(token))
        assert response.json()["due_count"] == 1


class TestDueItemsEndpoint:
    def test_returns_the_due_item_resolved_to_word_translation_and_exercise(
        self, make_client: Any, seeded_content: dict[str, str], db_path: Path
    ) -> None:
        client, token, user_id = _sign_in(make_client)
        _complete_lesson(client, token, seeded_content["lesson_a1"], "attempt-1", [])
        engine = create_engine(f"sqlite:///{db_path}")
        with SyncSession(engine) as session:
            row = session.get(UserVocabProgressModel, (user_id, seeded_content["vocab_hello"]))
            row.next_review_at = datetime.now(UTC) - timedelta(hours=1)
            session.commit()
        engine.dispose()

        response = client.get("/api/v1/practice/due-items", headers=_auth(token))

        assert response.status_code == 200
        items = response.json()["items"]
        assert len(items) == 1
        assert items[0]["vocab_item_id"] == "vocab-hello"
        assert items[0]["word"] == "ሰላም"
        assert items[0]["translation"] == "Hello"
        assert items[0]["exercise"]["id"] == "ex-a1-1"
        assert items[0]["exercise"]["type"] == "multiple_choice"

    def test_empty_list_for_a_brand_new_user(
        self, make_client: Any, seeded_content: dict[str, str]
    ) -> None:
        client, token, _ = _sign_in(make_client)

        response = client.get("/api/v1/practice/due-items", headers=_auth(token))

        assert response.status_code == 200
        assert response.json()["items"] == []

    def test_a_due_item_on_a_locked_skills_lesson_still_appears(
        self, make_client: Any, db_path: Path
    ) -> None:
        # Plan-stage finding: `GET /lessons/{lesson_id}` runs
        # `LessonAccessPolicy` and 403s for a locked skill, so due-items
        # must never route through it -- a due item whose lesson sits on a
        # still-locked skill (story 002's explicit edge case) must appear
        # in Practice regardless.
        engine = create_engine(f"sqlite:///{db_path}")
        with SyncSession(engine) as session:
            session.add_all(
                [
                    SkillModel(
                        category_id="cat-1", id="skill-a", title="Greetings & Basics", order_index=1
                    ),
                    SkillModel(
                        category_id="cat-1", id="skill-b", title="Food & Drink", order_index=2
                    ),
                ]
            )
            session.add(
                LessonModel(id="lesson-b1", skill_id="skill-b", title="Coffee & Tea", order_index=1)
            )
            session.add(VocabItemModel(id="vocab-coffee", word="ቡና", translation="Coffee"))
            session.add(
                ExerciseModel(
                    id="ex-b1-1",
                    lesson_id="lesson-b1",
                    order_index=1,
                    type="multiple_choice",
                    prompt="How do you say 'Coffee'?",
                    content={"choices": [{"id": "a", "text": "ቡና"}, {"id": "b", "text": "ሻይ"}]},
                    answer_key={"correct_choice_id": "a"},
                    vocab_item_id="vocab-coffee",
                )
            )
            session.commit()
        engine.dispose()

        client, token, user_id = _sign_in(make_client)

        # skill-b is locked for a brand-new user -- confirmed the same way
        # `test_locked_skills_lesson_is_unreachable_by_direct_id` does.
        locked_response = client.get("/api/v1/lessons/lesson-b1", headers=_auth(token))
        assert locked_response.status_code == 403
        assert locked_response.json()["error_code"] == "skill_locked"

        engine = create_engine(f"sqlite:///{db_path}")
        with SyncSession(engine) as session:
            session.add(
                UserVocabProgressModel(
                    user_id=user_id,
                    vocab_item_id="vocab-coffee",
                    box_level=1,
                    next_review_at=datetime.now(UTC) - timedelta(hours=1),
                    last_seen_at=datetime.now(UTC) - timedelta(days=1),
                )
            )
            session.commit()
        engine.dispose()

        response = client.get("/api/v1/practice/due-items", headers=_auth(token))

        assert response.status_code == 200
        items = response.json()["items"]
        assert len(items) == 1
        assert items[0]["vocab_item_id"] == "vocab-coffee"
        assert items[0]["exercise"]["id"] == "ex-b1-1"


class TestCompleteLessonVocabProgress:
    def test_first_completion_creates_a_box_1_row(
        self, make_client: Any, seeded_content: dict[str, str]
    ) -> None:
        client, token, _ = _sign_in(make_client)

        response = _complete_lesson(client, token, seeded_content["lesson_a1"], "attempt-1", [])

        assert response.status_code == 200
        due_count = client.get("/api/v1/practice/due-count", headers=_auth(token)).json()
        assert due_count["due_count"] == 0  # box 1's 1-day interval hasn't elapsed

    def test_missed_exercise_id_resets_an_existing_rows_box_on_a_later_completion(
        self, make_client: Any, seeded_content: dict[str, str], db_path: Path
    ) -> None:
        client, token, user_id = _sign_in(make_client)
        _complete_lesson(client, token, seeded_content["lesson_a1"], "attempt-1", [])
        # Advance the row to box 3 and make it due, simulating time passing.
        engine = create_engine(f"sqlite:///{db_path}")
        with SyncSession(engine) as session:
            row = session.get(UserVocabProgressModel, (user_id, seeded_content["vocab_hello"]))
            row.box_level = 3
            row.next_review_at = datetime.now(UTC) - timedelta(hours=1)
            session.commit()
        engine.dispose()

        _complete_lesson(client, token, seeded_content["lesson_a1"], "attempt-2", ["ex-a1-1"])

        engine = create_engine(f"sqlite:///{db_path}")
        with SyncSession(engine) as session:
            row = session.get(UserVocabProgressModel, (user_id, seeded_content["vocab_hello"]))
            assert row.box_level == 1
        engine.dispose()


class TestCompletePracticeSessionEndpoint:
    def test_success_awards_xp_amole_and_updates_vocab_progress(
        self, make_client: Any, seeded_content: dict[str, str], db_path: Path
    ) -> None:
        client, token, user_id = _sign_in(make_client)

        response = client.post(
            "/api/v1/practice/complete",
            headers=_auth(token),
            json={
                "session_id": "practice-session-1",
                "results": [
                    {"vocab_item_id": seeded_content["vocab_hello"], "correct": True},
                ],
                "time_spent_seconds": 12.0,
            },
        )

        assert response.status_code == 200
        body = response.json()
        assert body["correct_count"] == 1
        assert body["total_count"] == 1
        assert body["xp_earned"] > 0
        assert body["amole_earned"] > 0

        engine = create_engine(f"sqlite:///{db_path}")
        with SyncSession(engine) as session:
            row = session.get(UserVocabProgressModel, (user_id, seeded_content["vocab_hello"]))
            assert row is not None
            assert row.box_level == 1  # first appearance
        engine.dispose()

    def test_is_idempotent_on_session_id(
        self, make_client: Any, seeded_content: dict[str, str]
    ) -> None:
        client, token, _ = _sign_in(make_client)
        payload = {
            "session_id": "practice-session-1",
            "results": [{"vocab_item_id": seeded_content["vocab_hello"], "correct": True}],
            "time_spent_seconds": 12.0,
        }

        first = client.post("/api/v1/practice/complete", headers=_auth(token), json=payload)
        second = client.post("/api/v1/practice/complete", headers=_auth(token), json=payload)

        assert first.json() == second.json()

    def test_empty_results_list_is_rejected(
        self, make_client: Any, seeded_content: dict[str, str]
    ) -> None:
        client, token, _ = _sign_in(make_client)

        response = client.post(
            "/api/v1/practice/complete",
            headers=_auth(token),
            json={"session_id": "practice-session-1", "results": [], "time_spent_seconds": 1.0},
        )

        assert response.status_code == 422
        assert response.json()["error_code"] == "invalid_practice_completion"

    def test_requires_authentication(
        self, make_client: Any, seeded_content: dict[str, str]
    ) -> None:
        client = make_client(FakeTokenVerifier(subject="u1"), FakeTokenVerifier())

        response = client.post(
            "/api/v1/practice/complete",
            json={
                "session_id": "practice-session-1",
                "results": [{"vocab_item_id": "vocab-hello", "correct": True}],
                "time_spent_seconds": 1.0,
            },
        )

        assert response.status_code == 401

    def test_does_not_advance_the_daily_streak_or_skill_progress(
        self, make_client: Any, seeded_content: dict[str, str]
    ) -> None:
        client, token, _ = _sign_in(make_client)
        before = client.get("/api/v1/skill-tree", headers=_auth(token)).json()

        client.post(
            "/api/v1/practice/complete",
            headers=_auth(token),
            json={
                "session_id": "practice-session-1",
                "results": [{"vocab_item_id": seeded_content["vocab_hello"], "correct": True}],
                "time_spent_seconds": 12.0,
            },
        )

        after = client.get("/api/v1/skill-tree", headers=_auth(token)).json()
        assert after["streak_count"] == before["streak_count"]
        assert [s["crown_level"] for s in after["skills"]] == [
            s["crown_level"] for s in before["skills"]
        ]
        assert [s["state"] for s in after["skills"]] == [s["state"] for s in before["skills"]]
