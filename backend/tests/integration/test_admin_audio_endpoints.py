"""Integration tests: the admin audio endpoints (story
005-audio-upload-and-link-api, bolt 036-admin-audio-api), over HTTP. The R2
storage and the link checker are replaced through the router's dependency
hooks, so nothing leaves the machine.
"""

from __future__ import annotations

import asyncio
import logging
import re
from collections.abc import Callable
from pathlib import Path
from urllib.parse import parse_qs, urlsplit

import httpx
import pytest
from fastapi.testclient import TestClient
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine

from app.config import Settings
from app.infrastructure.api import admin_routers, dependencies
from app.infrastructure.db.seed_lesson_content import CURRICULUM, _content_id, seed
from app.infrastructure.external.audio_link_checker import AudioLinkChecker
from app.infrastructure.external.r2_storage import R2Storage
from tests.fakes import FakeTokenVerifier

ClientFactory = Callable[[object, object], TestClient]
ADMIN = "admin@example.com"
A = "/api/v1/admin"
SECRET = "r2-secret-never-shown"
LESSON = _content_id(CURRICULUM[0]["lessons"][0]["slug"])

STORAGE = R2Storage(
    account_id="acct123",
    bucket="ethio-lang",
    access_key_id="AKIDTEST",
    secret_access_key=SECRET,
    public_base_url="https://pub-abc.r2.dev",
)


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
    monkeypatch.setattr(dependencies, "get_settings", lambda: Settings(admin_emails=ADMIN))
    client = make_client(FakeTokenVerifier(subject="sub-admin", email=ADMIN), FakeTokenVerifier())
    client.app.dependency_overrides[admin_routers.get_audio_storage] = lambda: STORAGE
    return client


@pytest.fixture
def h(client: TestClient) -> dict[str, str]:
    token = client.post("/api/v1/auth/google", json={"id_token": "t"}).json()["session_token"]
    return {"Authorization": f"Bearer {token}"}


def _upload(client: TestClient, h: dict, **body: object) -> httpx.Response:
    payload = {"lesson_id": LESSON, "content_type": "audio/mp4", "size": 40960, **body}
    return client.post(f"{A}/audio/uploads", json=payload, headers=h)


class TestUploads:
    def test_returns_a_bound_short_lived_link_and_the_public_address(
        self, client: TestClient, h: dict
    ) -> None:
        response = _upload(client, h)

        assert response.status_code == 201
        body = response.json()
        assert re.fullmatch(rf"am/{LESSON}/[0-9a-f]{{12}}\.m4a", body["key"])
        assert body["public_url"] == f"https://pub-abc.r2.dev/{body['key']}"
        assert body["method"] == "PUT"
        assert body["headers"] == {"Content-Type": "audio/mp4"}
        assert body["expires_in"] == 600
        url = urlsplit(body["upload_url"])
        assert url.netloc == "acct123.r2.cloudflarestorage.com"
        assert url.path == f"/ethio-lang/{body['key']}"
        query = parse_qs(url.query)
        assert query["X-Amz-Expires"] == ["600"]
        assert query["X-Amz-SignedHeaders"] == ["content-length;content-type;host"]
        assert SECRET not in response.text

    def test_each_upload_gets_its_own_key(self, client: TestClient, h: dict) -> None:
        keys = {_upload(client, h).json()["key"] for _ in range(3)}
        assert len(keys) == 3

    @pytest.mark.parametrize(
        ("content_type", "extension"),
        [
            ("audio/x-m4a", "m4a"),
            ("audio/mpeg", "mp3"),
            ("audio/webm;codecs=opus", "webm"),
            ("audio/ogg", "ogg"),
        ],
    )
    def test_extension_follows_the_type(
        self, client: TestClient, h: dict, content_type: str, extension: str
    ) -> None:
        body = _upload(client, h, content_type=content_type).json()
        assert body["key"].endswith(f".{extension}")

    @pytest.mark.parametrize("content_type", ["video/mp4", "text/plain", "audio/wav", ""])
    def test_other_types_are_refused(self, client: TestClient, h: dict, content_type: str) -> None:
        response = _upload(client, h, content_type=content_type)
        assert response.status_code == 422
        assert response.json()["details"] == {"field": "content_type"}

    @pytest.mark.parametrize("size", [0, -1, 5 * 1024 * 1024 + 1])
    def test_sizes_outside_1_byte_to_5_mb_are_refused(
        self, client: TestClient, h: dict, size: int
    ) -> None:
        response = _upload(client, h, size=size)
        assert response.status_code == 422
        assert response.json()["details"] == {"field": "size"}

    def test_exactly_5_mb_is_allowed(self, client: TestClient, h: dict) -> None:
        assert _upload(client, h, size=5 * 1024 * 1024).status_code == 201

    def test_unknown_lesson_is_404(self, client: TestClient, h: dict) -> None:
        assert _upload(client, h, lesson_id="nope").status_code == 404

    def test_unconfigured_storage_is_503(self, client: TestClient, h: dict) -> None:
        client.app.dependency_overrides[admin_routers.get_audio_storage] = lambda: None
        response = _upload(client, h)
        assert response.status_code == 503
        assert response.json()["error_code"] == "audio_storage_not_configured"

    def test_logs_the_key_but_never_the_secret(
        self, client: TestClient, h: dict, caplog: pytest.LogCaptureFixture
    ) -> None:
        with caplog.at_level(logging.INFO, logger="app.admin"):
            key = _upload(client, h).json()["key"]
        lines = [r.getMessage() for r in caplog.records if r.name == "app.admin"]
        assert lines == [f"admin_write action=presign entity=audio id={key} admin={ADMIN}"]
        assert not any(SECRET in line for line in lines)


class TestLinks:
    def _use(self, client: TestClient, handler: Callable[[httpx.Request], httpx.Response]) -> None:
        async def resolver(host: str) -> list[str]:
            return ["93.184.216.34"] if host == "cdn.example" else ["10.0.0.1"]

        checker = AudioLinkChecker(transport=httpx.MockTransport(handler), resolver=resolver)
        client.app.dependency_overrides[admin_routers.get_audio_link_checker] = lambda: checker

    def test_an_audio_link_is_accepted(self, client: TestClient, h: dict) -> None:
        self._use(client, lambda r: httpx.Response(200, headers={"content-type": "audio/mpeg"}))
        response = client.post(
            f"{A}/audio/links", json={"url": " https://cdn.example/a.mp3 "}, headers=h
        )
        assert response.status_code == 200
        assert response.json() == {"url": "https://cdn.example/a.mp3", "content_type": "audio/mpeg"}

    @pytest.mark.parametrize(
        ("url", "reason"),
        [
            ("http://cdn.example/a.mp3", "not_https"),
            ("https://inside.example/a.mp3", "private_address"),
            ("https://cdn.example/page", "not_audio"),
        ],
    )
    def test_a_bad_link_is_refused_with_its_reason(
        self, client: TestClient, h: dict, url: str, reason: str
    ) -> None:
        self._use(client, lambda r: httpx.Response(200, headers={"content-type": "text/html"}))
        response = client.post(f"{A}/audio/links", json={"url": url}, headers=h)
        assert response.status_code == 422
        assert response.json()["error_code"] == "invalid_audio_link"
        assert response.json()["details"] == {"reason": reason}
