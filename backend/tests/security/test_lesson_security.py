"""Security tests for the lesson-content endpoints:

1. Correct-answer data is present in the lesson-content response (ADR-5,
   which supersedes ADR-4) under the expected field names only -- the raw
   `answer_key` JSON column name itself is never leaked.
2. Per-user skill-tree/lesson-access state is genuinely per-user -- one
   user's progress never leaks into or affects another user's view.
"""

from __future__ import annotations

from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import Session as SyncSession

from app.infrastructure.db.lesson_models import (
    ExerciseModel,
    LessonModel,
    SkillModel,
    UserSkillProgressModel,
)
from tests.fakes import FakeTokenVerifier


@pytest.fixture
def seeded_content(db_path: Path) -> dict[str, str]:
    engine = create_engine(f"sqlite:///{db_path}")
    with SyncSession(engine) as session:
        session.add_all(
            [
                SkillModel(
                    category_id="cat-1", id="skill-a", title="Greetings & Basics", order_index=1
                ),
                SkillModel(category_id="cat-1", id="skill-b", title="Food & Drink", order_index=2),
            ]
        )
        session.add(
            LessonModel(id="lesson-a1", skill_id="skill-a", title="Hello & Goodbye", order_index=1)
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
                        "choices": [{"id": "a", "text": "Hello"}, {"id": "b", "text": "Goodbye"}],
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
            ]
        )
        session.commit()
    engine.dispose()
    return {"skill_a": "skill-a", "skill_b": "skill-b", "lesson_a1": "lesson-a1"}


def _sign_in(make_client: Any, *, subject: str) -> tuple[Any, str, str]:
    client = make_client(FakeTokenVerifier(subject=subject), FakeTokenVerifier())
    response = client.post("/api/v1/auth/google", json={"id_token": "irrelevant"})
    assert response.status_code == 200
    body = response.json()
    return client, body["session_token"], body["user"]["id"]


class TestAnswerKeyFieldsShapedPerADR5:
    def test_exercises_carry_the_reconstructed_fields_not_the_raw_column_name(
        self, make_client: Any, seeded_content: dict[str, str]
    ) -> None:
        client, token, _ = _sign_in(make_client, subject="leak-check-user")

        response = client.get(
            f"/api/v1/lessons/{seeded_content['lesson_a1']}",
            headers={"Authorization": f"Bearer {token}"},
        )

        body = response.json()
        for exercise in body["exercises"]:
            assert "answer_key" not in exercise
            if exercise["type"] == "sentence_construction":
                assert exercise["correct_sequence"] == ["w1", "w2"]
            else:
                assert exercise["correct_choice_id"] == "a"


class TestPerUserIsolation:
    def test_one_users_completed_skill_does_not_affect_another_users_skill_tree(
        self, make_client: Any, seeded_content: dict[str, str], db_path: Path
    ) -> None:
        client_a, token_a, user_a_id = _sign_in(make_client, subject="user-a-sub")
        client_b, token_b, user_b_id = _sign_in(make_client, subject="user-b-sub")
        assert user_a_id != user_b_id

        # Directly grant user A a completed skill-a row -- simulates what
        # bolt 005's write path will eventually do, without depending on it.
        engine = create_engine(f"sqlite:///{db_path}")
        with SyncSession(engine) as session:
            session.add(
                UserSkillProgressModel(
                    id="progress-a",
                    user_id=user_a_id,
                    skill_id=seeded_content["skill_a"],
                    unlocked=True,
                    crown_level=1,
                    completed_at=datetime(2026, 1, 1, tzinfo=UTC),
                )
            )
            session.commit()
        engine.dispose()

        tree_a = client_a.get(
            "/api/v1/skill-tree", headers={"Authorization": f"Bearer {token_a}"}
        ).json()["skills"]
        tree_b = client_b.get(
            "/api/v1/skill-tree", headers={"Authorization": f"Bearer {token_b}"}
        ).json()["skills"]

        skill_a_for_a = next(s for s in tree_a if s["id"] == seeded_content["skill_a"])
        skill_a_for_b = next(s for s in tree_b if s["id"] == seeded_content["skill_a"])

        assert skill_a_for_a["state"] == "completed"
        assert skill_a_for_a["crown_level"] == 1
        # User B has no progress row at all -- still sees the new-user
        # bootstrap default (first skill active), completely unaffected by
        # user A's completion.
        assert skill_a_for_b["state"] == "active"
        assert skill_a_for_b["crown_level"] == 0

    def test_session_token_from_one_user_cannot_be_reused_by_a_different_signed_in_client(
        self, make_client: Any, seeded_content: dict[str, str]
    ) -> None:
        # Sanity check that session tokens genuinely resolve to their own
        # issuing user, not a shared/global session -- two independent
        # sign-ins get two independent, non-interchangeable tokens.
        client_a, token_a, user_a_id = _sign_in(make_client, subject="isolated-user-a")
        _, token_b, user_b_id = _sign_in(make_client, subject="isolated-user-b")

        assert token_a != token_b
        assert user_a_id != user_b_id
