"""Audio uploads saved by the local backend itself (bolt
`041-local-audio-storage`), until R2 serves files.

It hands out the same kind of link as `R2Storage`: a short-lived `PUT`
address whose query string carries a signature over the key, content type,
size and expiry. The admin site cannot tell the two stores apart. The file
lands in `backend/media/audio/{key}` and plays from `/media/audio/{key}`.

Keys are laid out as on R2 (`{language}/{lesson}/{12 hex}.{ext}`), so moving
to R2 later is a copy under the same keys plus a rewrite of the stored
`/media/audio/` prefix.

Only ever used when `environment == "local"` and R2 is not configured; see
`choose_audio_storage`.

Bolt `050-image-choice-service` made the store serve one `MediaKind` each:
`AUDIO` as before, or `IMAGES` -- pictures in `backend/media/images/`,
loaded from `/media/images/{key}` and uploaded through their own route. The
class keeps its name so audio code and tests are unchanged. The kind is
part of every signature, so a link for one kind never uploads the other.
"""

from __future__ import annotations

import hashlib
import hmac
import os
import re
import secrets
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from urllib.parse import urlencode

from app.config import Settings
from app.domain.lesson.exceptions import (
    AudioFileExistsError,
    InvalidUploadLinkError,
    UploadLinkExpiredError,
)
from app.infrastructure.external.r2_storage import PresignedUpload, R2Storage
from app.infrastructure.media import AUDIO_DIR, AUDIO_URL_PREFIX, IMAGES_DIR, IMAGES_URL_PREFIX

UPLOAD_ROUTE = "/api/v1/audio-files"
IMAGE_UPLOAD_ROUTE = "/api/v1/image-files"

# Exactly the keys `presign_upload` builds, and nothing else: no `..`, no
# absolute paths, no separators beyond the two, so a key can only ever name
# a file two folders below AUDIO_DIR.
KEY_PATTERN = re.compile(r"[a-z]{2,3}/[A-Za-z0-9_-]{1,64}/[0-9a-f]{12}\.(?:m4a|mp3|webm|ogg)")
# The same layout for pictures, with the two extensions
# `presign_image_upload` builds.
IMAGE_KEY_PATTERN = re.compile(r"[a-z]{2,3}/[A-Za-z0-9_-]{1,64}/[0-9a-f]{12}\.(?:webp|jpg)")


@dataclass(frozen=True)
class MediaKind:
    """One kind of uploaded file: the URL it loads from, the route that
    receives it, and the keys it may have. Its folder is looked up when a
    store is made (`_root_of`), so tests can point it elsewhere."""

    name: str
    url_prefix: str
    upload_route: str
    key_pattern: re.Pattern[str]


AUDIO = MediaKind("audio", AUDIO_URL_PREFIX, UPLOAD_ROUTE, KEY_PATTERN)
IMAGES = MediaKind("images", IMAGES_URL_PREFIX, IMAGE_UPLOAD_ROUTE, IMAGE_KEY_PATTERN)


def _root_of(kind: MediaKind) -> Path:
    return IMAGES_DIR if kind is IMAGES else AUDIO_DIR


# Links last minutes, so a secret that dies with the process only voids
# links nobody is still using. Local development runs one process.
_PROCESS_SECRET = secrets.token_bytes(32)


def is_valid_key(key: str, kind: MediaKind = AUDIO) -> bool:
    return kind.key_pattern.fullmatch(key) is not None


@dataclass(frozen=True)
class LocalAudioStorage:
    root: Path
    # Where the browser reaches this backend, e.g. `http://localhost:8000`.
    upload_base_url: str
    secret: bytes
    kind: MediaKind = AUDIO

    def _signature(self, key: str, content_type: str, size: int, expires: int) -> str:
        message = f"{self.kind.name}\n{key}\n{content_type}\n{size}\n{expires}".encode()
        return hmac.new(self.secret, message, hashlib.sha256).hexdigest()

    def presign_put(
        self,
        key: str,
        *,
        content_type: str,
        size: int,
        expires_in: int,
        now: datetime | None = None,
    ) -> PresignedUpload:
        """A PUT link to this backend for exactly this key, type and size."""
        expires = int((now or datetime.now(UTC)).timestamp()) + expires_in
        query = urlencode(
            {
                "type": content_type,
                "size": size,
                "expires": expires,
                "sig": self._signature(key, content_type, size, expires),
            }
        )
        return PresignedUpload(
            url=f"{self.upload_base_url}{self.kind.upload_route}/{key}?{query}",
            headers={"Content-Type": content_type},
            public_url=f"{self.kind.url_prefix}/{key}",
            expires_in=expires_in,
        )

    def verify(
        self,
        key: str,
        *,
        content_type: str,
        size: int,
        expires: int,
        signature: str,
        now: datetime | None = None,
    ) -> None:
        """Raises unless the link was issued by this process, unaltered, and
        has not expired. The signature is checked first, so an altered
        expiry reads as a bad link, not as a live one."""
        expected = self._signature(key, content_type, size, expires)
        if not hmac.compare_digest(expected, signature):
            raise InvalidUploadLinkError("This upload link is not valid; ask for a new one")
        if int((now or datetime.now(UTC)).timestamp()) > expires:
            raise UploadLinkExpiredError("This upload link has expired; ask for a new one")

    def path_for(self, key: str) -> Path:
        if not is_valid_key(key, self.kind):
            raise InvalidUploadLinkError("This upload link is not valid; ask for a new one")
        return self.root / key

    def save(self, key: str, body: bytes) -> None:
        """Writes the whole file or nothing, and never replaces one: it is
        written beside its final name, then hard-linked into place, which
        fails if that name is taken."""
        path = self.path_for(key)
        if path.exists():
            raise AudioFileExistsError("A file is already saved under this key")
        path.parent.mkdir(parents=True, exist_ok=True)
        temp = path.with_name(f".{path.name}.{secrets.token_hex(4)}.part")
        try:
            temp.write_bytes(body)
            try:
                os.link(temp, path)
            except FileExistsError as exc:
                raise AudioFileExistsError("A file is already saved under this key") from exc
        finally:
            temp.unlink(missing_ok=True)


def choose_audio_storage(
    settings: Settings, *, upload_base_url: str, kind: MediaKind = AUDIO
) -> R2Storage | LocalAudioStorage | None:
    """R2 whenever it is fully configured; otherwise, only in local
    development, this backend; otherwise nothing (uploads answer 503).
    Pictures share the audio's R2 bucket, told apart by extension."""
    r2 = R2Storage.from_settings(settings)
    if r2 is not None:
        return r2
    if settings.environment == "local":
        return LocalAudioStorage(
            root=_root_of(kind),
            upload_base_url=upload_base_url.rstrip("/"),
            secret=_PROCESS_SECRET,
            kind=kind,
        )
    return None


def choose_image_storage(
    settings: Settings, *, upload_base_url: str
) -> R2Storage | LocalAudioStorage | None:
    """`choose_audio_storage` for pictures (bolt 050)."""
    return choose_audio_storage(settings, upload_base_url=upload_base_url, kind=IMAGES)
