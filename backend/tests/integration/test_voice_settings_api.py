"""Integration tests: the voice settings admin API (intent 027, stories 002
and 003), over HTTP against a temp SQLite database."""

from __future__ import annotations

import logging
import sqlite3
from collections.abc import Callable
from pathlib import Path
from typing import Any

import pytest
from fastapi.testclient import TestClient

from app.config import Settings
from app.infrastructure.api import dependencies, voice_routers
from tests.fakes import FakeTokenVerifier

ClientFactory = Callable[[object, object], TestClient]
ADMIN = "admin@example.com"
S = "/api/v1/admin/voice/settings"


@pytest.fixture
def client(
    make_client: ClientFactory, db_path: Path, monkeypatch: pytest.MonkeyPatch
) -> TestClient:
    with sqlite3.connect(db_path) as conn:
        conn.executemany(
            "INSERT INTO languages (code, name, native_name, created_at) "
            "VALUES (?, ?, ?, '2026-10-12')",
            [("am", "Amharic", "አማርኛ"), ("om", "Afaan Oromo", "Afaan Oromoo")],
        )
    monkeypatch.setattr(dependencies, "get_settings", lambda: Settings(admin_emails=ADMIN))
    # Not the developer's backend/.env: no Addis key unless a test sets one.
    monkeypatch.setattr(voice_routers, "get_settings", lambda: Settings(_env_file=None))
    return make_client(FakeTokenVerifier(subject="sub-admin", email=ADMIN), FakeTokenVerifier())


@pytest.fixture
def h(client: TestClient) -> dict[str, str]:
    token = client.post("/api/v1/auth/google", json={"id_token": "t"}).json()["session_token"]
    return {"Authorization": f"Bearer {token}"}


def _put(client: TestClient, h: dict[str, str], language: str, **body: Any) -> Any:
    payload = {"male_voice_id": f"{language}-a", "female_voice_id": f"{language}-b", "speed": 50}
    return client.put(f"{S}/{language}", json={**payload, **body}, headers=h)


class TestReading:
    def test_defaults_with_names_before_anything_is_saved(
        self, client: TestClient, h: dict[str, str]
    ) -> None:
        response = client.get(S, headers=h)

        assert response.status_code == 200, response.text
        assert response.json() == {
            "configured": False,
            "languages": [
                {
                    "language": "am",
                    "language_name": "Amharic",
                    "male_voice_id": "am-yohanes-calm",
                    "female_voice_id": "am-loza",
                    "speed": 50,
                    "updated_by": None,
                    "updated_at": None,
                },
                {
                    "language": "om",
                    "language_name": "Afaan Oromo",
                    "male_voice_id": "om-diriba",
                    "female_voice_id": "om-obse",
                    "speed": 50,
                    "updated_by": None,
                    "updated_at": None,
                },
            ],
        }

    def test_a_language_missing_from_the_languages_table_shows_its_code(
        self, client: TestClient, h: dict[str, str], db_path: Path
    ) -> None:
        with sqlite3.connect(db_path) as conn:
            conn.execute("DELETE FROM languages WHERE code = 'om'")

        languages = client.get(S, headers=h).json()["languages"]

        assert languages[1]["language_name"] == "om"

    def test_configured_follows_the_server(self, client: TestClient, h: dict[str, str]) -> None:
        client.app.dependency_overrides[voice_routers.voice_generation_configured] = lambda: True

        assert client.get(S, headers=h).json()["configured"] is True

    @pytest.mark.parametrize(("key", "configured"), [("sk_test", True), ("  ", False), ("", False)])
    def test_configured_when_an_addis_key_is_set(
        self,
        client: TestClient,
        h: dict[str, str],
        monkeypatch: pytest.MonkeyPatch,
        key: str,
        configured: bool,
    ) -> None:
        monkeypatch.setattr(
            voice_routers, "get_settings", lambda: Settings(_env_file=None, addis_api_key=key)
        )

        body = client.get(S, headers=h).json()

        assert body["configured"] is configured
        assert key.strip() == "" or key not in str(body)


