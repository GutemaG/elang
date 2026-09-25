"""Integration tests: picture questions over HTTP (story
001-picture-question-content-types, bolt 050-image-choice-service). An admin
saves `image_choice` and `audio_image_choice` questions; the lesson API and
practice return them unchanged; bad ones are refused naming the field.
Against a temp SQLite database holding the real seeded content.
"""

from __future__ import annotations

import asyncio
from collections.abc import Callable
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.orm import Session as SyncSession

from app.config import Settings
from app.infrastructure.api import admin_routers, dependencies
from app.infrastructure.db.lesson_models import (
    ExerciseModel,
    UserVocabProgressModel,
    VocabItemModel,
)
from app.infrastructure.db.seed_lesson_content import CURRICULUM, _content_id, seed
from tests.fakes import EN_AM_COURSE_ID, FakeTokenVerifier

ClientFactory = Callable[[object, object], TestClient]
ADMIN = "admin@example.com"
A = "/api/v1/admin"
FIRST_LESSON = _content_id(CURRICULUM[0]["lessons"][0]["slug"])
CLIP = "https://pub-abc.r2.dev/am/lesson/0123456789ab.m4a"


def _pictures(count: int, *, local: bool = False) -> list[dict[str, str]]:
    names = ["coffee", "tea", "water", "bread"]
    return [
        {
            "id": f"p{i}",
            "image_url": (
                f"/media/images/am/{FIRST_LESSON}/{i:012x}.webp"
                if local
                else f"https://pub-abc.r2.dev/am/{FIRST_LESSON}/{i:012x}.webp"
            ),
            "alt_text": f"A picture of {names[i]}",
        }
        for i in range(count)
    ]


def _body(exercise_type: str, count: int = 4, **overrides: Any) -> dict[str, Any]:
    content: dict[str, Any] = {"choices": _pictures(count)}
    if exercise_type == "audio_image_choice":
        content["audio_url"] = CLIP
    return {
        "type": exercise_type,
        "prompt": "ቡና" if exercise_type == "image_choice" else "Tap what you hear",
        "content": content,
        "answer_key": {"correct_choice_id": "p0"},
        **overrides,
    }


@pytest.fixture
def seeded(db_path: Path) -> Path:
    async def _seed() -> None:
        engine = create_async_engine(f"sqlite+aiosqlite:///{db_path}")
        async with AsyncSession(engine) as session:
            await seed(session)
            await session.commit()
        await engine.dispose()

    asyncio.run(_seed())
    return db_path


@pytest.fixture
def use_environment(monkeypatch: pytest.MonkeyPatch) -> Callable[[str], None]:
    def _use(environment: str) -> None:
        settings = Settings(_env_file=None, admin_emails=ADMIN, environment=environment)
        for module in (dependencies, admin_routers):
            monkeypatch.setattr(module, "get_settings", lambda: settings)

    _use("production")
    return _use


@pytest.fixture
def client(
    make_client: ClientFactory, seeded: Path, use_environment: Callable[[str], None]
) -> TestClient:
    return make_client(FakeTokenVerifier(subject="sub-admin", email=ADMIN), FakeTokenVerifier())


@pytest.fixture
def h(client: TestClient) -> dict[str, str]:
    token = client.post("/api/v1/auth/google", json={"id_token": "t"}).json()["session_token"]
    return {"Authorization": f"Bearer {token}"}


def _create(client: TestClient, h: dict[str, str], body: dict[str, Any]) -> Any:
    return client.post(f"{A}/lessons/{FIRST_LESSON}/exercises", json=body, headers=h)


def _learner_view(client: TestClient, h: dict[str, str], exercise_id: str) -> dict[str, Any]:
    response = client.get(f"/api/v1/lessons/{FIRST_LESSON}", headers=h)
    assert response.status_code == 200, response.json()
    return next(e for e in response.json()["exercises"] if e["id"] == exercise_id)


class TestSavingAndServing:
    @pytest.mark.parametrize("count", [2, 3, 4])
    def test_image_choice_saves_and_the_lesson_serves_it_unchanged(
        self, client: TestClient, h: dict, count: int
    ) -> None:
        body = _body("image_choice", count)

        created = _create(client, h, body)

        assert created.status_code == 201, created.json()
        saved = created.json()
        assert {k: saved[k] for k in body} == body
        served = _learner_view(client, h, saved["id"])
        assert served == {
            "id": saved["id"],
            "order_index": saved["order_index"],
            "type": "image_choice",
            "prompt": "ቡና",
            "choices": body["content"]["choices"],
            "correct_choice_id": "p0",
        }

    @pytest.mark.parametrize("count", [2, 3, 4])
    def test_audio_image_choice_saves_and_the_lesson_serves_it_unchanged(
        self, client: TestClient, h: dict, count: int
    ) -> None:
        body = _body("audio_image_choice", count)

        created = _create(client, h, body)

        assert created.status_code == 201, created.json()
        served = _learner_view(client, h, created.json()["id"])
        assert served["type"] == "audio_image_choice"
        assert served["prompt"] == "Tap what you hear"
        assert served["audio_url"] == CLIP
        assert served["choices"] == body["content"]["choices"]
        assert served["correct_choice_id"] == "p0"

    @pytest.mark.parametrize("exercise_type", ["image_choice", "audio_image_choice"])
    def test_an_edit_round_trips(self, client: TestClient, h: dict, exercise_type: str) -> None:
        exercise_id = _create(client, h, _body(exercise_type)).json()["id"]
        edited = _body(exercise_type, 3, answer_key={"correct_choice_id": "p2"})
        edited["content"]["choices"][1]["alt_text"] = "A glass of tea"

        response = client.put(f"{A}/exercises/{exercise_id}", json=edited, headers=h)

        assert response.status_code == 200, response.json()
        listed = client.get(f"{A}/lessons/{FIRST_LESSON}/exercises", headers=h).json()
        row = next(e for e in listed["exercises"] if e["id"] == exercise_id)
        assert {k: row[k] for k in edited} == edited

    def test_the_tree_shows_the_audio_questions_clip(self, client: TestClient, h: dict) -> None:
        exercise_id = _create(client, h, _body("audio_image_choice")).json()["id"]
        picture_id = _create(client, h, _body("image_choice")).json()["id"]

        tree = client.get(f"{A}/courses/{EN_AM_COURSE_ID}/tree", headers=h).json()
        exercises = {
            e["id"]: e
            for s in tree["sections"]
            for k in s["skills"]
            for lesson in k["lessons"]
            for e in lesson["exercises"]
        }
        assert exercises[exercise_id]["audio"] == "hosted"
        assert exercises[picture_id]["audio"] is None


