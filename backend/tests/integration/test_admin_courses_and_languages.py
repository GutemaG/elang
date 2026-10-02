"""Integration tests: creating courses and managing the languages they use
from the content admin API, over HTTP against a temp SQLite database holding
the real seeded content (English to Amharic).
"""

from __future__ import annotations

import asyncio
import sqlite3
from collections.abc import Callable
from pathlib import Path
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine

from app.config import Settings
from app.infrastructure.api import dependencies
from app.infrastructure.db.seed_lesson_content import COURSES, _content_id, seed
from tests.fakes import EN_AM_COURSE_ID, FakeTokenVerifier
from tests.integration.test_admin_content_endpoints import _exercise_body

ClientFactory = Callable[[object, object], TestClient]
ADMIN = "admin@example.com"
A = "/api/v1/admin"

_LANGUAGES = [
    ("am", "Amharic", "አማርኛ"),
    ("en", "English", "English"),
    ("om", "Afaan Oromo", "Afaan Oromoo"),
    ("ti", "Tigrinya", "ትግርኛ"),
]
# The seeded courses, in catalog order: English to Amharic, English to Afaan
# Oromo, and Amharic and Afaan Oromo each from the other.
SEEDED = [_content_id(course["slug"]) for course in COURSES]


@pytest.fixture
def seeded(db_path: Path) -> Path:
    async def _seed() -> None:
        engine = create_async_engine(f"sqlite+aiosqlite:///{db_path}")
        async with AsyncSession(engine) as session:
            await seed(session)
            await session.commit()
        await engine.dispose()

    asyncio.run(_seed())
    with sqlite3.connect(db_path) as conn:
        conn.executemany(
            "INSERT INTO languages (code, name, native_name, created_at) "
            "VALUES (?, ?, ?, '2026-10-02')",
            _LANGUAGES,
        )
    return db_path


@pytest.fixture
def client(make_client: ClientFactory, seeded: Path, monkeypatch: pytest.MonkeyPatch) -> TestClient:
    monkeypatch.setattr(dependencies, "get_settings", lambda: Settings(admin_emails=ADMIN))
    return make_client(FakeTokenVerifier(subject="sub-admin", email=ADMIN), FakeTokenVerifier())


@pytest.fixture
def h(client: TestClient) -> dict[str, str]:
    # Signing in makes the admin a learner too, on English to Amharic.
    token = client.post("/api/v1/auth/google", json={"id_token": "t"}).json()["session_token"]
    return {"Authorization": f"Bearer {token}"}


def _new_course(client: TestClient, h: dict, **body: Any) -> Any:
    return client.post(
        f"{A}/courses", json={"learning_language": "ti", "from_language": "en", **body}, headers=h
    )


def _fill(client: TestClient, h: dict, course_id: str) -> None:
    """One section, skill, lesson and exercise: enough to be available."""
    section = client.post(f"{A}/courses/{course_id}/sections", json={"title": "S"}, headers=h)
    skill = client.post(
        f"{A}/sections/{section.json()['id']}/skills", json={"title": "K"}, headers=h
    )
    lesson = client.post(f"{A}/skills/{skill.json()['id']}/lessons", json={"title": "L"}, headers=h)
    exercise = client.post(
        f"{A}/lessons/{lesson.json()['id']}/exercises", json=_exercise_body(), headers=h
    )
    assert exercise.status_code == 201, exercise.json()


