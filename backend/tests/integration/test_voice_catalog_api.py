"""Integration tests: the voice catalog and credit routes, and the catalog
check on saving settings (intent 027, stories 006 and 007). Addis is a
fake client put in through `dependency_overrides`; nothing reaches the
network."""

from __future__ import annotations

import logging
import sqlite3
from collections.abc import Callable
from pathlib import Path
from typing import Any

import pytest
from fastapi.testclient import TestClient

from app.application.voice_use_cases import VoiceCatalog
from app.config import Settings
from app.domain.lesson.exceptions import VoiceServiceFailedError
from app.infrastructure.api import dependencies, voice_routers
from app.infrastructure.external.addis_voice_client import AddisUsage, AddisVoice
from tests.fakes import FakeTokenVerifier

ClientFactory = Callable[[object, object], TestClient]
ADMIN = "admin@example.com"
V = "/api/v1/admin/voice"


def _voice(vid: str, gender: str, *, available: bool = True, order: int = 0) -> AddisVoice:
    return AddisVoice(
        id=vid,
        name=vid.split("-")[1].title(),
        descriptor=f"{vid} descriptor",
        gender=gender,
        style="Narration",
        preview_audio_url=f"https://cdn.addisassistant.com/voice-previews/{vid}.mp3",
        is_available=available,
        sort_order=order,
    )


class FakeAddis:
    def __init__(self) -> None:
        self.voices = {
            "om": [
                _voice("om-obse", "female", order=80),
                _voice("om-diriba", "male", order=50),
                _voice("om-retired", "male", available=False, order=10),
                _voice("om-hawi", "female", order=30),
            ],
            "am": [_voice("am-yohanes-calm", "male"), _voice("am-loza", "female")],
        }
        self.calls: list[str] = []
        self.fail = False

    async def list_voices(self, language: str) -> list[AddisVoice]:
        self.calls.append(language)
        if self.fail:
            raise VoiceServiceFailedError("The voice service failed. Try again.")
        return self.voices.get(language, [])

    async def usage(self) -> AddisUsage:
        if self.fail:
            raise VoiceServiceFailedError("The voice service failed. Try again.")
        return AddisUsage(997.5277, "ETB", "Br 997.53", 2.5, 5000)


@pytest.fixture
def addis() -> FakeAddis:
    return FakeAddis()


@pytest.fixture
def client(
    make_client: ClientFactory, db_path: Path, monkeypatch: pytest.MonkeyPatch, addis: FakeAddis
) -> TestClient:
    with sqlite3.connect(db_path) as conn:
        conn.executemany(
            "INSERT INTO languages (code, name, native_name, created_at) "
            "VALUES (?, ?, ?, '2026-10-12')",
            [("am", "Amharic", "አማርኛ"), ("om", "Afaan Oromo", "Afaan Oromoo")],
        )
    monkeypatch.setattr(dependencies, "get_settings", lambda: Settings(admin_emails=ADMIN))
    monkeypatch.setattr(voice_routers, "get_settings", lambda: Settings(_env_file=None))
    # A fresh cache per test: the real one lives as long as the process.
    monkeypatch.setattr(voice_routers, "voice_catalog", VoiceCatalog())
    client = make_client(FakeTokenVerifier(subject="sub-admin", email=ADMIN), FakeTokenVerifier())
    client.app.dependency_overrides[voice_routers.get_addis_voice_client] = lambda: addis
    return client


@pytest.fixture
def h(client: TestClient) -> dict[str, str]:
    token = client.post("/api/v1/auth/google", json={"id_token": "t"}).json()["session_token"]
    return {"Authorization": f"Bearer {token}"}


def _no_addis(client: TestClient) -> None:
    client.app.dependency_overrides[voice_routers.get_addis_voice_client] = lambda: None


