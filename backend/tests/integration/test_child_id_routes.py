"""Integration tests: routes named by a section, skill, lesson, exercise or
vocab item check the course behind it (intent 028, story 008)."""

from __future__ import annotations

import asyncio
import sqlite3
from collections.abc import Callable
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from httpx import Response
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine

from app.config import Settings
from app.domain.admin import COURSE_ADMIN
from app.infrastructure.api import dependencies
from app.infrastructure.db.admin_content_repository import SqlAlchemyAdminContentRepository
from app.infrastructure.db.seed_lesson_content import seed
from tests.fakes import EN_AM_COURSE_ID, FakeTokenVerifier
from tests.integration.admin_route_rules import BODY_LESSON, CHILD
from tests.team import add_member

ClientFactory = Callable[[object, object], TestClient]
Pair = tuple[TestClient, FakeTokenVerifier]
OWNER = "owner@example.com"
HELPER = "helper@example.com"
TABLES = ("categories", "skills", "lessons", "exercises", "vocab_items")
PARAM = {
    "section": "{section_id}",
    "skill": "{skill_id}",
    "lesson": "{lesson_id}",
    "exercise": "{exercise_id}",
    "vocab": "{vocab_item_id}",
}


@pytest.fixture
def db(db_path: Path) -> Path:
    async def _seed() -> None:
        engine = create_async_engine(f"sqlite+aiosqlite:///{db_path}")
        async with AsyncSession(engine) as session:
            await seed(session)
            await session.commit()
        await engine.dispose()

    asyncio.run(_seed())
    return db_path


@pytest.fixture
def ids(db: Path) -> dict[str, str]:
    """One of each kind of item in the English-to-Amharic course."""
    with sqlite3.connect(db) as conn:
        one = lambda sql: conn.execute(sql, (EN_AM_COURSE_ID,)).fetchone()[0]  # noqa: E731
        return {
            "section": one("SELECT id FROM categories WHERE course_id = ?"),
            "skill": one(
                "SELECT s.id FROM skills s JOIN categories c ON c.id = s.category_id"
                " WHERE c.course_id = ?"
            ),
            "lesson": one(
                "SELECT l.id FROM lessons l JOIN skills s ON s.id = l.skill_id"
                " JOIN categories c ON c.id = s.category_id WHERE c.course_id = ?"
            ),
            "exercise": one(
                "SELECT e.id FROM exercises e JOIN lessons l ON l.id = e.lesson_id"
                " JOIN skills s ON s.id = l.skill_id JOIN categories c ON c.id = s.category_id"
                " WHERE c.course_id = ?"
            ),
            "vocab": one("SELECT id FROM vocab_items WHERE course_id = ?"),
        }


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


def _call(client: TestClient, method: str, path: str, kind: str, item: str, h: dict) -> Response:
    body: dict[str, object] | None = None if method in ("GET", "DELETE") else {}
    return client.request(method, path.replace(PARAM[kind], item), headers=h, json=body)


def _snapshot(db: Path) -> dict[str, list[tuple[object, ...]]]:
    with sqlite3.connect(db) as conn:
        return {t: sorted(conn.execute(f"SELECT * FROM {t}").fetchall(), key=repr) for t in TABLES}


ROUTES = sorted(CHILD.items())


@pytest.mark.parametrize(("route", "kind"), ROUTES)
def test_another_courses_item_is_not_found_and_unchanged(
    pair: Pair, db: Path, ids: dict[str, str], route: tuple[str, str], kind: str
) -> None:
    add_member(db, HELPER, COURSE_ADMIN)  # no courses at all
    h = _sign_in(pair, HELPER)
    before = _snapshot(db)

    response = _call(pair[0], *route, kind, ids[kind], h)

    assert response.status_code == 404
    assert response.json()["details"] == {"entity": kind, "id": ids[kind]}
    assert _snapshot(db) == before


@pytest.mark.parametrize(("route", "kind"), ROUTES)
def test_an_item_in_their_course_gets_through(
    pair: Pair, db: Path, ids: dict[str, str], route: tuple[str, str], kind: str
) -> None:
    add_member(db, HELPER, COURSE_ADMIN, [EN_AM_COURSE_ID])

    response = _call(pair[0], *route, kind, ids[kind], _sign_in(pair, HELPER))

    assert response.status_code not in (403, 404), response.text


@pytest.mark.parametrize(("route", "kind"), ROUTES)
def test_an_unknown_id_is_the_same_404(
    pair: Pair, db: Path, route: tuple[str, str], kind: str
) -> None:
    add_member(db, HELPER, COURSE_ADMIN, [EN_AM_COURSE_ID])

    response = _call(pair[0], *route, kind, "missing", _sign_in(pair, HELPER))

    assert response.status_code == 404
    assert response.json()["details"]["id"] == "missing"


def _body(path: str, lesson_id: str) -> dict[str, object]:
    if path.endswith("/generate"):
        return {"text": "ሰላም", "gender": "female", "lesson_id": lesson_id}
    return {"lesson_id": lesson_id, "content_type": "audio/mpeg", "size": 10}


@pytest.mark.parametrize("route", sorted(BODY_LESSON))
def test_a_lesson_named_in_the_body_is_checked(
    pair: Pair, db: Path, ids: dict[str, str], route: tuple[str, str]
) -> None:
    method, path = route
    add_member(db, HELPER, COURSE_ADMIN)
    h = _sign_in(pair, HELPER)

    response = pair[0].request(method, path, headers=h, json=_body(path, ids["lesson"]))

    assert response.status_code == 404
    assert response.json()["details"] == {"entity": "lesson", "id": ids["lesson"]}


@pytest.mark.parametrize("route", sorted(BODY_LESSON))
def test_a_lesson_in_their_course_named_in_the_body_gets_through(
    pair: Pair, db: Path, ids: dict[str, str], route: tuple[str, str]
) -> None:
    method, path = route
    add_member(db, HELPER, COURSE_ADMIN, [EN_AM_COURSE_ID])
    h = _sign_in(pair, HELPER)

    response = pair[0].request(method, path, headers=h, json=_body(path, ids["lesson"]))

    # Storage or the voice service may not be set up here; the guard let
    # it through.
    assert response.status_code not in (403, 404), response.text


async def test_course_of_finds_each_kind(ids: dict[str, str], db_session: AsyncSession) -> None:
    repo = SqlAlchemyAdminContentRepository(db_session)

    for kind, item in ids.items():
        assert await repo.course_of(kind, item) == EN_AM_COURSE_ID
        assert await repo.course_of(kind, "missing") is None
