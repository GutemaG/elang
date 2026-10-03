"""Integration tests (bolt 071, 022-light-and-dark-themes FR-8/FR-9):
`PATCH /api/v1/users/me/settings`, the session check's `settings`, and
`GET /api/v1/config`, via FastAPI's `TestClient` against a temp-file SQLite
database.

The real registries start empty, so each test lists its own keys by
swapping them into the registry, exactly as adding a line to
`app/domain/settings.py` would.
"""

from __future__ import annotations

import json
import sqlite3
from collections.abc import Callable
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app.domain.settings import ACCOUNT_SETTINGS, APP_CONFIG, Setting, SettingsRegistry
from tests.fakes import FakeTokenVerifier

ClientFactory = Callable[[object, object], TestClient]


def _register(monkeypatch: pytest.MonkeyPatch, registry: SettingsRegistry, *s: Setting) -> None:
    monkeypatch.setattr(registry, "_settings", {setting.key: setting for setting in s})


@pytest.fixture
def account_keys(monkeypatch: pytest.MonkeyPatch) -> None:
    _register(
        monkeypatch,
        ACCOUNT_SETTINGS,
        Setting("reduce_motion", "bool", False),
        Setting("theme", "str", "system", choices=("system", "light", "dark")),
    )


def _signed_in(make_client: ClientFactory, name: str) -> tuple[TestClient, dict[str, str]]:
    client = make_client(FakeTokenVerifier(subject=name), FakeTokenVerifier())
    response = client.post(
        "/api/v1/auth/google",
        json={
            "id_token": "whatever",
            "pending_selection": {"language": "am", "daily_goal_minutes": 10},
        },
    )
    assert response.status_code == 200
    return client, {"Authorization": f"Bearer {response.json()['session_token']}"}


def _session_settings(client: TestClient, headers: dict[str, str]) -> dict[str, object]:
    body = client.get("/api/v1/auth/session", headers=headers).json()
    assert body["valid"] is True
    settings: dict[str, object] = body["user"]["settings"]
    return settings


