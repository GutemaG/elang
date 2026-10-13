"""Reading, moving and deleting stored audio (intent 029, FR-1).

The upload stores (`R2Storage`, `LocalAudioStorage`) only hand out links to
put a file. The Audio library also needs to see what is there, give the
admin site a link to fetch a file, move a file to the trash and back, and
delete it. Both stores get a `MediaLibrary` here:

- `R2MediaLibrary` calls R2's S3 API (`ListObjectsV2`, `GET`, `CopyObject`,
  `DeleteObject`) with `httpx`, each request signed by the same stdlib
  `presign` as uploads. The secret is only used to sign; it never appears
  in a link the browser gets, a response or a log line.
- `LocalMediaLibrary` works on `backend/media/audio/`, as the local store
  does.

Keys are checked before any call (`is_safe_key`), so a key can't climb out
of the bucket or the folder.
"""

from __future__ import annotations

import os
import re
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from datetime import UTC, datetime
from pathlib import Path
from typing import Protocol
from urllib.parse import quote

import httpx

from app.config import Settings
from app.domain.lesson.exceptions import (
    AudioFileExistsError,
    AudioFileNotFoundError,
    AudioStorageUnavailableError,
)
from app.infrastructure.external.r2_storage import R2Storage, presign
from app.infrastructure.media import AUDIO_DIR, AUDIO_URL_PREFIX

# A file link for the admin site lasts this long: long enough to download a
# few hundred files one after another.
DOWNLOAD_LINK_SECONDS = 900
_S3_NS = "{http://s3.amazonaws.com/doc/2006-03-01/}"
_SAFE_KEY = re.compile(r"[A-Za-z0-9_-][A-Za-z0-9_.-]*(?:/[A-Za-z0-9_-][A-Za-z0-9_.-]*)*")


def is_safe_key(key: str) -> bool:
    """Relative, `/`-separated, no `..` and no empty or hidden parts."""
    return len(key) <= 512 and _SAFE_KEY.fullmatch(key) is not None and ".." not in key


def _check(key: str) -> str:
    if not is_safe_key(key):
        raise AudioFileNotFoundError("No stored file has this key", key=key)
    return key


@dataclass(frozen=True)
class StoredFile:
    key: str
    size: int
    uploaded_at: datetime


class MediaLibrary(Protocol):
    """What the Audio library needs from a store."""

    @property
    def name(self) -> str: ...

    # Where a stored link to `{key}` starts, e.g. `https://pub-x.r2.dev/`.
    @property
    def public_prefix(self) -> str: ...

    def public_url(self, key: str) -> str: ...

    async def list_files(self, prefix: str = "") -> list[StoredFile]: ...

    def download_url(self, key: str) -> str: ...

    async def move(self, key: str, to_key: str) -> None: ...

    async def delete(self, key: str) -> None: ...


