"""Integration tests for bolt `021-categories-service` (ADR-11): `GET
/skill-tree` returns categories, a brand-new user has one active skill per
category, completing a skill unlocks only the next skill in its own
category, and a locked skill's lesson stays unreachable (403) in a
non-first category.
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
from tests.fakes import FakeTokenVerifier

# (category id, title, subtitle, order) -- deliberately inserted out of order.
_CATEGORIES = [
    ("cat-family", "Family & People", "ቤተሰብ", 2),
    ("cat-found", "Foundations & Greetings", "ሰላምታ", 1),
]
# (skill id, category id, order_index) -- both categories start at order 1.
_SKILLS = [
    ("found-1", "cat-found", 1),
    ("found-2", "cat-found", 2),
    ("family-1", "cat-family", 1),
    ("family-2", "cat-family", 2),
]


@pytest.fixture
def seeded_categories(db_path: Path) -> None:
    engine = create_engine(f"sqlite:///{db_path}")
    with SyncSession(engine) as session:
        session.add_all(
            [CategoryModel(id=i, title=t, subtitle=s, order_index=o) for i, t, s, o in _CATEGORIES]
        )
        session.add_all(
            [
                SkillModel(id=sid, category_id=cid, title=sid, order_index=o)
                for sid, cid, o in _SKILLS
            ]
        )
        session.add_all(
            [
                LessonModel(id=f"{sid}-l1", skill_id=sid, title=sid, order_index=1)
                for sid, _, _ in _SKILLS
            ]
        )
        session.add_all(
            [
                ExerciseModel(
                    id=f"{sid}-e1",
                    lesson_id=f"{sid}-l1",
                    order_index=1,
                    type="multiple_choice",
                    prompt="Prompt",
                    content={"choices": [{"id": "a", "text": "ሰላም"}, {"id": "b", "text": "ደህና"}]},
                    answer_key={"correct_choice_id": "a"},
                )
                for sid, _, _ in _SKILLS
            ]
        )
        session.commit()
    engine.dispose()


def _sign_in(make_client: Any) -> tuple[Any, dict[str, str]]:
    client = make_client(FakeTokenVerifier(subject="google-user-1"), FakeTokenVerifier())
    response = client.post("/api/v1/auth/google", json={"id_token": "irrelevant"})
    assert response.status_code == 200
    return client, {"Authorization": f"Bearer {response.json()['session_token']}"}


def _complete_lesson(client: Any, headers: dict[str, str], lesson_id: str) -> None:
    response = client.post(
        f"/api/v1/lessons/{lesson_id}/complete",
        headers=headers,
        json={
            "attempt_id": f"attempt-{lesson_id}",
            "correct_count": 1,
            "total_count": 1,
            "time_spent_seconds": 10.0,
            "client_completed_at": datetime.now(UTC).isoformat(),
        },
    )
    assert response.status_code == 200, response.text


def _states(client: Any, headers: dict[str, str]) -> dict[str, str]:
    tree = client.get("/api/v1/skill-tree", headers=headers).json()
    return {s["id"]: s["state"] for s in tree["skills"]}


class TestSkillTreeCategories:
    def test_returns_categories_in_order_with_their_fields(
        self, make_client: Any, seeded_categories: None
    ) -> None:
        client, headers = _sign_in(make_client)

        tree = client.get("/api/v1/skill-tree", headers=headers).json()

        assert [c["id"] for c in tree["categories"]] == ["cat-found", "cat-family"]
        assert tree["categories"][1] == {
            "id": "cat-family",
            "title": "Family & People",
            "subtitle": "ቤተሰብ",
            "order_index": 2,
        }

    def test_every_skill_carries_its_category_id_and_is_grouped_by_category_order(
        self, make_client: Any, seeded_categories: None
    ) -> None:
        client, headers = _sign_in(make_client)

        tree = client.get("/api/v1/skill-tree", headers=headers).json()

        assert [(s["id"], s["category_id"]) for s in tree["skills"]] == [
            ("found-1", "cat-found"),
            ("found-2", "cat-found"),
            ("family-1", "cat-family"),
            ("family-2", "cat-family"),
        ]

    def test_deprecated_unit_fields_come_from_the_first_category(
        self, make_client: Any, seeded_categories: None
    ) -> None:
        client, headers = _sign_in(make_client)

        tree = client.get("/api/v1/skill-tree", headers=headers).json()

        assert tree["unit_title"] == "Foundations & Greetings"
        assert tree["unit_subtitle"] == "ሰላምታ"

    def test_existing_per_skill_fields_are_unchanged(
        self, make_client: Any, seeded_categories: None
    ) -> None:
        client, headers = _sign_in(make_client)

        skill = client.get("/api/v1/skill-tree", headers=headers).json()["skills"][0]

        for key in ("id", "title", "order_index", "state", "crown_level", "lesson_id"):
            assert key in skill
        assert skill["content_version"]


class TestPerCategoryProgression:
    def test_new_user_has_exactly_one_active_skill_per_category(
        self, make_client: Any, seeded_categories: None
    ) -> None:
        client, headers = _sign_in(make_client)

        assert _states(client, headers) == {
            "found-1": "active",
            "found-2": "locked",
            "family-1": "active",
            "family-2": "locked",
        }

    def test_completing_a_skill_unlocks_only_the_next_skill_in_its_own_category(
        self, make_client: Any, seeded_categories: None
    ) -> None:
        client, headers = _sign_in(make_client)

        _complete_lesson(client, headers, "family-1-l1")

        assert _states(client, headers) == {
            "found-1": "active",
            "found-2": "locked",
            "family-1": "completed",
            "family-2": "active",
        }

    def test_completing_the_last_skill_of_a_category_does_not_error_or_unlock_anything(
        self, make_client: Any, seeded_categories: None
    ) -> None:
        client, headers = _sign_in(make_client)
        _complete_lesson(client, headers, "family-1-l1")

        _complete_lesson(client, headers, "family-2-l1")

        assert _states(client, headers)["family-2"] == "completed"
        assert _states(client, headers)["found-2"] == "locked"

    def test_a_locked_skills_lesson_is_unreachable_in_a_non_first_category(
        self, make_client: Any, seeded_categories: None
    ) -> None:
        client, headers = _sign_in(make_client)

        response = client.get("/api/v1/lessons/family-2-l1", headers=headers)

        assert response.status_code == 403

    def test_the_first_skill_of_a_non_first_category_is_reachable(
        self, make_client: Any, seeded_categories: None
    ) -> None:
        client, headers = _sign_in(make_client)

        response = client.get("/api/v1/lessons/family-1-l1", headers=headers)

        assert response.status_code == 200
