"""Which browser origins the API answers: exactly what `CORS_ALLOWED_ORIGINS`
lists, where a `*` stands for one name (`https://*.vercel.app`), plus any
`http://localhost:<port>` in local development only. Nothing is allowed
beyond that by default.
"""

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

import app.main as main
from app.config import Settings

VERCEL = "https://*.vercel.app"


def _client(
    monkeypatch: pytest.MonkeyPatch, origins: str, environment: str = "production"
) -> TestClient:
    settings = Settings(_env_file=None, environment=environment, cors_allowed_origins=origins)
    monkeypatch.setattr(main, "get_settings", lambda: settings)
    return TestClient(main.create_app())


def _allowed(client: TestClient, origin: str) -> bool:
    response = client.options(
        "/health",
        headers={"Origin": origin, "Access-Control-Request-Method": "PUT"},
    )
    return response.headers.get("access-control-allow-origin") == origin


@pytest.mark.parametrize(
    "origin",
    [
        "https://admin-ethio-lang.vercel.app",
        "https://admin-ethio-lang-git-main-gutemag.vercel.app",
    ],
)
def test_a_wildcard_allows_every_site_under_it(
    monkeypatch: pytest.MonkeyPatch, origin: str
) -> None:
    assert _allowed(_client(monkeypatch, VERCEL), origin)


@pytest.mark.parametrize(
    "origin",
    [
        "http://admin-ethio-lang.vercel.app",  # not https
        "https://admin.vercel.app.evil.com",  # must match in full
        "https://evilvercel.app",
        "https://a.b.vercel.app",  # `*` is one name, not several
        "https://example.com",
        "http://localhost:5173",  # local development only
    ],
)
def test_a_wildcard_refuses_everything_else(monkeypatch: pytest.MonkeyPatch, origin: str) -> None:
    assert not _allowed(_client(monkeypatch, VERCEL), origin)


def test_nothing_is_allowed_when_unset(monkeypatch: pytest.MonkeyPatch) -> None:
    assert not _allowed(_client(monkeypatch, ""), "https://admin-ethio-lang.vercel.app")


def test_exact_and_wildcard_entries_mix(monkeypatch: pytest.MonkeyPatch) -> None:
    client = _client(monkeypatch, " https://buna.et/ , https://admin-ethio-lang*.vercel.app")
    assert _allowed(client, "https://buna.et")
    assert _allowed(client, "https://admin-ethio-lang-git-main.vercel.app")
    assert not _allowed(client, "https://someone-else.vercel.app")
    assert not _allowed(client, "https://www.buna.et")


def test_dots_in_an_entry_are_literal(monkeypatch: pytest.MonkeyPatch) -> None:
    client = _client(monkeypatch, VERCEL)
    assert not _allowed(client, "https://adminXvercel.app")
    assert not _allowed(client, "https://admin.vercelXapp")


def test_local_development_also_allows_any_localhost_port(monkeypatch: pytest.MonkeyPatch) -> None:
    client = _client(monkeypatch, VERCEL, environment="local")
    assert _allowed(client, "http://localhost:5173")
    assert _allowed(client, "http://localhost:61234")
    assert _allowed(client, "https://admin-ethio-lang.vercel.app")


def test_local_development_needs_no_setting_for_localhost(monkeypatch: pytest.MonkeyPatch) -> None:
    client = _client(monkeypatch, "", environment="local")
    assert _allowed(client, "http://localhost:5173")
    assert not _allowed(client, "https://admin-ethio-lang.vercel.app")
