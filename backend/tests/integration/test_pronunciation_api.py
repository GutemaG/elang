"""Integration tests: romanization over HTTP. An admin saves an exercise
whose tiles and question carry a `pronunciation`; the lesson API serves
them. One without any is served exactly as before, with no `pronunciation`
key at all. Against a temp SQLite database holding the real seeded content.
"""

from __future__ import annotations

import asyncio
from collections.abc import Callable
from pathlib import Path
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine

from app.config import Settings
from app.infrastructure.api import admin_routers, dependencies
from app.infrastructure.db.seed_lesson_content import CURRICULUM, _content_id, seed
from tests.fakes import FakeTokenVerifier

ClientFactory = Callable[[object, object], TestClient]
ADMIN = "admin@example.com"
A = "/api/v1/admin"
FIRST_LESSON = _content_id(CURRICULUM[0]["lessons"][0]["slug"])


@pytest.fixture
def client(
    make_client: ClientFactory, db_path: Path, monkeypatch: pytest.MonkeyPatch
) -> TestClient:
    async def _seed() -> None:
        engine = create_async_engine(f"sqlite+aiosqlite:///{db_path}")
        async with AsyncSession(engine) as session:
            await seed(session)
            await session.commit()
        await engine.dispose()

    asyncio.run(_seed())
    settings = Settings(_env_file=None, admin_emails=ADMIN, environment="production")
    for module in (dependencies, admin_routers):
        monkeypatch.setattr(module, "get_settings", lambda: settings)
    return make_client(FakeTokenVerifier(subject="sub-admin", email=ADMIN), FakeTokenVerifier())


@pytest.fixture
def h(client: TestClient) -> dict[str, str]:
    token = client.post("/api/v1/auth/google", json={"id_token": "t"}).json()["session_token"]
    return {"Authorization": f"Bearer {token}"}


def _save_and_serve(client: TestClient, h: dict[str, str], body: dict[str, Any]) -> dict:
    created = client.post(f"{A}/lessons/{FIRST_LESSON}/exercises", json=body, headers=h)
    assert created.status_code == 201, created.json()
    exercise_id = created.json()["id"]
    lesson = client.get(f"/api/v1/lessons/{FIRST_LESSON}", headers=h)
    assert lesson.status_code == 200, lesson.json()
    return next(e for e in lesson.json()["exercises"] if e["id"] == exercise_id)


def test_tile_and_question_pronunciations_are_served(client: TestClient, h: dict) -> None:
    served = _save_and_serve(
        client,
        h,
        {
            "type": "multiple_choice",
            "prompt": "What does 'ቡና' mean?",
            "content": {
                "pronunciation": "bunna",
                "choices": [
                    {"id": "a", "text": "ቡና", "pronunciation": "bunna"},
                    {"id": "b", "text": "ሻይ"},
                ],
            },
            "answer_key": {"correct_choice_id": "a"},
        },
    )

    assert served["pronunciation"] == "bunna"
    assert served["choices"] == [
        {"id": "a", "text": "ቡና", "pronunciation": "bunna"},
        {"id": "b", "text": "ሻይ"},
    ]


def test_match_pairs_and_spell_tiles_serve_their_tiles_pronunciations(
    client: TestClient, h: dict
) -> None:
    pairs = _save_and_serve(
        client,
        h,
        {
            "type": "match_pairs",
            "prompt": "Match each word to its meaning",
            "content": {
                "left_tiles": [
                    {"id": "l1", "text": "ቡና", "pronunciation": "bunna"},
                    {"id": "l2", "text": "ሻይ", "pronunciation": "shay"},
                ],
                "right_tiles": [{"id": "r1", "text": "coffee"}, {"id": "r2", "text": "tea"}],
            },
            "answer_key": {"correct_pairs": [["l1", "r1"], ["l2", "r2"]]},
        },
    )
    spell = _save_and_serve(
        client,
        h,
        {
            "type": "spell_tiles",
            "prompt": "Spell 'coffee'",
            "content": {
                "tiles": [
                    {"id": "t1", "text": "ቡ", "pronunciation": "bu"},
                    {"id": "t2", "text": "ና", "pronunciation": "na"},
                ]
            },
            "answer_key": {"correct_sequence": ["t1", "t2"]},
        },
    )

    assert [t.get("pronunciation") for t in pairs["left_tiles"]] == ["bunna", "shay"]
    assert "pronunciation" not in pairs["right_tiles"][0]
    assert [t["pronunciation"] for t in spell["tiles"]] == ["bu", "na"]


def test_an_exercise_without_romanization_has_no_pronunciation_key(
    client: TestClient, h: dict
) -> None:
    served = _save_and_serve(
        client,
        h,
        {
            "type": "multiple_choice",
            "prompt": "How do you say 'tea'?",
            "content": {"choices": [{"id": "a", "text": "ሻይ"}, {"id": "b", "text": "ቡና"}]},
            "answer_key": {"correct_choice_id": "a"},
        },
    )

    assert "pronunciation" not in served
    assert served["choices"] == [{"id": "a", "text": "ሻይ"}, {"id": "b", "text": "ቡና"}]


def test_an_empty_pronunciation_is_refused_naming_the_field(client: TestClient, h: dict) -> None:
    response = client.post(
        f"{A}/lessons/{FIRST_LESSON}/exercises",
        json={
            "type": "multiple_choice",
            "prompt": "How do you say 'tea'?",
            "content": {
                "choices": [
                    {"id": "a", "text": "ሻይ", "pronunciation": ""},
                    {"id": "b", "text": "ቡና"},
                ]
            },
            "answer_key": {"correct_choice_id": "a"},
        },
        headers=h,
    )

    assert response.status_code == 422
    assert response.json()["details"]["field"] == "content.choices[0].pronunciation"