class TestLanguages:
    def test_listed_by_name_with_how_many_courses_use_each(
        self, client: TestClient, h: dict
    ) -> None:
        response = client.get(f"{A}/languages", headers=h)

        assert response.status_code == 200
        assert response.json()["languages"] == [
            {"code": "om", "name": "Afaan Oromo", "native_name": "Afaan Oromoo", "course_count": 3},
            {"code": "am", "name": "Amharic", "native_name": "አማርኛ", "course_count": 3},
            {"code": "en", "name": "English", "native_name": "English", "course_count": 2},
            {"code": "ti", "name": "Tigrinya", "native_name": "ትግርኛ", "course_count": 0},
        ]

    def test_an_added_language_can_be_used_for_a_course(self, client: TestClient, h: dict) -> None:
        created = client.post(
            f"{A}/languages",
            json={"code": " SID ", "name": " Sidama ", "native_name": "Sidaamu Afoo"},
            headers=h,
        )

        assert created.status_code == 201
        assert created.json() == {
            "code": "sid",
            "name": "Sidama",
            "native_name": "Sidaamu Afoo",
            "course_count": 0,
        }
        course = _new_course(client, h, learning_language="sid")
        assert course.status_code == 201
        assert course.json()["learning_language_name"] == "Sidama"

    def test_a_code_already_in_use_is_refused(self, client: TestClient, h: dict) -> None:
        response = client.post(
            f"{A}/languages", json={"code": "ti", "name": "T", "native_name": "T"}, headers=h
        )

        assert response.status_code == 409
        assert response.json()["error_code"] == "content_exists"

    @pytest.mark.parametrize(
        ("body", "field"),
        [
            ({"code": "t", "name": "T", "native_name": "T"}, "code"),
            ({"code": "tigr", "name": "T", "native_name": "T"}, "code"),
            ({"code": "t1", "name": "T", "native_name": "T"}, "code"),
            ({"code": "so", "name": "  ", "native_name": "Soomaali"}, "name"),
            ({"code": "so", "name": "Somali", "native_name": ""}, "native_name"),
            ({"code": "so", "name": "S" * 65, "native_name": "Soomaali"}, "name"),
        ],
    )
    def test_a_bad_language_is_refused(
        self, client: TestClient, h: dict, body: dict, field: str
    ) -> None:
        response = client.post(f"{A}/languages", json=body, headers=h)

        assert response.status_code == 422
        assert response.json()["details"] == {"field": field}

    def test_names_can_be_corrected(self, client: TestClient, h: dict) -> None:
        response = client.patch(f"{A}/languages/am", json={"native_name": "አማርኛ ቋንቋ"}, headers=h)

        assert response.status_code == 200
        assert response.json() == {
            "code": "am",
            "name": "Amharic",
            "native_name": "አማርኛ ቋንቋ",
            "course_count": 3,
        }
        catalog = client.get("/api/v1/courses/catalog").json()["courses"]
        assert catalog[0]["learning_language_native_name"] == "አማርኛ ቋንቋ"

    def test_editing_an_unknown_language_is_404(self, client: TestClient, h: dict) -> None:
        assert client.patch(f"{A}/languages/xx", json={"name": "X"}, headers=h).status_code == 404

    def test_only_an_unused_language_can_be_deleted(self, client: TestClient, h: dict) -> None:
        used = client.delete(f"{A}/languages/am", headers=h)
        assert used.status_code == 409
        assert used.json()["error_code"] == "content_in_use"

        assert client.delete(f"{A}/languages/ti", headers=h).status_code == 204
        codes = [
            lang["code"] for lang in client.get(f"{A}/languages", headers=h).json()["languages"]
        ]
        assert codes == ["om", "am", "en"]


class TestCreateCourse:
    def test_a_new_course_is_empty_coming_soon_and_last(self, client: TestClient, h: dict) -> None:
        response = _new_course(client, h)

        assert response.status_code == 201
        course = response.json()
        assert course == {
            "id": course["id"],
            "title": "English to Tigrinya",
            "learning_language": "ti",
            "from_language": "en",
            "learning_language_name": "Tigrinya",
            "learning_language_native_name": "ትግርኛ",
            "from_language_name": "English",
            "from_language_native_name": "English",
            "status": "coming_soon",
            "section_count": 0,
        }
        listed = client.get(f"{A}/courses", headers=h).json()["courses"]
        assert [c["id"] for c in listed] == [*SEEDED, course["id"]]
        # Learners see it in the catalog as coming soon, named.
        catalog = client.get("/api/v1/courses/catalog").json()["courses"]
        assert catalog[-1]["id"] == course["id"]
        assert catalog[-1]["status"] == "coming_soon"
        assert catalog[-1]["learning_language_name"] == "Tigrinya"

    def test_a_given_title_is_kept(self, client: TestClient, h: dict) -> None:
        response = _new_course(client, h, title="  Tigrinya for beginners ")

        assert response.json()["title"] == "Tigrinya for beginners"

    @pytest.mark.parametrize(
        ("body", "field"),
        [
            ({"learning_language": "xx"}, "learning_language"),
            ({"from_language": ""}, "from_language"),
            ({"learning_language": "en", "from_language": "en"}, "from_language"),
        ],
    )
    def test_a_bad_pair_is_refused(
        self, client: TestClient, h: dict, body: dict, field: str
    ) -> None:
        response = _new_course(client, h, **body)

        assert response.status_code == 422
        assert response.json()["details"] == {"field": field}

    def test_a_pair_that_already_has_a_course_is_refused(self, client: TestClient, h: dict) -> None:
        response = _new_course(client, h, learning_language="am")

        assert response.status_code == 409
        assert response.json()["error_code"] == "content_exists"


