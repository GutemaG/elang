"""Unit tests: reading, moving and deleting stored audio (intent 029, FR-1),
and matching links to keys (FR-2). R2 is replaced by an httpx mock
transport, so nothing leaves the machine."""

from __future__ import annotations

from datetime import UTC, datetime
from pathlib import Path
from urllib.parse import parse_qs, urlsplit

import httpx
import pytest

from app.application.audio_library_use_cases import is_audio, key_of, slug
from app.domain.lesson.exceptions import (
    AudioFileExistsError,
    AudioFileNotFoundError,
    AudioStorageUnavailableError,
)
from app.infrastructure.external.media_library import (
    LocalMediaLibrary,
    R2MediaLibrary,
    is_safe_key,
)
from app.infrastructure.external.r2_storage import R2Storage

SECRET = "r2-secret-never-shown"
STORAGE = R2Storage(
    account_id="acct123",
    bucket="ethio-lang",
    access_key_id="AKIDTEST",
    secret_access_key=SECRET,
    public_base_url="https://pub-abc.r2.dev",
)
NOW = datetime(2026, 10, 13, 12, 0, tzinfo=UTC)


def _page(keys: list[str], token: str | None) -> bytes:
    items = "".join(
        f"<Contents><Key>{k}</Key><Size>12</Size>"
        f"<LastModified>2026-10-01T08:00:00.000Z</LastModified></Contents>"
        for k in keys
    )
    more = f"<IsTruncated>true</IsTruncated><NextContinuationToken>{token}</NextContinuationToken>"
    tail = more if token else "<IsTruncated>false</IsTruncated>"
    return (
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">'
        f"{items}{tail}</ListBucketResult>"
    ).encode()


def _r2(handler: object) -> tuple[R2MediaLibrary, list[httpx.Request]]:
    seen: list[httpx.Request] = []

    def record(request: httpx.Request) -> httpx.Response:
        seen.append(request)
        return handler(request)  # type: ignore[operator]

    return R2MediaLibrary(STORAGE, transport=httpx.MockTransport(record), now=NOW), seen


class TestR2:
    async def test_lists_every_page_with_signed_requests(self) -> None:
        def handler(request: httpx.Request) -> httpx.Response:
            query = parse_qs(urlsplit(str(request.url)).query)
            if "continuation-token" in query:
                return httpx.Response(200, content=_page(["am/l/b.m4a"], None))
            return httpx.Response(200, content=_page(["am/l/a.m4a"], "next+token/="))

        library, seen = _r2(handler)

        files = await library.list_files()

        assert [f.key for f in files] == ["am/l/a.m4a", "am/l/b.m4a"]
        assert files[0].size == 12
        assert files[0].uploaded_at == datetime(2026, 10, 1, 8, 0, tzinfo=UTC)
        first, second = (parse_qs(urlsplit(str(r.url)).query) for r in seen)
        assert first["list-type"] == ["2"] and "X-Amz-Signature" in first
        assert second["continuation-token"] == ["next+token/="]
        assert all(r.url.host == "acct123.r2.cloudflarestorage.com" for r in seen)
        assert all(SECRET not in str(r.url) for r in seen)

    async def test_a_move_copies_with_a_signed_source_then_deletes(self) -> None:
        library, seen = _r2(lambda r: httpx.Response(204 if r.method == "DELETE" else 200))

        await library.move("am/l/a.m4a", "trash/am/l/a.m4a")

        copy, delete = seen
        assert (copy.method, copy.url.path) == ("PUT", "/ethio-lang/trash/am/l/a.m4a")
        assert copy.headers["x-amz-copy-source"] == "/ethio-lang/am/l/a.m4a"
        signed = parse_qs(urlsplit(str(copy.url)).query)["X-Amz-SignedHeaders"][0]
        assert "x-amz-copy-source" in signed.split(";")
        assert (delete.method, delete.url.path) == ("DELETE", "/ethio-lang/am/l/a.m4a")

    async def test_moving_a_file_that_is_not_there_is_not_found(self) -> None:
        library, seen = _r2(lambda r: httpx.Response(404))

        with pytest.raises(AudioFileNotFoundError):
            await library.move("am/l/a.m4a", "trash/am/l/a.m4a")
        assert len(seen) == 1

    async def test_an_error_answer_is_unavailable(self) -> None:
        library, _ = _r2(lambda r: httpx.Response(500))

        with pytest.raises(AudioStorageUnavailableError):
            await library.list_files()

    async def test_a_dropped_connection_never_shows_the_signed_url(self) -> None:
        def handler(request: httpx.Request) -> httpx.Response:
            raise httpx.ConnectError(f"failed {request.url}")

        library, _ = _r2(handler)

        with pytest.raises(AudioStorageUnavailableError) as caught:
            await library.delete("am/l/a.m4a")
        assert "X-Amz" not in str(caught.value) and caught.value.__cause__ is None

    def test_download_links_are_signed_gets_without_the_secret(self) -> None:
        library, _ = _r2(lambda r: httpx.Response(200))

        url = library.download_url("am/l/a.m4a")

        query = parse_qs(urlsplit(url).query)
        assert urlsplit(url).path == "/ethio-lang/am/l/a.m4a"
        assert query["X-Amz-Expires"] == ["900"]
        assert SECRET not in url

    @pytest.mark.parametrize("key", ["../x.m4a", "/am/x.m4a", "am//x.m4a", "am/.x.m4a", ""])
    def test_refuses_unsafe_keys(self, key: str) -> None:
        library, _ = _r2(lambda r: httpx.Response(200))

        with pytest.raises(AudioFileNotFoundError):
            library.download_url(key)


