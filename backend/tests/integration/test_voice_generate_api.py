"""Integration tests: `POST /api/v1/admin/voice/generate` (intent 027,
stories 008-011) over HTTP against a temp SQLite database. Addis is a fake
put in through `dependency_overrides`; nothing reaches the network and
nothing is stored."""

from __future__ import annotations

import asyncio
import logging
import sqlite3
from collections.abc import Callable
from pathlib import Path
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine

from app.config import Settings
from app.domain.lesson.exceptions import (
    VoiceCreditExhaustedError,
    VoiceLanguageMismatchError,
    VoiceNotConfiguredError,
    VoiceRateLimitedError,
    VoiceServiceFailedError,
    VoiceServiceTimeoutError,
    VoiceTextRejectedError,
)
from app.infrastructure.api import dependencies, voice_routers
from app.infrastructure.db.seed_lesson_content import CURRICULUM, _content_id, seed
from app.infrastructure.external.addis_voice_client import AddisClip
from tests.fakes import FakeTokenVerifier

ClientFactory = Callable[[object, object], TestClient]
ADMIN = "admin@example.com"
G = "/api/v1/admin/voice/generate"
LESSON = _content_id(CURRICULUM[0]["lessons"][0]["slug"])
MP3 = b"ID3\x04fake-mp3"
KEY = "sk_live-never-shown"
TEXT = "Maqaan koo Saaraa dha."


class FakeAddis:
    def __init__(self) -> None:
        self.calls: list[dict[str, Any]] = []
        self.error: Exception | None = None

    async def generate(self, text: str, *, voice_id: str, language: str, speed: int) -> AddisClip:
        self.calls.append(
            {"text": text, "voice_id": voice_id, "language": language, "speed": speed}
        )
        if self.error is not None:
            raise self.error
        name = "Bikila Tadesse" if voice_id == "om-bikila" else voice_id.split("-")[1].title()
        return AddisClip(MP3, 1.83, voice_id, name, len(text), 497.5)


@pytest.fixture
def addis() -> FakeAddis:
    return FakeAddis()


@pytest.fixture
def client(
    make_client: ClientFactory, db_path: Path, monkeypatch: pytest.MonkeyPatch, addis: FakeAddis
) -> TestClient:
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
            "VALUES (?, ?, ?, '2026-10-12')",
            [("am", "Amharic", "አማርኛ"), ("om", "Afaan Oromo", "Afaan Oromoo")],
        )
    monkeypatch.setattr(dependencies, "get_settings", lambda: Settings(admin_emails=ADMIN))
    monkeypatch.setattr(voice_routers, "get_settings", lambda: Settings(_env_file=None))
    client = make_client(FakeTokenVerifier(subject="sub-admin", email=ADMIN), FakeTokenVerifier())
    client.app.dependency_overrides[voice_routers.get_addis_voice_client] = lambda: addis
    return client


@pytest.fixture
def h(client: TestClient) -> dict[str, str]:
    token = client.post("/api/v1/auth/google", json={"id_token": "t"}).json()["session_token"]
    return {"Authorization": f"Bearer {token}"}


def _gen(client: TestClient, h: dict[str, str], **body: Any) -> Any:
    payload: dict[str, Any] = {"language": "om", "text": TEXT, "gender": "female"} | body
    return client.post(G, json={k: v for k, v in payload.items() if v is not None}, headers=h)


class TestATake:
    def test_an_mp3_with_its_voice_and_length(
        self, client: TestClient, h: dict[str, str], addis: FakeAddis
    ) -> None:
        response = _gen(client, h)

        assert response.status_code == 200, response.text
        assert response.headers["content-type"] == "audio/mpeg"
        assert response.content == MP3
        assert response.headers["x-voice-id"] == "om-obse"
        assert response.headers["x-voice-name"] == "Obse"
        assert response.headers["x-duration-seconds"] == "1.83"
        assert response.headers["x-credits-remaining"] == "497.5"
        assert response.headers["cache-control"] == "no-store"
        assert addis.calls == [{"text": TEXT, "voice_id": "om-obse", "language": "om", "speed": 50}]

    def test_the_saved_settings_are_used(
        self, client: TestClient, h: dict[str, str], addis: FakeAddis
    ) -> None:
        client.app.dependency_overrides[voice_routers.get_addis_voice_client] = lambda: None
        saved = client.put(
            "/api/v1/admin/voice/settings/om",
            json={"male_voice_id": "om-bikila", "female_voice_id": "om-hawi", "speed": 35},
            headers=h,
        )
        assert saved.status_code == 200, saved.text
        client.app.dependency_overrides[voice_routers.get_addis_voice_client] = lambda: addis

        response = _gen(client, h, gender="male")

        assert addis.calls[0]["voice_id"] == "om-bikila"
        assert addis.calls[0]["speed"] == 35
        assert response.headers["x-voice-name"] == "Bikila%20Tadesse"

    def test_try_it_overrides(
        self, client: TestClient, h: dict[str, str], addis: FakeAddis
    ) -> None:
        _gen(client, h, voice_id="om-leensaa", speed=80)

        assert (addis.calls[0]["voice_id"], addis.calls[0]["speed"]) == ("om-leensaa", 80)

    def test_a_lesson_s_course_language(
        self, client: TestClient, h: dict[str, str], addis: FakeAddis
    ) -> None:
        response = _gen(client, h, language=None, lesson_id=LESSON, text="ሰላም")

        assert response.status_code == 200, response.text
        assert addis.calls[0]["language"] == "am"
        assert addis.calls[0]["voice_id"] == "am-loza"

    def test_nothing_is_stored(self, client: TestClient, h: dict[str, str], db_path: Path) -> None:
        _gen(client, h)

        with sqlite3.connect(db_path) as conn:
            assert conn.execute("SELECT COUNT(*) FROM voice_settings").fetchone() == (0,)