class TestRefusals:
    @pytest.mark.parametrize(
        ("exercise_type", "change", "field"),
        [
            (
                "image_choice",
                lambda b: b["content"].update(choices=_pictures(1)),
                "content.choices",
            ),
            (
                "image_choice",
                lambda b: b["content"]["choices"].append(_pictures(1)[0]),
                "content.choices",
            ),
            (
                "image_choice",
                lambda b: b["content"]["choices"][2].update(id="p0"),
                "content.choices[2].id",
            ),
            (
                "image_choice",
                lambda b: b["content"]["choices"][1].update(alt_text=" "),
                "content.choices[1].alt_text",
            ),
            (
                "image_choice",
                lambda b: b["content"]["choices"][3].pop("image_url"),
                "content.choices[3].image_url",
            ),
            (
                "audio_image_choice",
                lambda b: b["content"].pop("audio_url"),
                "content.audio_url",
            ),
            (
                "audio_image_choice",
                lambda b: b["answer_key"].update(correct_choice_id="p7"),
                "answer_key.correct_choice_id",
            ),
        ],
    )
    def test_a_broken_question_is_refused_naming_the_field(
        self,
        client: TestClient,
        h: dict,
        exercise_type: str,
        change: Callable[[dict[str, Any]], Any],
        field: str,
    ) -> None:
        body = _body(exercise_type)
        change(body)

        response = _create(client, h, body)

        assert response.status_code == 422
        assert response.json()["error_code"] == "invalid_exercise"
        assert response.json()["details"] == {"field": field}

    def test_local_pictures_save_only_in_local_development(
        self, client: TestClient, h: dict, use_environment: Callable[[str], None]
    ) -> None:
        body = _body("image_choice")
        body["content"]["choices"] = _pictures(2, local=True)

        refused = _create(client, h, body)
        assert refused.status_code == 422
        assert refused.json()["details"] == {"field": "content.choices[0].image_url"}

        use_environment("local")
        saved = _create(client, h, body)
        assert saved.status_code == 201, saved.json()
        served = _learner_view(client, h, saved.json()["id"])
        assert served["choices"][0]["image_url"].startswith("/media/images/")


class TestPractice:
    def test_a_due_word_whose_question_is_a_picture_question_is_practised_with_it(
        self, client: TestClient, h: dict, seeded: Path
    ) -> None:
        # The admin API cannot link a word (the seed does, in bolt 051), so
        # the link is made in the database, as the seed would make it.
        body = _body("image_choice", 2)
        created = _create(client, h, body)
        assert created.status_code == 201, created.json()
        user_id = client.post("/api/v1/auth/google", json={"id_token": "t"}).json()["user"]["id"]
        engine = create_engine(f"sqlite:///{seeded}")
        with SyncSession(engine) as session:
            session.add(
                VocabItemModel(
                    id="vocab-buna", course_id=EN_AM_COURSE_ID, word="ቡና", translation="Coffee"
                )
            )
            session.add(
                UserVocabProgressModel(
                    user_id=user_id,
                    vocab_item_id="vocab-buna",
                    box_level=1,
                    next_review_at=datetime.now(UTC) - timedelta(hours=1),
                    last_seen_at=datetime.now(UTC) - timedelta(days=1),
                )
            )
            session.flush()
            exercise = session.get(ExerciseModel, created.json()["id"])
            assert exercise is not None
            exercise.vocab_item_id = "vocab-buna"
            session.commit()
        engine.dispose()

        response = client.get("/api/v1/practice/due-items", headers=h)

        assert response.status_code == 200
        items = [i for i in response.json()["items"] if i["vocab_item_id"] == "vocab-buna"]
        assert len(items) == 1
        assert items[0]["word"] == "ቡና"
        assert items[0]["exercise"]["id"] == created.json()["id"]
        assert items[0]["exercise"]["type"] == "image_choice"
        assert items[0]["exercise"]["choices"] == body["content"]["choices"]
