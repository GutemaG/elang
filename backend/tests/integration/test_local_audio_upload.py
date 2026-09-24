"""Integration tests: uploading audio to the local backend when R2 is not
configured (story 007-local-audio-storage, bolt 041-local-audio-storage),
over HTTP. Files land in a temporary media folder, never `backend/media`.
"""

from __future__ import annotations

import asyncio
from collections.abc import Callable
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any
from urllib.parse import urlsplit

import httpx
import pytest
from fastapi.staticfiles import StaticFiles
from fastapi.testclient import TestClient
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from starlette.routing import Mount

from app import main
from app.config import Settings
from app.infrastructure.api import admin_routers, audio_file_routers, dependencies
from app.infrastructure.api.audio_file_routers import router as audio_file_router
from app.infrastructure.db.seed_lesson_content import CURRICULUM, _content_id, seed
from app.infrastructure.external import local_audio_storage
from app.infrastructure.external.local_audio_storage import LocalAudioStorage, choose_audio_storage
from tests.fakes import EN_AM_COURSE_ID, FakeTokenVerifier

ClientFactory = Callable[[object, object], TestClient]
ADMIN = "admin@example.com"
A = "/api/v1/admin"
LESSON = _content_id(CURRICULUM[0]["lessons"][0]["slug"])
CLIP = b"\x00\x00\x00\x18ftypM4A fake clip bytes"

R2 = {
    "audio_base_url": "https://pub-abc.r2.dev",
    "r2_account_id": "acct123",
    "r2_bucket": "ethio-lang",
    "r2_access_key_id": "AKIDTEST",
    "r2_secret_access_key": "r2-secret",
}


def _settings(**overrides: Any) -> Settings:
    # `_env_file=None`: the developer's own `.env` (which may hold R2 keys)
    # must not decide which store these tests get.
    return Settings(_env_file=None, admin_emails=ADMIN, **{"environment": "local", **overrides})


