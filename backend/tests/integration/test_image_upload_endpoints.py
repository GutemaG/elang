"""Integration tests: picture uploads (story 002-picture-upload-links, bolt
050-image-choice-service), over HTTP. `POST /admin/images/uploads` against a
stand-in R2 store, and the whole local flow -- link, `PUT`, then loading the
picture from `/media/images` -- in a temporary media folder, never
`backend/media`.
"""

from __future__ import annotations

import asyncio
import logging
import re
from collections.abc import Callable
from pathlib import Path
from typing import Any
from urllib.parse import parse_qs, urlsplit

import httpx
import pytest
from fastapi.staticfiles import StaticFiles
from fastapi.testclient import TestClient
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine

from app import main
from app.config import Settings
from app.infrastructure.api import admin_routers, audio_file_routers, dependencies
from app.infrastructure.api.audio_file_routers import image_router
from app.infrastructure.api.audio_file_routers import router as audio_file_router
from app.infrastructure.db.seed_lesson_content import CURRICULUM, _content_id, seed
from app.infrastructure.external import local_audio_storage
from app.infrastructure.external.r2_storage import R2Storage
from tests.fakes import FakeTokenVerifier

ClientFactory = Callable[[object, object], TestClient]
ADMIN = "admin@example.com"
A = "/api/v1/admin"
SECRET = "r2-secret-never-shown"
LESSON = _content_id(CURRICULUM[0]["lessons"][0]["slug"])
PICTURE = b"RIFF\x1a\x00\x00\x00WEBPVP8 fake picture bytes"
CLIP = b"\x00\x00\x00\x18ftypM4A fake clip bytes"
MB = 1024 * 1024

STORAGE = R2Storage(
    account_id="acct123",
    bucket="ethio-lang",
    access_key_id="AKIDTEST",
    secret_access_key=SECRET,
    public_base_url="https://pub-abc.r2.dev",
)


def _seed(db_path: Path) -> None:
    async def _run() -> None:
        engine = create_async_engine(f"sqlite+aiosqlite:///{db_path}")
        async with AsyncSession(engine) as session:
            await seed(session)
            await session.commit()
        await engine.dispose()

    asyncio.run(_run())


def _token(client: TestClient) -> dict[str, str]:
    token = client.post("/api/v1/auth/google", json={"id_token": "t"}).json()["session_token"]
    return {"Authorization": f"Bearer {token}"}


def _ask(client: TestClient, h: dict[str, str], **body: Any) -> httpx.Response:
    payload = {"lesson_id": LESSON, "content_type": "image/webp", "size": 40960, **body}
    return client.post(f"{A}/images/uploads", json=payload, headers=h)