class TestVoices:
    def test_available_voices_in_addis_order(self, client: TestClient, h: dict[str, str]) -> None:
        response = client.get(f"{V}/voices", params={"language": "om"}, headers=h)

        assert response.status_code == 200, response.text
        body = response.json()
        assert body["language"] == "om"
        assert [v["id"] for v in body["voices"]] == ["om-hawi", "om-diriba", "om-obse"]
        assert body["voices"][0] == {
            "id": "om-hawi",
            "name": "Hawi",
            "descriptor": "om-hawi descriptor",
            "gender": "female",
            "style": "Narration",
            "preview_audio_url": "https://cdn.addisassistant.com/voice-previews/om-hawi.mp3",
        }

    def test_two_calls_make_one_addis_call(
        self, client: TestClient, h: dict[str, str], addis: FakeAddis
    ) -> None:
        for _ in range(2):
            client.get(f"{V}/voices", params={"language": "om"}, headers=h)

        assert addis.calls == ["om"]

    def test_a_language_without_voices(self, client: TestClient, h: dict[str, str]) -> None:
        response = client.get(f"{V}/voices", params={"language": "ti"}, headers=h)

        assert response.status_code == 422
        assert response.json()["details"]["field"] == "language"

    def test_the_language_is_required(self, client: TestClient, h: dict[str, str]) -> None:
        assert client.get(f"{V}/voices", headers=h).status_code == 422

    def test_without_a_key(self, client: TestClient, h: dict[str, str]) -> None:
        _no_addis(client)

        response = client.get(f"{V}/voices", params={"language": "om"}, headers=h)

        assert response.status_code == 503
        assert response.json()["error_code"] == "voice_not_configured"

    def test_when_addis_fails(
        self, client: TestClient, h: dict[str, str], addis: FakeAddis
    ) -> None:
        addis.fail = True

        response = client.get(f"{V}/voices", params={"language": "om"}, headers=h)

        assert response.status_code == 502
        assert response.json()["error_code"] == "voice_service_failed"


class TestUsage:
    def test_the_credit_left(self, client: TestClient, h: dict[str, str]) -> None:
        response = client.get(f"{V}/usage", headers=h)

        assert response.status_code == 200, response.text
        assert response.json() == {
            "balance": 997.5277,
            "currency": "ETB",
            "formatted_balance": "Br 997.53",
            "price_per_minute": 2.5,
            "max_characters": 5000,
        }

    def test_without_a_key(self, client: TestClient, h: dict[str, str]) -> None:
        _no_addis(client)

        assert client.get(f"{V}/usage", headers=h).status_code == 503

    def test_when_addis_fails(
        self, client: TestClient, h: dict[str, str], addis: FakeAddis
    ) -> None:
        addis.fail = True

        assert client.get(f"{V}/usage", headers=h).status_code == 502


class TestSavingChecksTheCatalog:
    def _put(self, client: TestClient, h: dict[str, str], male: str, female: str) -> Any:
        return client.put(
            f"{V}/settings/om",
            json={"male_voice_id": male, "female_voice_id": female, "speed": 45},
            headers=h,
        )

    def test_offered_voices_are_saved(self, client: TestClient, h: dict[str, str]) -> None:
        response = self._put(client, h, "om-diriba", "om-hawi")

        assert response.status_code == 200, response.text

    @pytest.mark.parametrize(
        ("male", "female", "field"),
        [
            ("om-ghost", "om-obse", "male_voice_id"),
            ("om-retired", "om-obse", "male_voice_id"),
            ("om-diriba", "om-diriba", "female_voice_id"),
        ],
    )
    def test_a_voice_not_offered_is_refused(
        self, client: TestClient, h: dict[str, str], male: str, female: str, field: str
    ) -> None:
        response = self._put(client, h, male, female)

        assert response.status_code == 422
        assert response.json()["details"]["field"] == field

    def test_when_addis_is_down_the_save_goes_ahead(
        self,
        client: TestClient,
        h: dict[str, str],
        addis: FakeAddis,
        caplog: pytest.LogCaptureFixture,
    ) -> None:
        addis.fail = True

        with caplog.at_level(logging.INFO, logger="app.admin"):
            response = self._put(client, h, "om-ghost", "om-obse")

        assert response.status_code == 200
        assert "voice_catalog_unchecked language=om" in caplog.text

    def test_without_a_key_only_the_prefix_is_checked(
        self, client: TestClient, h: dict[str, str], addis: FakeAddis
    ) -> None:
        _no_addis(client)

        response = self._put(client, h, "om-ghost", "om-obse")

        assert response.status_code == 200
        assert addis.calls == []


class TestAccess:
    def test_a_session_is_needed(self, client: TestClient) -> None:
        assert client.get(f"{V}/voices", params={"language": "om"}).status_code == 401
        assert client.get(f"{V}/usage").status_code == 401

    def test_only_admins_may_use_it(
        self, make_client: ClientFactory, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        monkeypatch.setattr(dependencies, "get_settings", lambda: Settings(admin_emails=ADMIN))
        learner = make_client(
            FakeTokenVerifier(subject="sub-l", email="l@example.com"), FakeTokenVerifier()
        )
        token = learner.post("/api/v1/auth/google", json={"id_token": "t"}).json()["session_token"]
        lh = {"Authorization": f"Bearer {token}"}

        assert learner.get(f"{V}/voices", params={"language": "om"}, headers=lh).status_code == 403
        assert learner.get(f"{V}/usage", headers=lh).status_code == 403