def test_the_client_is_built_only_with_a_key(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(voice_routers, "get_settings", lambda: Settings(_env_file=None))
    assert voice_routers.get_addis_voice_client() is None

    monkeypatch.setattr(
        voice_routers,
        "get_settings",
        lambda: Settings(_env_file=None, addis_api_key=" sk_test ", addis_timeout_seconds=5),
    )
    assert voice_routers.get_addis_voice_client() is not None


class TestSaving:
    def test_a_save_is_returned_and_read_back(self, client: TestClient, h: dict[str, str]) -> None:
        response = _put(
            client, h, "om", male_voice_id="om-bikila", female_voice_id=" om-hawi ", speed=40
        )

        assert response.status_code == 200, response.text
        saved = response.json()
        assert saved["language_name"] == "Afaan Oromo"
        assert (saved["male_voice_id"], saved["female_voice_id"], saved["speed"]) == (
            "om-bikila",
            "om-hawi",
            40,
        )
        assert saved["updated_by"] == ADMIN
        assert saved["updated_at"] is not None
        assert client.get(S, headers=h).json()["languages"][1] == saved

    def test_saving_one_language_leaves_the_other_alone(
        self, client: TestClient, h: dict[str, str]
    ) -> None:
        assert _put(client, h, "am", speed=30).status_code == 200

        om = client.get(S, headers=h).json()["languages"][1]

        assert (om["male_voice_id"], om["speed"], om["updated_by"]) == ("om-diriba", 50, None)

    def test_each_save_is_logged(
        self, client: TestClient, h: dict[str, str], caplog: pytest.LogCaptureFixture
    ) -> None:
        with caplog.at_level(logging.INFO, logger="app.admin"):
            _put(client, h, "am")

        assert f"admin_write action=update entity=voice_settings id=am admin={ADMIN}" in caplog.text


class TestRefusing:
    def test_a_language_without_voices(self, client: TestClient, h: dict[str, str]) -> None:
        response = _put(client, h, "ti")

        assert response.status_code == 404
        assert response.json()["details"] == {"entity": "voice_settings", "id": "ti"}

    @pytest.mark.parametrize("speed", [-1, 101])
    def test_a_speed_outside_0_to_100(
        self, client: TestClient, h: dict[str, str], speed: int
    ) -> None:
        response = _put(client, h, "am", speed=speed)

        assert response.status_code == 422
        assert response.json()["details"]["field"] == "speed"

    @pytest.mark.parametrize("speed", [40.5, "40"])
    def test_a_speed_that_is_not_a_whole_number(
        self, client: TestClient, h: dict[str, str], speed: object
    ) -> None:
        assert _put(client, h, "am", speed=speed).status_code == 422

    @pytest.mark.parametrize(
        ("field", "voice"),
        [("male_voice_id", "am-yohanes-calm"), ("female_voice_id", "om-"), ("male_voice_id", "")],
    )
    def test_a_voice_that_is_not_the_language_s(
        self, client: TestClient, h: dict[str, str], field: str, voice: str
    ) -> None:
        response = _put(client, h, "om", **{field: voice})

        assert response.status_code == 422
        body = response.json()
        assert body["details"]["field"] == field
        assert body["message"] == "That is not a voice for Afaan Oromo"

    def test_nothing_is_saved_when_refused(self, client: TestClient, h: dict[str, str]) -> None:
        _put(client, h, "om", male_voice_id="am-simon", speed=10)

        assert client.get(S, headers=h).json()["languages"][1]["updated_by"] is None


class TestAccess:
    def test_a_session_is_needed(self, client: TestClient) -> None:
        assert client.get(S).status_code == 401
        assert client.put(f"{S}/am", json={}).status_code == 401

    def test_only_admins_may_use_it(
        self, make_client: ClientFactory, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        monkeypatch.setattr(dependencies, "get_settings", lambda: Settings(admin_emails=ADMIN))
        learner = make_client(
            FakeTokenVerifier(subject="sub-l", email="l@example.com"), FakeTokenVerifier()
        )
        token = learner.post("/api/v1/auth/google", json={"id_token": "t"}).json()["session_token"]
        lh = {"Authorization": f"Bearer {token}"}

        assert learner.get(S, headers=lh).status_code == 403
        assert _put(learner, lh, "am").status_code == 403