class TestLinksToR2:
    @pytest.fixture
    def client(
        self, make_client: ClientFactory, db_path: Path, monkeypatch: pytest.MonkeyPatch
    ) -> TestClient:
        _seed(db_path)
        monkeypatch.setattr(dependencies, "get_settings", lambda: Settings(admin_emails=ADMIN))
        client = make_client(
            FakeTokenVerifier(subject="sub-admin", email=ADMIN), FakeTokenVerifier()
        )
        client.app.dependency_overrides[admin_routers.get_image_storage] = lambda: STORAGE
        return client

    @pytest.fixture
    def h(self, client: TestClient) -> dict[str, str]:
        return _token(client)

    def test_returns_a_bound_short_lived_link_and_the_public_address(
        self, client: TestClient, h: dict
    ) -> None:
        response = _ask(client, h)

        assert response.status_code == 201
        body = response.json()
        assert re.fullmatch(rf"am/{LESSON}/[0-9a-f]{{12}}\.webp", body["key"])
        assert body["public_url"] == f"https://pub-abc.r2.dev/{body['key']}"
        assert body["method"] == "PUT"
        assert body["headers"] == {"Content-Type": "image/webp"}
        assert body["expires_in"] == 600
        url = urlsplit(body["upload_url"])
        assert url.netloc == "acct123.r2.cloudflarestorage.com"
        assert url.path == f"/ethio-lang/{body['key']}"
        query = parse_qs(url.query)
        assert query["X-Amz-Expires"] == ["600"]
        assert query["X-Amz-SignedHeaders"] == ["content-length;content-type;host"]
        assert SECRET not in response.text

    @pytest.mark.parametrize(
        ("content_type", "extension", "sent"),
        [
            ("image/webp", "webp", "image/webp"),
            ("image/jpeg", "jpg", "image/jpeg"),
            ("IMAGE/JPEG; charset=binary", "jpg", "image/jpeg"),
        ],
    )
    def test_extension_and_signed_type_follow_the_type(
        self, client: TestClient, h: dict, content_type: str, extension: str, sent: str
    ) -> None:
        body = _ask(client, h, content_type=content_type).json()
        assert body["key"].endswith(f".{extension}")
        assert body["headers"] == {"Content-Type": sent}

    @pytest.mark.parametrize(
        "content_type", ["image/png", "image/gif", "image/svg+xml", "audio/mp4", "text/html", ""]
    )
    def test_other_types_are_refused(self, client: TestClient, h: dict, content_type: str) -> None:
        response = _ask(client, h, content_type=content_type)
        assert response.status_code == 422
        assert response.json()["details"] == {"field": "content_type"}

    @pytest.mark.parametrize("size", [0, -1, MB + 1, 5 * MB])
    def test_sizes_outside_1_byte_to_1_mb_are_refused(
        self, client: TestClient, h: dict, size: int
    ) -> None:
        response = _ask(client, h, size=size)
        assert response.status_code == 422
        assert response.json()["details"] == {"field": "size"}

    @pytest.mark.parametrize("size", [1, MB])
    def test_1_byte_and_exactly_1_mb_are_allowed(
        self, client: TestClient, h: dict, size: int
    ) -> None:
        assert _ask(client, h, size=size).status_code == 201

    def test_each_upload_gets_its_own_key(self, client: TestClient, h: dict) -> None:
        assert len({_ask(client, h).json()["key"] for _ in range(3)}) == 3

    def test_unknown_lesson_is_404(self, client: TestClient, h: dict) -> None:
        assert _ask(client, h, lesson_id="nope").status_code == 404

    def test_unconfigured_storage_is_503(self, client: TestClient, h: dict) -> None:
        client.app.dependency_overrides[admin_routers.get_image_storage] = lambda: None
        response = _ask(client, h)
        assert response.status_code == 503
        assert response.json()["error_code"] == "audio_storage_not_configured"

    def test_logs_the_key_but_never_the_secret(
        self, client: TestClient, h: dict, caplog: pytest.LogCaptureFixture
    ) -> None:
        with caplog.at_level(logging.INFO, logger="app.admin"):
            key = _ask(client, h).json()["key"]
        lines = [r.getMessage() for r in caplog.records if r.name == "app.admin"]
        assert lines == [f"admin_write action=presign entity=image id={key} admin={ADMIN}"]
        assert not any(SECRET in line for line in lines)

    def test_a_learner_cannot_ask(
        self, make_client: ClientFactory, db_path: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        _seed(db_path)
        monkeypatch.setattr(dependencies, "get_settings", lambda: Settings(admin_emails=ADMIN))
        learner = make_client(
            FakeTokenVerifier(subject="sub-learner", email="learner@example.com"),
            FakeTokenVerifier(),
        )
        learner.app.dependency_overrides[admin_routers.get_image_storage] = lambda: STORAGE

        response = _ask(learner, _token(learner))

        assert response.status_code == 403


class TestUploadingLocally:
    """Every refusal leaves the media folder exactly as it was."""

    @pytest.fixture
    def media(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
        folder = tmp_path / "media"
        monkeypatch.setattr(local_audio_storage, "AUDIO_DIR", folder / "audio")
        monkeypatch.setattr(local_audio_storage, "IMAGES_DIR", folder / "images")
        return folder

    @pytest.fixture
    def client(
        self,
        make_client: ClientFactory,
        db_path: Path,
        media: Path,
        monkeypatch: pytest.MonkeyPatch,
    ) -> TestClient:
        _seed(db_path)
        # `_env_file=None`: the developer's own `.env` must not decide which
        # store these tests get.
        settings = Settings(_env_file=None, admin_emails=ADMIN, environment="local")
        for module in (dependencies, admin_routers, audio_file_routers):
            monkeypatch.setattr(module, "get_settings", lambda: settings)
        client = make_client(
            FakeTokenVerifier(subject="sub-admin", email=ADMIN), FakeTokenVerifier()
        )
        client.app.include_router(audio_file_router)
        client.app.include_router(image_router)
        client.app.mount("/media", StaticFiles(directory=media, check_dir=False), name="media")
        return client

    @pytest.fixture
    def h(self, client: TestClient) -> dict[str, str]:
        return _token(client)

    def _link(self, client: TestClient, h: dict, **body: Any) -> dict[str, Any]:
        response = _ask(client, h, size=len(PICTURE), **body)
        assert response.status_code == 201, response.json()
        return response.json()

    def _put(self, client: TestClient, url: str, body: bytes, headers: dict) -> httpx.Response:
        # No Authorization header: the link's signature is the only permission.
        parts = urlsplit(url)
        return client.put(f"{parts.path}?{parts.query}", content=body, headers=headers)

    def _files(self, media: Path) -> list[str]:
        if not media.exists():
            return []
        return sorted(p.relative_to(media).as_posix() for p in media.rglob("*") if p.is_file())

    def test_a_picture_is_saved_and_then_loads_from_its_address(
        self, client: TestClient, h: dict, media: Path
    ) -> None:
        link = self._link(client, h)
        assert link["upload_url"].startswith(f"http://testserver/api/v1/image-files/{link['key']}?")
        assert link["public_url"] == f"/media/images/{link['key']}"

        saved = self._put(client, link["upload_url"], PICTURE, link["headers"])

        assert saved.status_code == 201
        assert saved.json() == {"key": link["key"], "public_url": link["public_url"]}
        assert self._files(media) == [f"images/{link['key']}"]
        loaded = client.get(link["public_url"])
        assert loaded.status_code == 200
        assert loaded.content == PICTURE

    def test_a_jpeg_is_saved_as_jpg(self, client: TestClient, h: dict, media: Path) -> None:
        link = self._link(client, h, content_type="image/jpeg")
        assert self._put(client, link["upload_url"], PICTURE, link["headers"]).status_code == 201
        assert self._files(media) == [f"images/{link['key']}"]
        assert link["key"].endswith(".jpg")

    def test_a_picture_link_cannot_upload_to_the_audio_route(
        self, client: TestClient, h: dict, media: Path
    ) -> None:
        link = self._link(client, h)
        url = link["upload_url"].replace("/image-files/", "/audio-files/", 1)

        assert self._put(client, url, PICTURE, link["headers"]).status_code == 404
        assert self._files(media) == []

    def test_an_audio_link_cannot_upload_a_picture(
        self, client: TestClient, h: dict, media: Path
    ) -> None:
        audio = client.post(
            f"{A}/audio/uploads",
            json={"lesson_id": LESSON, "content_type": "audio/mp4", "size": len(CLIP)},
            headers=h,
        ).json()
        url = audio["upload_url"].replace("/audio-files/", "/image-files/", 1)
        moved = url.replace(".m4a", ".webp")

        assert self._put(client, url, CLIP, audio["headers"]).status_code == 404
        refused = self._put(client, moved, CLIP, audio["headers"])
        assert refused.status_code == 403
        assert refused.json()["error_code"] == "invalid_upload_link"
        assert self._files(media) == []

    def test_audio_still_uploads_beside_pictures(
        self, client: TestClient, h: dict, media: Path
    ) -> None:
        audio = client.post(
            f"{A}/audio/uploads",
            json={"lesson_id": LESSON, "content_type": "audio/mp4", "size": len(CLIP)},
            headers=h,
        ).json()
        picture = self._link(client, h)

        assert self._put(client, audio["upload_url"], CLIP, audio["headers"]).status_code == 201
        assert (
            self._put(client, picture["upload_url"], PICTURE, picture["headers"]).status_code == 201
        )
        assert self._files(media) == [f"audio/{audio['key']}", f"images/{picture['key']}"]

    def test_an_altered_signature(self, client: TestClient, h: dict, media: Path) -> None:
        link = self._link(client, h)
        url = link["upload_url"].replace("sig=", "sig=0", 1)

        response = self._put(client, url, PICTURE, link["headers"])

        assert response.status_code == 403
        assert response.json()["error_code"] == "invalid_upload_link"
        assert self._files(media) == []

    def test_a_different_content_type(self, client: TestClient, h: dict, media: Path) -> None:
        link = self._link(client, h)

        response = self._put(client, link["upload_url"], PICTURE, {"Content-Type": "image/jpeg"})

        assert response.status_code == 422
        assert response.json()["details"] == {"field": "content_type"}
        assert self._files(media) == []

    @pytest.mark.parametrize("body", [PICTURE[:-1], PICTURE + b"x", b""])
    def test_a_body_of_another_size(
        self, client: TestClient, h: dict, media: Path, body: bytes
    ) -> None:
        link = self._link(client, h)

        response = self._put(client, link["upload_url"], body, link["headers"])

        assert response.status_code == 422
        assert response.json()["details"] == {"field": "size"}
        assert self._files(media) == []

    def test_a_forged_link_over_1_mb_is_never_read_past_the_limit(
        self, client: TestClient, media: Path
    ) -> None:
        # A size the admin API would never sign; the route still stops at
        # its own limit rather than trusting the link's.
        store = local_audio_storage.choose_image_storage(
            Settings(_env_file=None, environment="local"), upload_base_url="http://testserver/"
        )
        assert isinstance(store, local_audio_storage.LocalAudioStorage)
        big = b"\x00" * (MB + 1)
        link = store.presign_put(
            f"am/{LESSON}/0123456789ab.webp",
            content_type="image/webp",
            size=len(big),
            expires_in=600,
        )

        response = self._put(client, link.url, big, link.headers)

        assert response.status_code == 422
        assert response.json()["details"] == {"field": "size"}
        assert self._files(media) == []

    @pytest.mark.parametrize(
        "path",
        [
            "am/../../evil.webp",
            "am/lesson/sub/0123456789ab.webp",
            "am/lesson/0123456789ab.png",
            "am/lesson/0123456789ab.m4a",
        ],
    )
    def test_a_key_this_backend_never_issues(
        self, client: TestClient, media: Path, path: str
    ) -> None:
        query = f"type=image/webp&size={len(PICTURE)}&expires=9999999999&sig={'0' * 64}"
        response = client.put(
            f"/api/v1/image-files/{path}?{query}",
            content=PICTURE,
            headers={"Content-Type": "image/webp"},
        )

        assert response.status_code == 404
        assert self._files(media) == []

    def test_the_picture_route_never_uses_an_audio_store(
        self, client: TestClient, media: Path
    ) -> None:
        # Wiring the wrong store to the route must close it, not let an
        # audio-signed link write into the audio folder under a picture key.
        audio_store = local_audio_storage.choose_audio_storage(
            Settings(_env_file=None, environment="local"), upload_base_url="http://testserver/"
        )
        assert isinstance(audio_store, local_audio_storage.LocalAudioStorage)
        client.app.dependency_overrides[audio_file_routers.get_local_image_storage] = lambda: (
            audio_store
        )
        link = audio_store.presign_put(
            f"am/{LESSON}/0123456789ab.webp",
            content_type="image/webp",
            size=len(PICTURE),
            expires_in=600,
        )
        url = link.url.replace("/audio-files/", "/image-files/", 1)

        response = self._put(client, url, PICTURE, link.headers)

        assert response.status_code == 404
        assert self._files(media) == []

    def test_the_route_is_closed_outside_local_development(
        self, client: TestClient, h: dict, media: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        link = self._link(client, h)
        settings = Settings(_env_file=None, admin_emails=ADMIN, environment="production")
        for module in (dependencies, admin_routers, audio_file_routers):
            monkeypatch.setattr(module, "get_settings", lambda: settings)

        closed = self._put(client, link["upload_url"], PICTURE, link["headers"])
        refused = _ask(client, h, size=len(PICTURE))

        assert closed.status_code == 404
        assert refused.status_code == 503
        assert self._files(media) == []


def test_the_app_registers_both_picture_routes() -> None:
    paths = main.create_app().openapi()["paths"]
    assert "/api/v1/admin/images/uploads" in paths
    assert "/api/v1/image-files/{key}" in paths