class TestCourseStatus:
    def test_an_empty_course_cannot_be_made_available(self, client: TestClient, h: dict) -> None:
        course_id = _new_course(client, h).json()["id"]

        response = client.patch(f"{A}/courses/{course_id}", json={"status": "available"}, headers=h)

        assert response.status_code == 422
        assert response.json()["details"] == {"field": "status"}

    def test_a_course_with_an_exercise_can_be_made_available(
        self, client: TestClient, h: dict
    ) -> None:
        course_id = _new_course(client, h).json()["id"]
        _fill(client, h, course_id)

        response = client.patch(f"{A}/courses/{course_id}", json={"status": "available"}, headers=h)

        assert response.status_code == 200
        assert response.json()["status"] == "available"
        assert response.json()["section_count"] == 1
        catalog = {c["id"]: c for c in client.get("/api/v1/courses/catalog").json()["courses"]}
        assert catalog[course_id]["status"] == "available"
        # A learner can now switch to it, and the skill tree names it.
        switched = client.put(
            "/api/v1/users/me/active-course", json={"course_id": course_id}, headers=h
        )
        assert switched.status_code == 200
        assert switched.json()["selected_language"] == "ti"
        tree = client.get("/api/v1/skill-tree", headers=h).json()
        assert tree["course"]["learning_language_name"] == "Tigrinya"

    def test_a_course_learners_are_studying_stays_available(
        self, client: TestClient, h: dict
    ) -> None:
        response = client.patch(
            f"{A}/courses/{EN_AM_COURSE_ID}", json={"status": "coming_soon"}, headers=h
        )

        assert response.status_code == 409
        assert response.json()["error_code"] == "content_in_use"

    def test_an_unknown_status_is_refused(self, client: TestClient, h: dict) -> None:
        course_id = _new_course(client, h).json()["id"]

        response = client.patch(f"{A}/courses/{course_id}", json={"status": "live"}, headers=h)

        assert response.status_code == 422
        assert response.json()["details"] == {"field": "status"}

    def test_title_and_status_change_together(self, client: TestClient, h: dict) -> None:
        course_id = _new_course(client, h).json()["id"]
        _fill(client, h, course_id)

        response = client.patch(
            f"{A}/courses/{course_id}", json={"title": "Tigrinya", "status": "available"}, headers=h
        )

        assert (response.json()["title"], response.json()["status"]) == ("Tigrinya", "available")
        # And back, as no learner has picked it.
        back = client.patch(f"{A}/courses/{course_id}", json={"status": "coming_soon"}, headers=h)
        assert back.json()["status"] == "coming_soon"


class TestDeleteCourse:
    def test_an_empty_course_can_be_deleted(self, client: TestClient, h: dict) -> None:
        course_id = _new_course(client, h).json()["id"]

        assert client.delete(f"{A}/courses/{course_id}", headers=h).status_code == 204
        listed = client.get(f"{A}/courses", headers=h).json()["courses"]
        assert [c["id"] for c in listed] == SEEDED
        # The pair is free again.
        assert _new_course(client, h).status_code == 201

    def test_a_course_with_content_cannot_be_deleted(self, client: TestClient, h: dict) -> None:
        course_id = _new_course(client, h).json()["id"]
        _fill(client, h, course_id)

        response = client.delete(f"{A}/courses/{course_id}", headers=h)

        assert response.status_code == 409
        assert response.json()["details"] == {"sections": 1, "words": 0}

    def test_a_course_learners_are_studying_cannot_be_deleted(
        self, client: TestClient, h: dict
    ) -> None:
        response = client.delete(f"{A}/courses/{EN_AM_COURSE_ID}", headers=h)

        assert response.status_code == 409
        assert response.json()["details"] == {"learners": 1}

    def test_deleting_an_unknown_course_is_404(self, client: TestClient, h: dict) -> None:
        assert client.delete(f"{A}/courses/nope", headers=h).status_code == 404