@pytest.fixture
def media(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    folder = tmp_path / "media"
    monkeypatch.setattr(local_audio_storage, "AUDIO_DIR", folder / "audio")
    return folder


@pytest.fixture
def use_settings(monkeypatch: pytest.MonkeyPatch) -> Callable[..., None]:
    def _use(**overrides: Any) -> None:
        settings = _settings(**overrides)
        for module in (dependencies, admin_routers, audio_file_routers):
            monkeypatch.setattr(module, "get_settings", lambda: settings)

    _use()
    return _use


@pytest.fixture
def client(
    make_client: ClientFactory, db_path: Path, media: Path, use_settings: Callable[..., None]
) -> TestClient:
    async def _seed() -> None:
        engine = create_async_engine(f"sqlite+aiosqlite:///{db_path}")
        async with AsyncSession(engine) as session:
            await seed(session)
            await session.commit()
        await engine.dispose()

    asyncio.run(_seed())
    client = make_client(FakeTokenVerifier(subject="sub-admin", email=ADMIN), FakeTokenVerifier())
    # What `create_app` adds beyond the conftest app: the receiving route,
    # and `/media` over the temporary folder.
    client.app.include_router(audio_file_router)
    client.app.mount("/media", StaticFiles(directory=media, check_dir=False), name="media")
    return client


@pytest.fixture
def h(client: TestClient) -> dict[str, str]:
    token = client.post("/api/v1/auth/google", json={"id_token": "t"}).json()["session_token"]
    return {"Authorization": f"Bearer {token}"}


def _ask(client: TestClient, h: dict[str, str], *, lesson: str = LESSON, **body: Any) -> Any:
    payload = {"lesson_id": lesson, "content_type": "audio/mp4", "size": len(CLIP), **body}
    response = client.post(f"{A}/audio/uploads", json=payload, headers=h)
    assert response.status_code == 201, response.json()
    return response.json()


def _put(client: TestClient, url: str, body: bytes, headers: dict[str, str]) -> httpx.Response:
    # No Authorization header: the link's signature is the only permission.
    parts = urlsplit(url)
    return client.put(f"{parts.path}?{parts.query}", content=body, headers=headers)


def _files(media: Path) -> list[str]:
    if not media.exists():
        return []
    return sorted(p.relative_to(media).as_posix() for p in media.rglob("*") if p.is_file())


class TestUploadingLocally:
    def test_the_link_points_at_this_backend_and_the_address_at_media(
        self, client: TestClient, h: dict[str, str]
    ) -> None:
        link = _ask(client, h)

        assert link["key"].startswith(f"am/{LESSON}/")
        assert link["upload_url"].startswith(f"http://testserver/api/v1/audio-files/{link['key']}?")
        assert link["public_url"] == f"/media/audio/{link['key']}"
        assert link["method"] == "PUT"
        assert link["headers"] == {"Content-Type": "audio/mp4"}
        assert link["expires_in"] == 600

    def test_an_upload_is_saved_and_then_plays_from_its_address(
        self, client: TestClient, h: dict[str, str], media: Path
    ) -> None:
        link = _ask(client, h)

        saved = _put(client, link["upload_url"], CLIP, link["headers"])

        assert saved.status_code == 201
        assert saved.json() == {"key": link["key"], "public_url": link["public_url"]}
        assert _files(media) == [f"audio/{link['key']}"]
        played = client.get(link["public_url"])
        assert played.status_code == 200
        assert played.content == CLIP

    def test_the_address_can_be_saved_on_a_listening_exercise(
        self, client: TestClient, h: dict[str, str]
    ) -> None:
        tree = client.get(f"{A}/courses/{EN_AM_COURSE_ID}/tree", headers=h).json()
        lesson_id, exercise_id = next(
            (lesson["id"], e["id"])
            for s in tree["sections"]
            for k in s["skills"]
            for lesson in k["lessons"]
            for e in lesson["exercises"]
            if e["audio"] == "placeholder"
        )
        link = _ask(client, h, lesson=lesson_id)
        assert _put(client, link["upload_url"], CLIP, link["headers"]).status_code == 201

        exercise = next(
            e
            for e in client.get(f"{A}/lessons/{lesson_id}/exercises", headers=h).json()["exercises"]
            if e["id"] == exercise_id
        )
        body = {k: exercise[k] for k in ("type", "prompt", "content", "answer_key")}
        body["content"] = {**body["content"], "audio_url": link["public_url"]}
        updated = client.put(f"{A}/exercises/{exercise_id}", json=body, headers=h)

        assert updated.status_code == 200, updated.json()
        tree = client.get(f"{A}/courses/{EN_AM_COURSE_ID}/tree", headers=h).json()
        audio = {
            e["id"]: e["audio"]
            for s in tree["sections"]
            for k in s["skills"]
            for lesson in k["lessons"]
            for e in lesson["exercises"]
        }
        assert audio[exercise_id] == "local"

    @pytest.mark.parametrize(
        ("content_type", "extension"),
        [("audio/mpeg", "mp3"), ("audio/webm;codecs=opus", "webm"), ("audio/ogg", "ogg")],
    )
    def test_other_audio_types_upload_too(
        self, client: TestClient, h: dict[str, str], media: Path, content_type: str, extension: str
    ) -> None:
        link = _ask(client, h, content_type=content_type)

        assert _put(client, link["upload_url"], CLIP, link["headers"]).status_code == 201
        assert _files(media)[0].endswith(f".{extension}")


class TestRefusals:
    """Every refusal leaves the media folder exactly as it was."""

    def test_an_altered_signature(self, client: TestClient, h: dict, media: Path) -> None:
        link = _ask(client, h)
        url = link["upload_url"].replace("sig=", "sig=0", 1)

        response = _put(client, url, CLIP, link["headers"])

        assert response.status_code == 403
        assert response.json()["error_code"] == "invalid_upload_link"
        assert _files(media) == []

    def test_a_link_moved_to_another_key(self, client: TestClient, h: dict, media: Path) -> None:
        link = _ask(client, h)
        other = f"am/{LESSON}/abcdefabcdef.m4a"
        url = link["upload_url"].replace(link["key"], other, 1)

        assert _put(client, url, CLIP, link["headers"]).status_code == 403
        assert _files(media) == []

    def test_an_expired_link(self, client: TestClient, media: Path) -> None:
        store = choose_audio_storage(_settings(), upload_base_url="http://testserver/")
        assert isinstance(store, LocalAudioStorage)
        stale = store.presign_put(
            f"am/{LESSON}/0123456789ab.m4a",
            content_type="audio/mp4",
            size=len(CLIP),
            expires_in=600,
            now=datetime.now(UTC) - timedelta(minutes=11),
        )

        response = _put(client, stale.url, CLIP, stale.headers)

        assert response.status_code == 403
        assert response.json()["error_code"] == "upload_link_expired"
        assert _files(media) == []

    def test_a_different_content_type(self, client: TestClient, h: dict, media: Path) -> None:
        link = _ask(client, h)

        response = _put(client, link["upload_url"], CLIP, {"Content-Type": "audio/mpeg"})

        assert response.status_code == 422
        assert response.json()["details"] == {"field": "content_type"}
        assert _files(media) == []

    @pytest.mark.parametrize("body", [CLIP[:-1], CLIP + b"x", CLIP * 50, b""])
    def test_a_body_of_another_size(
        self, client: TestClient, h: dict, media: Path, body: bytes
    ) -> None:
        link = _ask(client, h)

        response = _put(client, link["upload_url"], body, link["headers"])

        assert response.status_code == 422
        assert response.json()["details"] == {"field": "size"}
        assert _files(media) == []

    def test_the_same_link_twice(self, client: TestClient, h: dict, media: Path) -> None:
        link = _ask(client, h)
        assert _put(client, link["upload_url"], CLIP, link["headers"]).status_code == 201

        again = _put(client, link["upload_url"], b"\x01" * len(CLIP), link["headers"])

        assert again.status_code == 409
        assert again.json()["error_code"] == "audio_file_exists"
        assert (media / "audio" / link["key"]).read_bytes() == CLIP

    @pytest.mark.parametrize(
        "path",
        [
            "am/../../evil.m4a",
            "..%2F..%2Fevil.m4a",
            "am/lesson/sub/0123456789ab.m4a",
            "am/lesson/0123456789ab.exe",
        ],
    )
    def test_a_key_this_backend_never_issues(
        self, client: TestClient, media: Path, path: str
    ) -> None:
        query = f"type=audio/mp4&size={len(CLIP)}&expires=9999999999&sig={'0' * 64}"
        response = client.put(
            f"/api/v1/audio-files/{path}?{query}",
            content=CLIP,
            headers={"Content-Type": "audio/mp4"},
        )

        assert response.status_code == 404
        assert _files(media) == []
        assert not (media.parent / "evil.m4a").exists()


class TestWhichStore:
    def test_a_deployed_server_without_r2_uploads_nowhere(
        self, client: TestClient, h: dict, media: Path, use_settings: Callable[..., None]
    ) -> None:
        # A link signed while local, then used once the server is deployed.
        link = _ask(client, h)
        use_settings(environment="production")

        refused = client.post(
            f"{A}/audio/uploads",
            json={"lesson_id": LESSON, "content_type": "audio/mp4", "size": len(CLIP)},
            headers=h,
        )
        closed = _put(client, link["upload_url"], CLIP, link["headers"])

        assert refused.status_code == 503
        assert refused.json()["error_code"] == "audio_storage_not_configured"
        assert closed.status_code == 404
        assert _files(media) == []

    def test_with_r2_configured_uploads_go_to_r2_and_the_local_route_closes(
        self, client: TestClient, h: dict, media: Path, use_settings: Callable[..., None]
    ) -> None:
        local_link = _ask(client, h)
        use_settings(**R2)

        link = _ask(client, h)
        closed = _put(client, local_link["upload_url"], CLIP, local_link["headers"])

        assert urlsplit(link["upload_url"]).netloc == "acct123.r2.cloudflarestorage.com"
        assert link["public_url"] == f"https://pub-abc.r2.dev/{link['key']}"
        assert closed.status_code == 404
        assert _files(media) == []


class TestTheApp:
    """`create_app` wires the route and the media folder itself."""

    def _app(self, monkeypatch: pytest.MonkeyPatch, tmp_path: Path, environment: str) -> Any:
        monkeypatch.setattr(main, "get_settings", lambda: _settings(environment=environment))
        monkeypatch.setattr(main, "MEDIA_DIR", tmp_path / "not-created-yet")
        return main.create_app()

    def test_locally_it_serves_media_even_before_the_first_upload(
        self, monkeypatch: pytest.MonkeyPatch, tmp_path: Path
    ) -> None:
        app = self._app(monkeypatch, tmp_path, "local")

        # FastAPI 0.14x keeps included routers nested, so ask the schema.
        assert "/api/v1/audio-files/{key}" in app.openapi()["paths"]
        assert {r.path for r in app.routes if isinstance(r, Mount)} == {"/media"}

    def test_deployed_without_a_media_folder_it_serves_none(
        self, monkeypatch: pytest.MonkeyPatch, tmp_path: Path
    ) -> None:
        app = self._app(monkeypatch, tmp_path, "production")

        assert not [r for r in app.routes if isinstance(r, Mount)]