@dataclass(frozen=True)
class R2MediaLibrary:
    storage: R2Storage
    transport: httpx.AsyncBaseTransport | None = None
    timeout: float = 20.0
    now: datetime | None = None
    name: str = field(default="r2", init=False)

    @property
    def public_prefix(self) -> str:
        return f"{self.storage.public_base_url}/"

    def public_url(self, key: str) -> str:
        return f"{self.storage.public_base_url}/{key}"

    def _url(
        self,
        method: str,
        path: str,
        *,
        headers: dict[str, str] | None = None,
        params: dict[str, str] | None = None,
        expires_in: int = 300,
    ) -> str:
        return presign(
            method=method,
            host=self.storage.host,
            path=path,
            headers=headers or {},
            access_key_id=self.storage.access_key_id,
            secret_access_key=self.storage.secret_access_key,
            region="auto",
            now=self.now or datetime.now(UTC),
            expires_in=expires_in,
            params=params,
        )

    async def _send(
        self, method: str, url: str, headers: dict[str, str] | None = None
    ) -> httpx.Response:
        try:
            async with httpx.AsyncClient(timeout=self.timeout, transport=self.transport) as client:
                return await client.request(method, url, headers=headers)
        except httpx.HTTPError as exc:
            # The URL carries a signature; only the kind of failure is kept.
            raise AudioStorageUnavailableError(
                f"Could not reach the audio store ({type(exc).__name__})"
            ) from None

    @staticmethod
    def _fail(response: httpx.Response) -> AudioStorageUnavailableError:
        return AudioStorageUnavailableError(
            f"The audio store answered {response.status_code}", status=response.status_code
        )

    async def list_files(self, prefix: str = "") -> list[StoredFile]:
        files: list[StoredFile] = []
        token: str | None = None
        while True:
            params = {"list-type": "2", "prefix": prefix, "max-keys": "1000"}
            if token:
                params["continuation-token"] = token
            response = await self._send(
                "GET", self._url("GET", f"/{self.storage.bucket}", params=params)
            )
            if response.status_code != 200:
                raise self._fail(response)
            try:
                root = ET.fromstring(response.content)
            except ET.ParseError:
                raise AudioStorageUnavailableError(
                    "The audio store sent an unreadable list"
                ) from None
            for item in root.iter(f"{_S3_NS}Contents"):
                key = item.findtext(f"{_S3_NS}Key") or ""
                files.append(
                    StoredFile(
                        key=key,
                        size=int(item.findtext(f"{_S3_NS}Size") or 0),
                        uploaded_at=datetime.fromisoformat(
                            (item.findtext(f"{_S3_NS}LastModified") or "").replace("Z", "+00:00")
                        ),
                    )
                )
            truncated = (root.findtext(f"{_S3_NS}IsTruncated") or "").lower() == "true"
            token = root.findtext(f"{_S3_NS}NextContinuationToken")
            if not truncated or not token:
                return files

    def download_url(self, key: str) -> str:
        return self._url(
            "GET", f"/{self.storage.bucket}/{_check(key)}", expires_in=DOWNLOAD_LINK_SECONDS
        )

    async def move(self, key: str, to_key: str) -> None:
        bucket = self.storage.bucket
        source = f"/{bucket}/{quote(_check(key), safe='/')}"
        headers = {"x-amz-copy-source": source}
        response = await self._send(
            "PUT", self._url("PUT", f"/{bucket}/{_check(to_key)}", headers=headers), headers
        )
        if response.status_code == 404:
            raise AudioFileNotFoundError("No stored file has this key", key=key)
        if response.status_code != 200:
            raise self._fail(response)
        await self.delete(key)

    async def delete(self, key: str) -> None:
        response = await self._send(
            "DELETE", self._url("DELETE", f"/{self.storage.bucket}/{_check(key)}")
        )
        # S3 answers 204 whether or not the key was there.
        if response.status_code not in (200, 204):
            raise self._fail(response)


@dataclass(frozen=True)
class LocalMediaLibrary:
    root: Path
    # Where the browser reaches this backend, e.g. `http://localhost:8000`.
    base_url: str
    name: str = field(default="local", init=False)

    @property
    def public_prefix(self) -> str:
        return f"{AUDIO_URL_PREFIX}/"

    def public_url(self, key: str) -> str:
        return f"{self.base_url}{AUDIO_URL_PREFIX}/{key}"

    def _path(self, key: str) -> Path:
        return self.root / _check(key)

    async def list_files(self, prefix: str = "") -> list[StoredFile]:
        if not self.root.is_dir():
            return []
        files = []
        for path in self.root.rglob("*"):
            key = path.relative_to(self.root).as_posix()
            if not path.is_file() or not key.startswith(prefix) or not is_safe_key(key):
                continue
            stat = path.stat()
            files.append(StoredFile(key, stat.st_size, datetime.fromtimestamp(stat.st_mtime, UTC)))
        return files

    def download_url(self, key: str) -> str:
        return self.public_url(_check(key))

    async def move(self, key: str, to_key: str) -> None:
        source, target = self._path(key), self._path(to_key)
        if not source.is_file():
            raise AudioFileNotFoundError("No stored file has this key", key=key)
        if target.exists():
            raise AudioFileExistsError("A file is already saved under this key", key=to_key)
        target.parent.mkdir(parents=True, exist_ok=True)
        os.replace(source, target)

    async def delete(self, key: str) -> None:
        self._path(key).unlink(missing_ok=True)


def choose_media_library(
    settings: Settings, *, base_url: str
) -> R2MediaLibrary | LocalMediaLibrary | None:
    """As `choose_audio_storage`: R2 when configured, else the local folder
    in local development, else nothing (the library answers 503)."""
    r2 = R2Storage.from_settings(settings)
    if r2 is not None:
        return R2MediaLibrary(r2)
    if settings.environment == "local":
        return LocalMediaLibrary(root=AUDIO_DIR, base_url=base_url.rstrip("/"))
    return None
