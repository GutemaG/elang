"""Integration tests for `GET /api/v1/skill-tree` and
`GET /api/v1/lessons/{lesson_id}`, via `TestClient` against a real temp-file
SQLite database -- covers story 001's acceptance criteria end-to-end,
including authentication (reusing `001-auth-service`'s real auth endpoint to
mint a session token, not a shortcut/fake auth mechanism).
"""

from __future__ import annotations

from pathlib import Path
from typing import Any

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import Session as SyncSession

from app.infrastructure.db.lesson_models import ExerciseModel, LessonModel, SkillModel
from tests.fakes import FakeTokenVerifier


@pytest.fixture
def seeded_content(db_path: Path) -> dict[str, str]:
    """Seeds 2 skills / 2 lessons / a mix of all 3 exercise types via a
    plain synchronous engine -- run entirely before the async engines used
    by `db_session`/`app_engine` ever touch the file, avoiding any
    event-loop entanglement (same discipline `db_path` itself uses for
    schema creation).
    """
    engine = create_engine(f"sqlite:///{db_path}")
    with SyncSession(engine) as session:
        session.add_all(
            [
                SkillModel(id="skill-a", title="Greetings & Basics", order_index=1),
                SkillModel(id="skill-b", title="Food & Drink", order_index=2),
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
                    id="ex-mc",
                    lesson_id="lesson-a1",
                    order_index=1,
                    type="multiple_choice",
                    prompt="How do you say 'Hello'?",
                    content={
                        "choices": [
                            {"id": "a", "text": "ሰላም"},
                            {"id": "b", "text": "ደህና ሁን"},
                        ]
                    },
                    answer_key={"correct_choice_id": "a"},
                ),
                ExerciseModel(
                    id="ex-listening",
                    lesson_id="lesson-a1",
                    order_index=2,
                    type="listening",
                    prompt="What does this word mean?",
                    content={
                        "audio_url": "https://r2-placeholder.buna.dev/audio/hello.mp3",
                        "choices": [
                            {"id": "a", "text": "Hello"},
                            {"id": "b", "text": "Goodbye"},
                        ],
                    },
                    answer_key={"correct_choice_id": "a"},
                ),
                ExerciseModel(
                    id="ex-sentence",
                    lesson_id="lesson-a1",
                    order_index=3,
                    type="sentence_construction",
                    prompt="Translate: 'I am fine'",
                    content={
                        "word_bank": [
                            {"id": "w1", "text": "ደህና"},
                            {"id": "w2", "text": "ነኝ"},
                        ]
                    },
                    answer_key={"correct_sequence": ["w1", "w2"]},
                ),
                ExerciseModel(
                    id="ex-b1",
                    lesson_id="lesson-b1",
                    order_index=1,
                    type="multiple_choice",
                    prompt="How do you say 'Coffee'?",
                    content={
                        "choices": [
                            {"id": "a", "text": "ቡና"},
                            {"id": "b", "text": "ሻይ"},
                        ]
                    },
                    answer_key={"correct_choice_id": "a"},
                ),
            ]
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
    """Returns `(client, session_token)` via the real `/api/v1/auth/google`
    endpoint -- not a shortcut. Mirrors `test_auth_endpoints.py`'s pattern.
    """
    client = make_client(FakeTokenVerifier(subject="google-user-1"), FakeTokenVerifier())
    response = client.post("/api/v1/auth/google", json={"id_token": "irrelevant-fake-token"})
    assert response.status_code == 200
    return client, response.json()["session_token"]


class TestSkillTreeAuthentication:
    def test_missing_authorization_header_returns_401_missing_credentials(
        self, make_client: Any, seeded_content: dict[str, str]
    ) -> None:
        client = make_client(FakeTokenVerifier(subject="u1"), FakeTokenVerifier())

        response = client.get("/api/v1/skill-tree")

        assert response.status_code == 401
        assert response.json()["error_code"] == "missing_credentials"

    def test_unknown_session_token_returns_401_invalid_session(
        self, make_client: Any, seeded_content: dict[str, str]
    ) -> None:
        client = make_client(FakeTokenVerifier(subject="u1"), FakeTokenVerifier())

        response = client.get(
            "/api/v1/skill-tree", headers={"Authorization": "Bearer not-a-real-token"}
        )

        assert response.status_code == 401
        assert response.json()["error_code"] == "invalid_session"


