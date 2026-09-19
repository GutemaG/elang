"""Integration tests for bolt 007's `skill-tree` amendment: each skill
entry's `lesson_id` (the lesson to navigate to when the node is tapped),
computed as the first lesson (by `order_index`) not yet completed this
cycle, falling back to the first lesson once the cycle is complete again.
"""

from __future__ import annotations

from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import Session as SyncSession

from app.infrastructure.db.lesson_models import (
    CategoryModel,
    ExerciseModel,
    LessonModel,
    SkillModel,
)
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
        session.add(
            SkillModel(category_id="cat-1", id="skill-a", title="Greetings & Basics", order_index=1)
        )
        session.add_all(
            [
                LessonModel(id="lesson-a1", skill_id="skill-a", title="Hello", order_index=1),
                LessonModel(id="lesson-a2", skill_id="skill-a", title="Goodbye", order_index=2),
            ]
        )
        session.add_all(
            [
                ExerciseModel(
                    id=f"ex-{lesson_id}",
                    lesson_id=lesson_id,
                    order_index=1,
                    type="multiple_choice",
                    prompt="Prompt",
                    content={"choices": [{"id": "a", "text": "ሰላም"}, {"id": "b", "text": "ደህና"}]},
                    answer_key={"correct_choice_id": "a"},
                )
                for lesson_id in ("lesson-a1", "lesson-a2")
            ]
        )
        session.commit()
    engine.dispose()
    return {"skill_a": "skill-a", "lesson_a1": "lesson-a1", "lesson_a2": "lesson-a2"}


def _sign_in(make_client: Any) -> tuple[Any, str]:
    client = make_client(FakeTokenVerifier(subject="google-user-1"), FakeTokenVerifier())
    response = client.post("/api/v1/auth/google", json={"id_token": "irrelevant"})
    assert response.status_code == 200
    return client, response.json()["session_token"]


def _auth(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def _lesson_id_for_skill_a(client: Any, token: str, skill_a: str) -> str | None:
    tree = client.get("/api/v1/skill-tree", headers=_auth(token)).json()
    entry = next(s for s in tree["skills"] if s["id"] == skill_a)
    return entry["lesson_id"]


class TestSkillTreeNextLessonId:
    def test_defaults_to_the_first_lesson_by_order_index(
        self, make_client: Any, seeded_content: dict[str, str]
    ) -> None:
        client, token = _sign_in(make_client)

        lesson_id = _lesson_id_for_skill_a(client, token, seeded_content["skill_a"])

        assert lesson_id == seeded_content["lesson_a1"]

    def test_advances_to_the_next_incomplete_lesson_after_completing_one(
        self, make_client: Any, seeded_content: dict[str, str]
    ) -> None:
        client, token = _sign_in(make_client)

        client.post(
            f"/api/v1/lessons/{seeded_content['lesson_a1']}/complete",
            headers=_auth(token),
            json={
                "attempt_id": "attempt-1",
                "correct_count": 1,
                "total_count": 1,
                "time_spent_seconds": 10.0,
                "client_completed_at": datetime.now(UTC).isoformat(),
            },
        )

        lesson_id = _lesson_id_for_skill_a(client, token, seeded_content["skill_a"])

        assert lesson_id == seeded_content["lesson_a2"]

    def test_resets_to_the_first_lesson_once_the_whole_cycle_completes(
        self, make_client: Any, seeded_content: dict[str, str]
    ) -> None:
        client, token = _sign_in(make_client)

        for i, lesson_id in enumerate((seeded_content["lesson_a1"], seeded_content["lesson_a2"])):
            client.post(
                f"/api/v1/lessons/{lesson_id}/complete",
                headers=_auth(token),
                json={
                    "attempt_id": f"attempt-{i}",
                    "correct_count": 1,
                    "total_count": 1,
                    "time_spent_seconds": 10.0,
                    "client_completed_at": datetime.now(UTC).isoformat(),
                },
            )

        next_lesson_id = _lesson_id_for_skill_a(client, token, seeded_content["skill_a"])

        # Cycle just completed and reset -- back to the first lesson,
        # ready for a replay pass (crown-level increment).
        assert next_lesson_id == seeded_content["lesson_a1"]