class TestLocal:
    def _library(self, root: Path) -> LocalMediaLibrary:
        return LocalMediaLibrary(root=root, base_url="http://localhost:8000")

    async def test_lists_moves_and_deletes(self, tmp_path: Path) -> None:
        (tmp_path / "am" / "l").mkdir(parents=True)
        (tmp_path / "am" / "l" / "a.m4a").write_bytes(b"1234")
        (tmp_path / "am" / "l" / ".a.m4a.1234.part").write_bytes(b"x")
        library = self._library(tmp_path)

        (only,) = await library.list_files()
        assert (only.key, only.size) == ("am/l/a.m4a", 4)
        assert library.public_url("am/l/a.m4a") == "http://localhost:8000/media/audio/am/l/a.m4a"

        await library.move("am/l/a.m4a", "trash/am/l/a.m4a")
        assert [f.key for f in await library.list_files("trash/")] == ["trash/am/l/a.m4a"]

        await library.delete("trash/am/l/a.m4a")
        assert await library.list_files() == []

    async def test_a_move_never_replaces_a_file(self, tmp_path: Path) -> None:
        for name in ("a.m4a", "b.m4a"):
            (tmp_path / name).write_bytes(b"1")
        library = self._library(tmp_path)

        with pytest.raises(AudioFileExistsError):
            await library.move("a.m4a", "b.m4a")
        with pytest.raises(AudioFileNotFoundError):
            await library.move("c.m4a", "d.m4a")

    async def test_no_folder_is_an_empty_library(self, tmp_path: Path) -> None:
        assert await self._library(tmp_path / "none").list_files() == []


class TestKeys:
    @pytest.mark.parametrize(
        ("url", "key"),
        [
            ("https://pub-abc.r2.dev/am/l/a.m4a", "am/l/a.m4a"),
            ("https://pub-abc.r2.dev/am/l/a.m4a?v=2#t", "am/l/a.m4a"),
            ("https://pub-abc.r2.dev/am/l/a%2Db.m4a", "am/l/a-b.m4a"),
            ("https://elsewhere.example/am/l/a.m4a", None),
            ("https://pub-abc.r2.dev/../x.m4a", None),
            ("some prompt text", None),
        ],
    )
    def test_r2_links(self, url: str, key: str | None) -> None:
        assert key_of(url, "https://pub-abc.r2.dev/") == key

    @pytest.mark.parametrize(
        "url", ["/media/audio/am/l/a.m4a", "http://localhost:8000/media/audio/am/l/a.m4a"]
    )
    def test_local_links_with_or_without_the_host(self, url: str) -> None:
        assert key_of(url, "/media/audio/") == "am/l/a.m4a"

    def test_audio_extensions(self) -> None:
        assert is_audio("am/l/a.M4A") and is_audio("x.wav")
        assert not is_audio("am/l/a.webp") and not is_audio("am/l/noext")

    def test_slugs_are_ascii_with_a_fallback_for_fidel(self) -> None:
        assert slug("English to Amharic!") == "english-to-amharic"
        assert slug("Café — Ordering") == "cafe-ordering"
        assert slug("ሰላምታ", "section") == "section"
        assert len(slug("a" * 80)) == 40

    def test_safe_keys(self) -> None:
        assert is_safe_key("trash/am/l/gen-am-x-1.m4a")
        assert not is_safe_key("am/../x") and not is_safe_key("a\\b")
