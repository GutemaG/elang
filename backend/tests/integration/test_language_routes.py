"""Integration tests: a course admin may work on the Sounds charts, and
generate audio, for the languages their courses teach (intent 028, story
009)."""

from __future__ import annotations

import asyncio
import sqlite3
from collections.abc import Callable
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine

from app.config import Settings
from app.domain.admin import COURSE_ADMIN
from app.infrastructure.api import dependencies
from app.infrastructure.db.seed_lesson_content import seed
from tests.fakes import EN_AM_COURSE_ID, FakeTokenVerifier
from tests.integration.admin_route_rules import LANGUAGE, OPEN
from tests.team import add_member

ClientFactory = Callable[[object, object], TestClient]
Pair = tuple[TestClient, FakeTokenVerifier]
OWNER = "owner@example.com"
HELPER = "helper@example.com"
A = "/api/v1/admin/sound-charts"


@pytest.fixture
def db(db_path: Path) -> Path:
    async def _seed() -> None:
        engine = create_async_engine(f"sqlite+aiosqlite:///{db_path}")
        async with AsyncSession(engine) as session:
            await seed(session)
            await session.commit()
        await engine.dispose()

    asyncio.run(_seed())
    with sqlite3.connect(db_path) as conn:
        conn.executemany(
            "INSERT OR IGNORE INTO languages (code, name, native_name, created_at) "
            "VALUES (?, ?, ?, '2026-10-04')",
            [("am", "Amharic", "አማርኛ"), ("om", "Afaan Oromo", "Afaan Oromoo")],
        )
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


@pytest.fixture
def charts(pair: Pair) -> None:
    """An Amharic and an Afaan Oromo chart, made by the owner."""
    h = _sign_in(pair, OWNER)
    for language in ("am", "om"):
        response = pair[0].post(A, json={"language": language, "template": "empty"}, headers=h)
        assert response.status_code == 201, response.text


@pytest.fixture
def helper(pair: Pair, db: Path, charts: None) -> dict[str, str]:
    """A course admin of English to Amharic: their language is `am`."""
    add_member(db, HELPER, COURSE_ADMIN, [EN_AM_COURSE_ID])
    return _sign_in(pair, HELPER)


def _letters(db: Path) -> list[tuple[object, ...]]:
    with sqlite3.connect(db) as conn:
        return sorted(conn.execute("SELECT * FROM sound_letters").fetchall(), key=repr)


def _call(client: TestClient, method: str, path: str, language: str, h: dict) -> int:
    url = path.replace("{language}", language).replace("{letter_id}", "missing")
    body: dict[str, object] | None = None if method in ("GET", "DELETE") else {}
    return client.request(method, url, headers=h, json=body).status_code


def test_the_chart_list_has_only_their_languages(pair: Pair, helper: dict) -> None:
    charts = pair[0].get(A, headers=helper).json()["charts"]

    assert [c["language"] for c in charts] == ["am"]


def test_a_super_admin_lists_every_chart(pair: Pair, charts: None) -> None:
    charts_ = pair[0].get(A, headers=_sign_in(pair, OWNER)).json()["charts"]

    assert {c["language"] for c in charts_} == {"am", "om"}


@pytest.mark.parametrize(("method", "path"), sorted(LANGUAGE))
def test_another_language_is_the_no_chart_404_and_unchanged(
    pair: Pair, db: Path, helper: dict, method: str, path: str
) -> None:
    before = _letters(db)
    url = path.replace("{language}", "om").replace("{letter_id}", "missing")
    body: dict[str, object] | None = None if method in ("GET", "DELETE") else {}

    response = pair[0].request(method, url, headers=helper, json=body)

    assert response.status_code == 404
    assert response.json()["details"] == {"entity": "sound_chart", "id": "om"}
    assert _letters(db) == before


@pytest.mark.parametrize(("method", "path"), sorted(LANGUAGE))
def test_their_language_gets_through(pair: Pair, helper: dict, method: str, path: str) -> None:
    status = _call(pair[0], method, path, "am", helper)

    assert status != 403
    if status == 404:  # an unknown letter, not a refused chart
        assert path.endswith("{letter_id}")


def test_a_course_admin_records_a_letter_of_their_chart(pair: Pair, helper: dict) -> None:
    response = pair[0].post(
        f"{A}/am/letters", json={"glyph": "ሀ", "group": "fidel"}, headers=helper
    )

    assert response.status_code in (200, 201, 422), response.text
    assert response.status_code != 404


def test_generating_for_another_language_is_refused(pair: Pair, helper: dict) -> None:
    response = pair[0].post(
        "/api/v1/admin/voice/generate",
        json={"text": "Akkam", "gender": "female", "language": "om"},
        headers=helper,
    )

    assert response.status_code == 403
    assert response.json()["error_code"] == "super_admin_only"


def test_generating_for_their_language_gets_through(pair: Pair, helper: dict) -> None:
    response = pair[0].post(
        "/api/v1/admin/voice/generate",
        json={"text": "ሰላም", "gender": "female", "language": "am"},
        headers=helper,
    )

    # No Addis key in tests: the guard let it through to the 503.
    assert response.status_code == 503


@pytest.mark.parametrize(("method", "path"), sorted(OPEN))
def test_open_routes_stay_open_to_a_course_admin(
    pair: Pair, helper: dict, method: str, path: str
) -> None:
    body = {"url": "https://example.com/a.mp3"} if method == "POST" else None
    url = path.replace("{language}", "am")

    response = pair[0].request(method, url, headers=helper, json=body)

    assert response.status_code != 403
