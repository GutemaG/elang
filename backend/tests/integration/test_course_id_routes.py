"""Integration tests: a course admin's course list, and the routes named by
`{course_id}` (intent 028, stories 006 and 007)."""

from __future__ import annotations

import asyncio
import sqlite3
from collections.abc import Callable
from datetime import UTC, datetime
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from httpx import Response
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine

from app.config import Settings
from app.domain.admin import COURSE_ADMIN, SUPER_ADMIN
from app.infrastructure.api import dependencies
from app.infrastructure.db.lesson_models import CourseModel
from app.infrastructure.db.seed_lesson_content import seed
from tests.fakes import EN_AM_COURSE_ID, FakeTokenVerifier
from tests.integration import test_curriculum_publish as workbook
from tests.integration.admin_route_rules import COURSE
from tests.team import add_member

ClientFactory = Callable[[object, object], TestClient]
Pair = tuple[TestClient, FakeTokenVerifier]
OWNER = "owner@example.com"
HELPER = "helper@example.com"
OTHER_COURSE_ID = "c0000000-0000-0000-0000-0000000000ti"
ROUTES = sorted(COURSE)
# The tables a course route could write to.
TABLES = (
    "categories",
    "skills",
    "lessons",
    "vocab_items",
    "curriculum_entries",
    "curriculum_rows",
    "curriculum_exercises",
)


@pytest.fixture
def db(db_path: Path) -> Path:
    """The seeded content plus an empty course of our own."""

    async def _setup() -> None:
        engine = create_async_engine(f"sqlite+aiosqlite:///{db_path}")
        async with AsyncSession(engine) as session:
            await seed(session)
            session.add(
                CourseModel(
                    id=OTHER_COURSE_ID,
                    # A pair the seed doesn't create.
                    learning_language="ti",
                    from_language="en",
                    title="English to Tigrinya",
                    status="available",
                    order_index=99,
                    created_at=datetime.now(UTC),
                )
            )
            await session.commit()
        await engine.dispose()

    asyncio.run(_setup())
    return db_path


@pytest.fixture
def pair(make_client: ClientFactory, db: Path, monkeypatch: pytest.MonkeyPatch) -> Pair:
    monkeypatch.setattr(dependencies, "get_settings", lambda: Settings(admin_emails=OWNER))
    google = FakeTokenVerifier()
    return make_client(google, FakeTokenVerifier()), google


def _sign_in(pair: Pair, email: str) -> dict[str, str]:
    client, google = pair
    google.next_subject = f"sub-{email}"
    google.next_email = email
    response = client.post("/api/v1/auth/google", json={"id_token": "t"})
    assert response.status_code == 200
    return {"Authorization": f"Bearer {response.json()['session_token']}"}


def _call(client: TestClient, method: str, path: str, course_id: str, h: dict) -> Response:
    url = path.replace("{course_id}", course_id).replace("{ref}", "S1-U01-L1")
    body: dict[str, object] | None = None if method in ("GET", "DELETE") else {}
    return client.request(method, url, headers=h, json=body)


def _course_ids(client: TestClient, h: dict) -> list[str]:
    response = client.get("/api/v1/admin/courses", headers=h)
    assert response.status_code == 200
    return [c["id"] for c in response.json()["courses"]]


def _snapshot(db_path: Path) -> dict[str, list[tuple[object, ...]]]:
    with sqlite3.connect(db_path) as conn:
        return {t: sorted(conn.execute(f"SELECT * FROM {t}").fetchall(), key=repr) for t in TABLES}


class TestCourseList:
    def test_a_course_admin_sees_only_their_courses(self, pair: Pair, db: Path) -> None:
        add_member(db, HELPER, COURSE_ADMIN, [OTHER_COURSE_ID])

        assert _course_ids(pair[0], _sign_in(pair, HELPER)) == [OTHER_COURSE_ID]

    def test_a_course_admin_with_none_sees_an_empty_list(self, pair: Pair, db: Path) -> None:
        add_member(db, HELPER, COURSE_ADMIN)

        assert _course_ids(pair[0], _sign_in(pair, HELPER)) == []

    @pytest.mark.parametrize("stored", [False, True])
    def test_super_admins_see_every_course(self, pair: Pair, db: Path, stored: bool) -> None:
        if stored:
            add_member(db, HELPER, SUPER_ADMIN)

        ids = _course_ids(pair[0], _sign_in(pair, HELPER if stored else OWNER))

        with sqlite3.connect(db) as conn:
            every = {r[0] for r in conn.execute("SELECT id FROM courses")}
        assert set(ids) == every
        assert {EN_AM_COURSE_ID, OTHER_COURSE_ID} <= every


@pytest.mark.parametrize(("method", "path"), ROUTES)
def test_another_course_is_not_found_and_unchanged(
    pair: Pair, db: Path, method: str, path: str
) -> None:
    add_member(db, HELPER, COURSE_ADMIN, [OTHER_COURSE_ID])
    h = _sign_in(pair, HELPER)
    before = _snapshot(db)

    response = _call(pair[0], method, path, EN_AM_COURSE_ID, h)

    assert response.status_code == 404
    assert response.json() == {
        "error_code": "content_not_found",
        "message": "No such course",
        "details": {"entity": "course", "id": EN_AM_COURSE_ID},
    }
    assert _snapshot(db) == before


@pytest.mark.parametrize(("method", "path"), ROUTES)
def test_their_own_course_gets_through(pair: Pair, db: Path, method: str, path: str) -> None:
    add_member(db, HELPER, COURSE_ADMIN, [EN_AM_COURSE_ID])

    response = _call(pair[0], method, path, EN_AM_COURSE_ID, _sign_in(pair, HELPER))

    assert response.status_code != 403
    if response.status_code == 404:
        assert response.json().get("details", {}).get("entity") != "course"


def test_a_course_admin_publishes_a_lesson_in_their_course(pair: Pair, db: Path) -> None:
    add_member(db, HELPER, COURSE_ADMIN, [EN_AM_COURSE_ID])
    client, h = pair[0], _sign_in(pair, HELPER)
    workbook._import(client, h)
    workbook._finish(client, h)
    assert workbook._save(client, h, workbook._choice("Which is hello?")).status_code == 200

    response = workbook._publish(client, h)

    assert response.status_code == 200, response.text