@pytest.mark.usefixtures("account_keys")
class TestAccountSettings:
    def test_a_new_account_reads_every_default(self, make_client: ClientFactory) -> None:
        client, headers = _signed_in(make_client, f"{__name__}-1")
        assert _session_settings(client, headers) == {"reduce_motion": False, "theme": "system"}

    def test_patch_merges_and_returns_the_full_map(self, make_client: ClientFactory) -> None:
        client, headers = _signed_in(make_client, f"{__name__}-2")

        first = client.patch("/api/v1/users/me/settings", json={"theme": "dark"}, headers=headers)
        second = client.patch(
            "/api/v1/users/me/settings", json={"reduce_motion": True}, headers=headers
        )

        assert first.status_code == 200
        assert first.json() == {"settings": {"reduce_motion": False, "theme": "dark"}}
        assert second.json() == {"settings": {"reduce_motion": True, "theme": "dark"}}
        assert _session_settings(client, headers) == {"reduce_motion": True, "theme": "dark"}

    @pytest.mark.parametrize(
        "changes",
        [
            {"unknown": True},
            {"theme": "sepia"},
            {"reduce_motion": "yes"},
            {"theme": "dark", "unknown": 1},
        ],
    )
    def test_a_bad_update_is_refused_and_nothing_is_saved(
        self, make_client: ClientFactory, changes: dict[str, object]
    ) -> None:
        client, headers = _signed_in(make_client, f"{__name__}-3")

        response = client.patch("/api/v1/users/me/settings", json=changes, headers=headers)

        assert response.status_code == 422
        assert response.json()["error_code"] == "invalid_setting"
        assert _session_settings(client, headers) == {"reduce_motion": False, "theme": "system"}

    def test_the_body_must_be_a_map(self, make_client: ClientFactory) -> None:
        client, headers = _signed_in(make_client, f"{__name__}-4")
        response = client.patch("/api/v1/users/me/settings", json=["theme"], headers=headers)
        assert response.status_code == 422

    def test_sign_in_is_required(self, make_client: ClientFactory) -> None:
        client = make_client(FakeTokenVerifier(), FakeTokenVerifier())
        response = client.patch("/api/v1/users/me/settings", json={"theme": "dark"})
        assert response.status_code == 401

    def test_a_key_added_later_reads_for_an_existing_account(
        self, make_client: ClientFactory, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        # Story 007: no migration, seed or backfill for a new setting.
        client, headers = _signed_in(make_client, f"{__name__}-5")
        client.patch("/api/v1/users/me/settings", json={"theme": "light"}, headers=headers)

        _register(
            monkeypatch,
            ACCOUNT_SETTINGS,
            Setting("theme", "str", "system", choices=("system", "light", "dark")),
            Setting("daily_tip", "bool", True),
        )

        assert _session_settings(client, headers) == {"theme": "light", "daily_tip": True}


def _write_config(db_path: Path, key: str, value: object) -> None:
    with sqlite3.connect(db_path) as conn:
        conn.execute(
            "INSERT INTO app_config (key, value, updated_at) VALUES (?, ?, '2026-09-30') "
            "ON CONFLICT(key) DO UPDATE SET value = excluded.value",
            (key, json.dumps(value)),
        )


class TestAppConfig:
    @pytest.fixture(autouse=True)
    def _config_keys(self, monkeypatch: pytest.MonkeyPatch) -> None:
        _register(
            monkeypatch,
            APP_CONFIG,
            Setting("max_beans", "int", 5),
            Setting("maintenance", "bool", False),
        )

    def test_no_rows_is_every_default_with_no_sign_in(self, make_client: ClientFactory) -> None:
        client = make_client(FakeTokenVerifier(), FakeTokenVerifier())
        response = client.get("/api/v1/config")
        assert response.status_code == 200
        assert response.json() == {"config": {"max_beans": 5, "maintenance": False}}

    def test_a_written_row_changes_the_value(
        self, make_client: ClientFactory, db_path: Path
    ) -> None:
        client = make_client(FakeTokenVerifier(), FakeTokenVerifier())
        _write_config(db_path, "max_beans", 7)

        assert client.get("/api/v1/config").json()["config"]["max_beans"] == 7

    def test_a_bad_row_reads_as_the_default(
        self, make_client: ClientFactory, db_path: Path
    ) -> None:
        client = make_client(FakeTokenVerifier(), FakeTokenVerifier())
        _write_config(db_path, "max_beans", "seven")
        _write_config(db_path, "retired_key", 1)

        assert client.get("/api/v1/config").json() == {
            "config": {"max_beans": 5, "maintenance": False}
        }


def test_with_the_real_registries_the_league_switch_and_app_language_are_listed(
    make_client: ClientFactory,
) -> None:
    # Bolt 073 (023-weekly-leagues) added the first account setting, bolt
    # 077 (024-app-localization) the app language.
    client, headers = _signed_in(make_client, f"{__name__}-6")
    assert _session_settings(client, headers) == {"show_in_leagues": True, "app_language": ""}
    assert client.get("/api/v1/config").json() == {
        "config": {
            "min_build_android": 0,
            "min_build_ios": 0,
            "latest_build_ios": 0,
            "ios_store_url": "",
        }
    }


class TestAppLanguage:
    """024-app-localization, story 001: the app language is kept on the
    account through the real registry, with no migration."""

    def test_is_saved_returned_and_read_back_at_the_session_check(
        self, make_client: ClientFactory
    ) -> None:
        client, headers = _signed_in(make_client, f"{__name__}-7")

        response = client.patch(
            "/api/v1/users/me/settings", json={"app_language": "am"}, headers=headers
        )

        assert response.status_code == 200
        assert response.json() == {"settings": {"show_in_leagues": True, "app_language": "am"}}
        assert _session_settings(client, headers)["app_language"] == "am"

    def test_leaves_the_other_settings_alone(self, make_client: ClientFactory) -> None:
        client, headers = _signed_in(make_client, f"{__name__}-8")
        client.patch("/api/v1/users/me/settings", json={"show_in_leagues": False}, headers=headers)

        client.patch("/api/v1/users/me/settings", json={"app_language": "om"}, headers=headers)

        assert _session_settings(client, headers) == {
            "show_in_leagues": False,
            "app_language": "om",
        }

    @pytest.mark.parametrize("code", ["", "sid"])
    def test_takes_any_short_code_and_can_be_cleared(
        self, make_client: ClientFactory, code: str
    ) -> None:
        client, headers = _signed_in(make_client, f"{__name__}-9-{code}")
        client.patch("/api/v1/users/me/settings", json={"app_language": "am"}, headers=headers)

        response = client.patch(
            "/api/v1/users/me/settings", json={"app_language": code}, headers=headers
        )

        assert response.status_code == 200
        assert _session_settings(client, headers)["app_language"] == code

    @pytest.mark.parametrize("value", ["AM", "amharic", "a", None, 3])
    def test_a_bad_code_is_refused_and_nothing_is_saved(
        self, make_client: ClientFactory, value: object
    ) -> None:
        client, headers = _signed_in(make_client, f"{__name__}-10")
        client.patch("/api/v1/users/me/settings", json={"app_language": "am"}, headers=headers)

        response = client.patch(
            "/api/v1/users/me/settings",
            json={"app_language": value, "show_in_leagues": False},
            headers=headers,
        )

        assert response.status_code == 422
        assert response.json()["error_code"] == "invalid_setting"
        assert _session_settings(client, headers) == {
            "show_in_leagues": True,
            "app_language": "am",
        }