class TestSkillTreeEndpoint:
    def test_new_user_sees_first_skill_active_and_rest_locked(
        self, make_client: Any, seeded_content: dict[str, str]
    ) -> None:
        client, token = _sign_in(make_client)

        response = client.get("/api/v1/skill-tree", headers={"Authorization": f"Bearer {token}"})

        assert response.status_code == 200
        body = response.json()
        skills = body["skills"]
        by_id = {s["id"]: s for s in skills}
        assert by_id[seeded_content["skill_a"]]["state"] == "active"
        assert by_id[seeded_content["skill_a"]]["crown_level"] == 0
        assert by_id[seeded_content["skill_b"]]["state"] == "locked"
        # bolt 005's extended fields -- HUD stats for a brand-new user.
        assert body["beans"] == body["beans_max"]
        assert body["streak_count"] == 0
        assert body["total_xp"] == 0
        assert body["unit_title"]


class TestLessonContentEndpoint:
    def test_returns_full_ordered_exercise_list_in_one_request(
        self, make_client: Any, seeded_content: dict[str, str]
    ) -> None:
        client, token = _sign_in(make_client)

        response = client.get(
            f"/api/v1/lessons/{seeded_content['lesson_a1']}",
            headers={"Authorization": f"Bearer {token}"},
        )

        assert response.status_code == 200
        body = response.json()
        assert body["lesson"]["id"] == seeded_content["lesson_a1"]
        exercises = body["exercises"]
        assert [e["type"] for e in exercises] == [
            "multiple_choice",
            "listening",
            "sentence_construction",
        ]
        # Real Amharic content served, UTF-8 intact.
        assert exercises[0]["choices"][0]["text"] == "ሰላም"
        assert exercises[1]["audio_url"] == "https://r2-placeholder.buna.dev/audio/hello.mp3"
        assert exercises[2]["word_bank"][0]["text"] == "ደህና"

    def test_includes_correct_answer_data_per_adr5(
        self, make_client: Any, seeded_content: dict[str, str]
    ) -> None:
        # ADR-5 (memory-bank/bolts/005-lesson-engagement-service/) supersedes
        # ADR-4's "never expose correct answers": grading moved client-side
        # to satisfy the "no network call per exercise" NFR, so the
        # lesson-content response now includes each exercise's correct
        # answer.
        client, token = _sign_in(make_client)

        response = client.get(
            f"/api/v1/lessons/{seeded_content['lesson_a1']}",
            headers={"Authorization": f"Bearer {token}"},
        )

        exercises = response.json()["exercises"]
        assert exercises[0]["correct_choice_id"] == "a"  # multiple_choice
        assert exercises[1]["correct_choice_id"] == "a"  # listening
        assert exercises[2]["correct_sequence"] == ["w1", "w2"]  # sentence_construction
        # The raw JSON column name itself is still never leaked -- only the
        # reconstructed `correct_choice_id`/`correct_sequence` fields are.
        assert "answer_key" not in response.text

    def test_locked_skills_lesson_is_unreachable_by_direct_id(
        self, make_client: Any, seeded_content: dict[str, str]
    ) -> None:
        client, token = _sign_in(make_client)

        response = client.get(
            f"/api/v1/lessons/{seeded_content['lesson_b1']}",
            headers={"Authorization": f"Bearer {token}"},
        )

        assert response.status_code == 403
        assert response.json()["error_code"] == "skill_locked"

    def test_unknown_lesson_id_returns_404(
        self, make_client: Any, seeded_content: dict[str, str]
    ) -> None:
        client, token = _sign_in(make_client)

        response = client.get(
            "/api/v1/lessons/does-not-exist",
            headers={"Authorization": f"Bearer {token}"},
        )

        assert response.status_code == 404
        assert response.json()["error_code"] == "lesson_not_found"

    def test_requires_authentication(
        self, make_client: Any, seeded_content: dict[str, str]
    ) -> None:
        client = make_client(FakeTokenVerifier(subject="u1"), FakeTokenVerifier())

        response = client.get(f"/api/v1/lessons/{seeded_content['lesson_a1']}")

        assert response.status_code == 401
        assert response.json()["error_code"] == "missing_credentials"
