"""Audio for listening exercises, from the admin API (bolt
`036-admin-audio-api`, story 005-audio-upload-and-link-api).

Either way the result is an address the admin then saves as the exercise's
`audio_url` through the ordinary exercise update: a full https address, or
in local development without R2 a `/media/audio/...` path (bolt 041), which
that update accepts only locally.
"""

from __future__ import annotations

import logging
import secrets
from typing import Protocol

from app.application.admin_content_use_cases import AdminContext
from app.domain.lesson.exceptions import (
    AudioStorageNotConfiguredError,
    ContentNotFoundError,
    InvalidContentError,
)
from app.infrastructure.db.admin_content_repository import SqlAlchemyAdminContentRepository
from app.infrastructure.external.audio_link_checker import AudioLinkChecker
from app.infrastructure.external.r2_storage import PresignedUpload

logger = logging.getLogger("app.admin")

# Content type -> file extension. The browser records `audio/mp4` (Chrome,
# Edge, Safari) or `audio/webm` (Firefox); uploads are usually m4a or mp3.
AUDIO_TYPES: dict[str, str] = {
    "audio/mp4": "m4a",
    "audio/x-m4a": "m4a",
    "audio/mpeg": "mp3",
    "audio/webm": "webm",
    "audio/ogg": "ogg",
}
MAX_UPLOAD_BYTES = 5 * 1024 * 1024
UPLOAD_LINK_SECONDS = 600


class AudioStore(Protocol):
    """Where uploads go: R2, or the local backend until R2 serves files
    (bolt 041). Both hand out the same kind of short-lived PUT link."""

    def presign_put(
        self, key: str, *, content_type: str, size: int, expires_in: int
    ) -> PresignedUpload: ...


async def presign_upload(
    repo: SqlAlchemyAdminContentRepository,
    ctx: AdminContext,
    storage: AudioStore | None,
    *,
    lesson_id: str,
    content_type: str,
    size: int,
) -> tuple[str, PresignedUpload]:
    """Returns the object key and a PUT link for exactly this type and size."""
    base_type = content_type.split(";")[0].strip().lower()
    if base_type not in AUDIO_TYPES:
        raise InvalidContentError(
            "content_type", f"Audio must be one of: {', '.join(sorted(AUDIO_TYPES))}"
        )
    if not 0 < size <= MAX_UPLOAD_BYTES:
        raise InvalidContentError("size", "Audio must be between 1 byte and 5 MB")
    if storage is None:
        raise AudioStorageNotConfiguredError("Audio storage is not configured on this server")
    language = await repo.learning_language_of_lesson(lesson_id)
    if language is None:
        raise ContentNotFoundError("No such lesson", entity="lesson", id=lesson_id)

    key = f"{language}/{lesson_id}/{secrets.token_hex(6)}.{AUDIO_TYPES[base_type]}"
    upload = storage.presign_put(
        key, content_type=base_type, size=size, expires_in=UPLOAD_LINK_SECONDS
    )
    logger.info("admin_write action=presign entity=audio id=%s admin=%s", key, ctx.email)
    return key, upload


async def check_audio_link(checker: AudioLinkChecker, url: str) -> tuple[str, str]:
    """Returns the cleaned link and its audio content type."""
    cleaned = url.strip()
    return cleaned, await checker.check(cleaned)
