"""Integration tests for bolt `024-courses-service` (ADR-12, ADR-13): the
course list, switching the active course, course-scoped skill tree, progress
and Practice, lessons gated by their own course, signup with a language pair,
and the `PATCH language` compatibility path -- via `TestClient` against a real
temp-file SQLite database.

Fixture courses (English to Amharic already exists in every test database):
  A  am from en  available    categories cat-a (skills a-1, a-2), vocab v-a
  B  om from am  available    categories cat-b (skills b-1, b-2), vocab v-b
  C  am from om  coming soon  category   cat-c (skill c-1)
  D  om from en  available    no content
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import Session as SyncSession

from app.infrastructure.db.lesson_models import (
    CategoryModel,
    CourseModel,
    ExerciseModel,
    LessonModel,
    SkillModel,
    UserVocabProgressModel,
    VocabItemModel,
)
from tests.fakes import EN_AM_COURSE_ID, FakeTokenVerifier

COURSE_B = "course-am-om"
COURSE_C = "course-om-am"
COURSE_D = "course-en-om"

# skill id -> (category id, order_index)
_SKILLS = {
    "a-1": ("cat-a", 1),
    "a-2": ("cat-a", 2),
    "b-1": ("cat-b", 1),
    "b-2": ("cat-b", 2),
    "c-1": ("cat-c", 1),
}


@pytest.fixture
def seeded_courses(db_path: Path) -> None:
    engine = create_engine(f"sqlite:///{db_path}")
    with SyncSession(engine) as session:
        session.add_all(
            [
                CourseModel(
                    id=COURSE_B,
                    learning_language="om",
                    from_language="am",
                    title="Amharic to Afaan Oromo",
                    status="available",
                    order_index=2,
                ),
                CourseModel(
                    id=COURSE_C,
                    learning_language="am",
                    from_language="om",
                    title="Afaan Oromo to Amharic",
                    status="coming_soon",
                    order_index=3,
                ),
                CourseModel(
                    id=COURSE_D,
                    learning_language="om",
                    from_language="en",
                    title="English to Afaan Oromo",
                    status="available",
                    order_index=4,
                ),
            ]
        )
        session.add_all(
            [
                CategoryModel(
                    id="cat-a", course_id=EN_AM_COURSE_ID, title="A", subtitle="a", order_index=1
                ),
                CategoryModel(
                    id="cat-b", course_id=COURSE_B, title="B", subtitle="b", order_index=1
                ),
                CategoryModel(
                    id="cat-c", course_id=COURSE_C, title="C", subtitle="c", order_index=1
                ),
            ]
        )
        session.add_all(
            [
                VocabItemModel(
                    id="v-a", course_id=EN_AM_COURSE_ID, word="ሰላም", translation="Hello"
                ),
                VocabItemModel(id="v-b", course_id=COURSE_B, word="akkam", translation="Hello"),
            ]
        )
        session.add_all(
            [
                SkillModel(id=sid, category_id=cat, title=sid, order_index=order)
                for sid, (cat, order) in _SKILLS.items()
            ]
        )
        session.add_all(
            [LessonModel(id=f"{sid}-l1", skill_id=sid, title=sid, order_index=1) for sid in _SKILLS]
        )
        session.add_all(
            [
                ExerciseModel(
                    id=f"{sid}-e1",
                    lesson_id=f"{sid}-l1",
                    order_index=1,
                    type="multiple_choice",
                    prompt="Prompt",
                    content={"choices": [{"id": "a", "text": "x"}, {"id": "b", "text": "y"}]},
                    answer_key={"correct_choice_id": "a"},
                    vocab_item_id={"a-1": "v-a", "b-1": "v-b"}.get(sid),
                )
                for sid in _SKILLS
            ]
        )
        session.commit()
    engine.dispose()


def _sign_in(
    make_client: Any, subject: str = "google-user-1", pending: dict[str, Any] | None = None
) -> tuple[Any, dict[str, str], dict[str, Any]]:
    client = make_client(FakeTokenVerifier(subject=subject), FakeTokenVerifier())
    body: dict[str, Any] = {"id_token": "irrelevant"}
    if pending is not None:
        body["pending_selection"] = pending
    response = client.post("/api/v1/auth/google", json=body)
    assert response.status_code == 200, response.text
    data = response.json()
    return client, {"Authorization": f"Bearer {data['session_token']}"}, data["user"]


def _switch(client: Any, headers: dict[str, str], course_id: str) -> Any:
    return client.put(
        "/api/v1/users/me/active-course", headers=headers, json={"course_id": course_id}
    )


def _complete(client: Any, headers: dict[str, str], lesson_id: str) -> Any:
    return client.post(
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


def _tree(client: Any, headers: dict[str, str]) -> dict[str, Any]:
    response = client.get("/api/v1/skill-tree", headers=headers)
    assert response.status_code == 200, response.text
    return response.json()


def _states(client: Any, headers: dict[str, str]) -> dict[str, str]:
    return {s["id"]: s["state"] for s in _tree(client, headers)["skills"]}


class TestCourseList:
    def test_lists_every_course_in_order_with_one_active(
        self, make_client: Any, seeded_courses: None
    ) -> None:
        client, headers, _ = _sign_in(make_client)

        body = client.get("/api/v1/courses", headers=headers).json()

        assert [c["id"] for c in body["courses"]] == [
            EN_AM_COURSE_ID,
            COURSE_B,
            COURSE_C,
            COURSE_D,
        ]
        assert body["active_course_id"] == EN_AM_COURSE_ID
        assert [c["is_active"] for c in body["courses"]] == [True, False, False, False]

    def test_coming_soon_courses_are_included_and_marked_with_no_skills(
        self, make_client: Any, seeded_courses: None
    ) -> None:
        client, headers, _ = _sign_in(make_client)

        courses = {
            c["id"]: c for c in client.get("/api/v1/courses", headers=headers).json()["courses"]
        }

        assert courses[COURSE_C]["status"] == "coming_soon"
        assert (courses[COURSE_D]["completed_skills"], courses[COURSE_D]["total_skills"]) == (0, 0)
        assert (
            courses[EN_AM_COURSE_ID]["learning_language"],
            courses[EN_AM_COURSE_ID]["from_language"],
        ) == ("am", "en")
        assert courses[EN_AM_COURSE_ID]["total_skills"] == 2
        assert courses[COURSE_B]["total_skills"] == 2

    def test_completed_skills_are_counted_per_course(
        self, make_client: Any, seeded_courses: None
    ) -> None:
        client, headers, _ = _sign_in(make_client)
        assert _complete(client, headers, "a-1-l1").status_code == 200

        courses = {
            c["id"]: c for c in client.get("/api/v1/courses", headers=headers).json()["courses"]
        }

        assert courses[EN_AM_COURSE_ID]["completed_skills"] == 1
        assert courses[COURSE_B]["completed_skills"] == 0

    def test_requires_authentication(self, make_client: Any, seeded_courses: None) -> None:
        client = make_client(FakeTokenVerifier(), FakeTokenVerifier())

        assert client.get("/api/v1/courses").status_code == 401


class TestSwitchCourse:
    def test_switching_returns_the_new_course_and_mirrors_the_language(
        self, make_client: Any, seeded_courses: None
    ) -> None:
        client, headers, _ = _sign_in(make_client)

        response = _switch(client, headers, COURSE_B)

        assert response.status_code == 200
        body = response.json()
        assert body["active_course_id"] == COURSE_B
        assert body["selected_language"] == "om"
        assert body["course"] == {
            "id": COURSE_B,
            "learning_language": "om",
            "from_language": "am",
            "title": "Amharic to Afaan Oromo",
        }

    def test_the_choice_persists_across_a_new_session(
        self, make_client: Any, seeded_courses: None
    ) -> None:
        client, headers, _ = _sign_in(make_client)
        _switch(client, headers, COURSE_B)

        session_check = client.get("/api/v1/auth/session", headers=headers).json()
        assert session_check["user"]["active_course_id"] == COURSE_B
        assert session_check["user"]["selected_language"] == "om"

        # A later sign-in as the same (returning) user lands on the same course.
        relogin = client.post("/api/v1/auth/google", json={"id_token": "x"}).json()
        assert relogin["user"]["is_new_user"] is False
        assert relogin["user"]["active_course_id"] == COURSE_B

    def test_an_unknown_course_is_404_and_nothing_changes(
        self, make_client: Any, seeded_courses: None
    ) -> None:
        client, headers, _ = _sign_in(make_client)

        response = _switch(client, headers, "no-such-course")

        assert response.status_code == 404
        assert response.json()["error_code"] == "course_not_found"
        assert (
            client.get("/api/v1/courses", headers=headers).json()["active_course_id"]
            == EN_AM_COURSE_ID
        )

    def test_a_coming_soon_course_is_422_and_nothing_changes(
        self, make_client: Any, seeded_courses: None
    ) -> None:
        client, headers, _ = _sign_in(make_client)

        response = _switch(client, headers, COURSE_C)

        assert response.status_code == 422
        assert response.json()["error_code"] == "course_not_available"
        session_check = client.get("/api/v1/auth/session", headers=headers).json()
        assert session_check["user"]["active_course_id"] == EN_AM_COURSE_ID
        assert session_check["user"]["selected_language"] == "am"

    def test_selecting_the_current_course_succeeds(
        self, make_client: Any, seeded_courses: None
    ) -> None:
        client, headers, _ = _sign_in(make_client)

        assert _switch(client, headers, EN_AM_COURSE_ID).status_code == 200

    def test_requires_authentication(self, make_client: Any, seeded_courses: None) -> None:
        client = make_client(FakeTokenVerifier(), FakeTokenVerifier())

        response = client.put("/api/v1/users/me/active-course", json={"course_id": COURSE_B})

        assert response.status_code == 401


class TestCourseScopedSkillTree:
    def test_the_tree_holds_only_the_active_courses_categories_and_skills(
        self, make_client: Any, seeded_courses: None
    ) -> None:
        client, headers, _ = _sign_in(make_client)

        tree = _tree(client, headers)

        assert [c["id"] for c in tree["categories"]] == ["cat-a"]
        assert [s["id"] for s in tree["skills"]] == ["a-1", "a-2"]
        assert tree["course"]["id"] == EN_AM_COURSE_ID

    def test_switching_shows_the_other_courses_tree(
        self, make_client: Any, seeded_courses: None
    ) -> None:
        client, headers, _ = _sign_in(make_client)
        _switch(client, headers, COURSE_B)

        tree = _tree(client, headers)

        assert [s["id"] for s in tree["skills"]] == ["b-1", "b-2"]
        assert tree["course"]["id"] == COURSE_B
        assert tree["course"]["learning_language"] == "om"

    def test_a_course_with_no_content_is_an_empty_tree_not_an_error(
        self, make_client: Any, seeded_courses: None
    ) -> None:
        client, headers, _ = _sign_in(make_client)
        _switch(client, headers, COURSE_D)

        tree = _tree(client, headers)

        assert tree["skills"] == [] and tree["categories"] == []
        assert tree["course"]["id"] == COURSE_D

    def test_a_user_new_to_a_course_sees_its_first_skill_active(
        self, make_client: Any, seeded_courses: None
    ) -> None:
        client, headers, _ = _sign_in(make_client)
        _complete(client, headers, "a-1-l1")
        _switch(client, headers, COURSE_B)

        assert _states(client, headers) == {"b-1": "active", "b-2": "locked"}

    def test_progress_is_independent_and_restored_exactly_on_switching_back(
        self, make_client: Any, seeded_courses: None
    ) -> None:
        client, headers, _ = _sign_in(make_client)
        _complete(client, headers, "a-1-l1")
        before = _tree(client, headers)["skills"]
        _switch(client, headers, COURSE_B)
        _complete(client, headers, "b-1-l1")
        assert _states(client, headers) == {"b-1": "completed", "b-2": "active"}

        _switch(client, headers, EN_AM_COURSE_ID)

        assert _tree(client, headers)["skills"] == before
        assert _states(client, headers) == {"a-1": "completed", "a-2": "active"}

    def test_xp_streak_and_beans_are_account_wide(
        self, make_client: Any, seeded_courses: None
    ) -> None:
        client, headers, _ = _sign_in(make_client)
        _complete(client, headers, "a-1-l1")
        in_a = _tree(client, headers)
        _switch(client, headers, COURSE_B)
        in_b = _tree(client, headers)

        for key in ("total_xp", "streak_count", "beans", "beans_max"):
            assert in_a[key] == in_b[key]
        assert in_a["total_xp"] > 0


class TestLessonsAreGatedByTheirOwnCourse:
    def test_a_non_active_courses_lesson_can_be_completed_and_counts_in_its_course(
        self, make_client: Any, seeded_courses: None
    ) -> None:
        """The queued-offline case: a completion recorded in course B still
        syncs after the user has switched to A (ADR-6, ADR-12)."""
        client, headers, _ = _sign_in(make_client)

        response = _complete(client, headers, "b-1-l1")

        assert response.status_code == 200
        _switch(client, headers, COURSE_B)
        assert _states(client, headers) == {"b-1": "completed", "b-2": "active"}

    def test_a_locked_skill_in_a_non_active_course_is_still_403(
        self, make_client: Any, seeded_courses: None
    ) -> None:
        client, headers, _ = _sign_in(make_client)

        response = client.get("/api/v1/lessons/b-2-l1", headers=headers)

        assert response.status_code == 403
        assert response.json()["error_code"] == "skill_locked"

    def test_a_coming_soon_courses_lesson_cannot_be_started_or_completed(
        self, make_client: Any, seeded_courses: None
    ) -> None:
        client, headers, _ = _sign_in(make_client)

        started = client.get("/api/v1/lessons/c-1-l1", headers=headers)
        completed = _complete(client, headers, "c-1-l1")

        assert started.status_code == 403
        assert started.json()["error_code"] == "course_not_available"
        assert completed.status_code == 403
        assert completed.json()["error_code"] == "course_not_available"


class TestCourseScopedPractice:
    @staticmethod
    def _make_both_words_due(db_path: Path, user_id: str) -> None:
        engine = create_engine(f"sqlite:///{db_path}")
        past = datetime.now(UTC) - timedelta(hours=1)
        with SyncSession(engine) as session:
            session.add_all(
                [
                    UserVocabProgressModel(
                        user_id=user_id,
                        vocab_item_id=vocab_id,
                        box_level=1,
                        next_review_at=past,
                        last_seen_at=past - timedelta(days=1),
                    )
                    for vocab_id in ("v-a", "v-b")
                ]
            )
            session.commit()
        engine.dispose()

    def test_due_count_and_items_only_cover_the_active_course(
        self, make_client: Any, seeded_courses: None, db_path: Path
    ) -> None:
        client, headers, user = _sign_in(make_client)
        self._make_both_words_due(db_path, user["id"])

        assert client.get("/api/v1/practice/due-count", headers=headers).json()["due_count"] == 1
        items = client.get("/api/v1/practice/due-items", headers=headers).json()["items"]
        assert [i["vocab_item_id"] for i in items] == ["v-a"]

    def test_switching_courses_switches_the_practice_words(
        self, make_client: Any, seeded_courses: None, db_path: Path
    ) -> None:
        client, headers, user = _sign_in(make_client)
        self._make_both_words_due(db_path, user["id"])

        _switch(client, headers, COURSE_B)

        assert client.get("/api/v1/practice/due-count", headers=headers).json()["due_count"] == 1
        items = client.get("/api/v1/practice/due-items", headers=headers).json()["items"]
        assert [i["vocab_item_id"] for i in items] == ["v-b"]

    def test_a_course_with_no_due_words_is_caught_up(
        self, make_client: Any, seeded_courses: None, db_path: Path
    ) -> None:
        client, headers, user = _sign_in(make_client)
        self._make_both_words_due(db_path, user["id"])

        _switch(client, headers, COURSE_D)

        assert client.get("/api/v1/practice/due-count", headers=headers).json()["due_count"] == 0

    def test_words_learned_in_a_lesson_land_in_that_courses_practice(
        self, make_client: Any, seeded_courses: None
    ) -> None:
        client, headers, _ = _sign_in(make_client)
        _complete(client, headers, "b-1-l1")
        _switch(client, headers, COURSE_B)

        # Brand-new words are due tomorrow, so nothing is due yet in either.
        assert client.get("/api/v1/practice/due-count", headers=headers).json()["due_count"] == 0


class TestSignupWithLanguagePair:
    def test_an_amharic_speaker_can_start_learning_afaan_oromo(
        self, make_client: Any, seeded_courses: None
    ) -> None:
        _, _, user = _sign_in(
            make_client,
            pending={"language": "om", "from_language": "am", "daily_goal_minutes": 10},
        )

        assert user["active_course_id"] == COURSE_B
        assert user["selected_language"] == "om"

    def test_a_signup_without_a_from_language_means_english(
        self, make_client: Any, seeded_courses: None
    ) -> None:
        _, _, user = _sign_in(make_client, pending={"language": "om", "daily_goal_minutes": 10})

        assert user["active_course_id"] == COURSE_D

    def test_a_signup_with_no_pending_selection_starts_english_to_amharic(
        self, make_client: Any, seeded_courses: None
    ) -> None:
        _, _, user = _sign_in(make_client)

        assert user["active_course_id"] == EN_AM_COURSE_ID
        assert user["selected_language"] == "am"

    def test_an_unavailable_pair_is_rejected_and_no_account_is_created(
        self, make_client: Any, seeded_courses: None
    ) -> None:
        client = make_client(FakeTokenVerifier(subject="google-user-9"), FakeTokenVerifier())
        pending = {"language": "am", "from_language": "om", "daily_goal_minutes": 10}

        rejected = client.post(
            "/api/v1/auth/google", json={"id_token": "x", "pending_selection": pending}
        )

        assert rejected.status_code == 400
        assert rejected.json()["error_code"] == "invalid_pending_selection"
        # Nothing was created: the same person signing up properly is a new user.
        retry = client.post("/api/v1/auth/google", json={"id_token": "x"})
        assert retry.json()["user"]["is_new_user"] is True

    def test_the_same_language_twice_is_rejected(
        self, make_client: Any, seeded_courses: None
    ) -> None:
        client = make_client(FakeTokenVerifier(subject="google-user-8"), FakeTokenVerifier())
        pending = {"language": "am", "from_language": "am", "daily_goal_minutes": 10}

        response = client.post(
            "/api/v1/auth/google", json={"id_token": "x", "pending_selection": pending}
        )

        assert response.status_code == 400


class TestPatchLanguageCompatibility:
    def test_a_language_change_activates_the_matching_course(
        self, make_client: Any, seeded_courses: None
    ) -> None:
        client, headers, _ = _sign_in(make_client)

        response = client.patch("/api/v1/users/me", headers=headers, json={"language": "om"})

        assert response.status_code == 200
        assert response.json()["selected_language"] == "om"
        assert response.json()["active_course_id"] == COURSE_D
        assert client.get("/api/v1/courses", headers=headers).json()["active_course_id"] == COURSE_D

    def test_a_language_nobody_teaches_is_422(self, make_client: Any, seeded_courses: None) -> None:
        client, headers, _ = _sign_in(make_client)

        response = client.patch("/api/v1/users/me", headers=headers, json={"language": "en"})

        assert response.status_code == 422
        assert response.json()["error_code"] == "invalid_preference_value"
        assert (
            client.get("/api/v1/courses", headers=headers).json()["active_course_id"]
            == EN_AM_COURSE_ID
        )

    def test_the_mirror_and_the_active_course_always_agree(
        self, make_client: Any, seeded_courses: None
    ) -> None:
        client, headers, _ = _sign_in(make_client)

        _switch(client, headers, COURSE_B)
        after_switch = client.get("/api/v1/auth/session", headers=headers).json()["user"]
        client.patch("/api/v1/users/me", headers=headers, json={"language": "am"})
        after_patch = client.get("/api/v1/auth/session", headers=headers).json()["user"]

        assert (after_switch["active_course_id"], after_switch["selected_language"]) == (
            COURSE_B,
            "om",
        )
        # From Amharic, learning Amharic is not a course, so the change is refused
        # and both fields are untouched.
        assert (after_patch["active_course_id"], after_patch["selected_language"]) == (
            COURSE_B,
            "om",
        )


class TestPerUserIsolationAndInput:
    def test_one_users_switch_does_not_change_another_users_course(
        self, make_client: Any, seeded_courses: None
    ) -> None:
        verifier = FakeTokenVerifier(subject="user-one")
        client = make_client(verifier, FakeTokenVerifier())
        first = client.post("/api/v1/auth/google", json={"id_token": "x"}).json()
        verifier.next_subject = "user-two"
        second = client.post("/api/v1/auth/google", json={"id_token": "x"}).json()
        headers_one = {"Authorization": f"Bearer {first['session_token']}"}
        headers_two = {"Authorization": f"Bearer {second['session_token']}"}

        assert _switch(client, headers_one, COURSE_B).status_code == 200

        list_two = client.get("/api/v1/courses", headers=headers_two).json()
        assert list_two["active_course_id"] == EN_AM_COURSE_ID
        assert [s["id"] for s in _tree(client, headers_two)["skills"]] == ["a-1", "a-2"]

    def test_a_request_without_a_course_id_is_rejected_and_changes_nothing(
        self, make_client: Any, seeded_courses: None
    ) -> None:
        client, headers, _ = _sign_in(make_client)

        response = client.put("/api/v1/users/me/active-course", headers=headers, json={})

        assert response.status_code == 422
        assert (
            client.get("/api/v1/courses", headers=headers).json()["active_course_id"]
            == EN_AM_COURSE_ID
        )


class TestPublicCourseCatalog:
    def test_it_needs_no_login_and_lists_every_course_in_order(
        self, make_client: Any, seeded_courses: None
    ) -> None:
        client = make_client(FakeTokenVerifier(), FakeTokenVerifier())

        response = client.get("/api/v1/courses/catalog")

        assert response.status_code == 200
        courses = response.json()["courses"]
        assert [c["id"] for c in courses] == [EN_AM_COURSE_ID, COURSE_B, COURSE_C, COURSE_D]
        assert courses[0] == {
            "id": EN_AM_COURSE_ID,
            "learning_language": "am",
            "from_language": "en",
            "title": "English to Amharic",
            "status": "available",
            "order_index": 1,
        }

    def test_coming_soon_courses_are_included_and_marked(
        self, make_client: Any, seeded_courses: None
    ) -> None:
        client = make_client(FakeTokenVerifier(), FakeTokenVerifier())

        courses = {c["id"]: c for c in client.get("/api/v1/courses/catalog").json()["courses"]}

        assert courses[COURSE_C]["status"] == "coming_soon"
        assert courses[COURSE_B]["status"] == "available"

    def test_it_carries_no_per_user_fields(self, make_client: Any, seeded_courses: None) -> None:
        client = make_client(FakeTokenVerifier(), FakeTokenVerifier())

        body = client.get("/api/v1/courses/catalog").json()

        assert "active_course_id" not in body
        for course in body["courses"]:
            assert not {"is_active", "completed_skills", "total_skills"} & set(course)

    def test_the_signed_in_course_list_still_needs_a_login(
        self, make_client: Any, seeded_courses: None
    ) -> None:
        client = make_client(FakeTokenVerifier(), FakeTokenVerifier())

        assert client.get("/api/v1/courses").status_code == 401