class TestRefusedForFree:
    @pytest.mark.parametrize(
        ("body", "status", "field"),
        [
            ({"text": "  "}, 422, "text"),
            ({"text": "a" * 501}, 422, "text"),
            ({"speed": 101}, 422, "speed"),
            ({"voice_id": "am-loza"}, 422, "voice_id"),
            ({"language": "ti"}, 422, "language"),
            ({"lesson_id": LESSON}, 422, "language"),
            ({"language": None, "lesson_id": "nope"}, 404, None),
        ],
    )
    def test_bad_input(
        self,
        client: TestClient,
        h: dict[str, str],
        addis: FakeAddis,
        body: dict[str, Any],
        status: int,
        field: str | None,
    ) -> None:
        response = _gen(client, h, **body)

        assert response.status_code == status, response.text
        if field is not None:
            assert response.json()["details"]["field"] == field
        assert addis.calls == []

    @pytest.mark.parametrize("body", [{"gender": "other"}, {"speed": 40.5}, {"text": None}])
    def test_a_malformed_body(
        self, client: TestClient, h: dict[str, str], body: dict[str, Any]
    ) -> None:
        assert _gen(client, h, **body).status_code == 422


class TestAddisFailures:
    @pytest.mark.parametrize(
        ("error", "status", "code"),
        [
            (
                VoiceNotConfiguredError("The voice service refused this server's key"),
                503,
                "voice_not_configured",
            ),
            (
                VoiceCreditExhaustedError("The Addis AI credit has run out."),
                402,
                "voice_credit_exhausted",
            ),
            (
                VoiceRateLimitedError("Too many requests. Try again in a minute."),
                429,
                "voice_rate_limited",
            ),
            (
                VoiceServiceFailedError("The voice service failed. Try again."),
                502,
                "voice_service_failed",
            ),
            (
                VoiceServiceTimeoutError("The voice service didn't answer. Try again."),
                504,
                "voice_service_timeout",
            ),
            (
                VoiceTextRejectedError("The voice service couldn't read this text"),
                422,
                "invalid_content",
            ),
        ],
    )
    def test_each_failure_has_its_status_and_message(
        self,
        client: TestClient,
        h: dict[str, str],
        addis: FakeAddis,
        error: Exception,
        status: int,
        code: str,
    ) -> None:
        addis.error = error

        response = _gen(client, h)

        assert response.status_code == status
        assert response.json()["error_code"] == code
        assert response.json()["message"] == str(error)

    def test_a_mismatch_names_the_language(
        self, client: TestClient, h: dict[str, str], addis: FakeAddis
    ) -> None:
        addis.error = VoiceLanguageMismatchError(
            "Addis words", addis_code="VOICE_LANGUAGE_MISMATCH"
        )

        response = _gen(client, h)

        assert response.status_code == 422
        assert response.json()["message"] == "That voice doesn't speak Afaan Oromo"
        assert response.json()["details"] == {"field": "voice_id"}

    def test_without_a_key(self, client: TestClient, h: dict[str, str]) -> None:
        client.app.dependency_overrides[voice_routers.get_addis_voice_client] = lambda: None

        response = _gen(client, h)

        assert response.status_code == 503
        assert response.json()["message"] == "Generated voices aren't set up on this server."

    def test_no_secret_or_text_leaks(
        self,
        client: TestClient,
        h: dict[str, str],
        addis: FakeAddis,
        caplog: pytest.LogCaptureFixture,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        monkeypatch.setattr(
            voice_routers, "get_settings", lambda: Settings(_env_file=None, addis_api_key=KEY)
        )
        seen: list[str] = []
        with caplog.at_level(logging.DEBUG):
            seen.append(_gen(client, h).text)
            addis.error = VoiceCreditExhaustedError(
                "The Addis AI credit has run out.", addis_code="WALLET_EMPTY"
            )
            seen.append(_gen(client, h).text)

        everything = caplog.text + " ".join(seen)
        assert KEY not in everything
        assert TEXT not in caplog.text
        assert "WALLET_EMPTY" not in " ".join(seen)
        assert (
            "admin_voice_failed code=voice_credit_exhausted addis_code=WALLET_EMPTY" in caplog.text
        )


class TestAccess:
    def test_a_session_is_needed(self, client: TestClient) -> None:
        assert (
            client.post(G, json={"language": "om", "text": TEXT, "gender": "male"}).status_code
            == 401
        )

    def test_only_admins_may_use_it(
        self, make_client: ClientFactory, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        monkeypatch.setattr(dependencies, "get_settings", lambda: Settings(admin_emails=ADMIN))
        learner = make_client(
            FakeTokenVerifier(subject="sub-l", email="l@example.com"), FakeTokenVerifier()
        )
        token = learner.post("/api/v1/auth/google", json={"id_token": "t"}).json()["session_token"]

        response = learner.post(
            G,
            json={"language": "om", "text": TEXT, "gender": "male"},
            headers={"Authorization": f"Bearer {token}"},
        )

        assert response.status_code == 403
