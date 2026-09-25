"""Pictures for picture questions, from the admin API (bolt
`050-image-choice-service`, story 002-picture-upload-links).

The same flow as audio (`admin_audio_use_cases.py`): the admin site asks
for a short-lived PUT link bound to one content type and exact size, uploads
straight to storage, then saves the returned address as a choice's
`image_url` through the ordinary exercise update. The site shrinks and
re-encodes every picture before asking (bolt 052), so only its two output
formats are accepted, and the limit is far below audio's.
"""

from __future__ import annotations

import logging
import secrets

from app.application.admin_audio_use_cases import UPLOAD_LINK_SECONDS, AudioStore
from app.application.admin_content_use_cases import AdminContext
from app.domain.lesson.exceptions import (
    AudioStorageNotConfiguredError,
    ContentNotFoundError,
    InvalidContentError,
)
from app.infrastructure.db.admin_content_repository import SqlAlchemyAdminContentRepository
from app.infrastructure.external.r2_storage import PresignedUpload

logger = logging.getLogger("app.admin")

# Content type -> file extension: what the admin site's shrinking produces,
# WebP, or JPEG where the browser cannot encode WebP.
IMAGE_TYPES: dict[str, str] = {
    "image/webp": "webp",
    "image/jpeg": "jpg",
}
MAX_IMAGE_UPLOAD_BYTES = 1024 * 1024


async def presign_image_upload(
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
    if base_type not in IMAGE_TYPES:
        raise InvalidContentError(
            "content_type", f"Pictures must be one of: {', '.join(sorted(IMAGE_TYPES))}"
        )
    if not 0 < size <= MAX_IMAGE_UPLOAD_BYTES:
        raise InvalidContentError("size", "Pictures must be between 1 byte and 1 MB")
    if storage is None:
        raise AudioStorageNotConfiguredError("Picture storage is not configured on this server")
    language = await repo.learning_language_of_lesson(lesson_id)
    if language is None:
        raise ContentNotFoundError("No such lesson", entity="lesson", id=lesson_id)

    key = f"{language}/{lesson_id}/{secrets.token_hex(6)}.{IMAGE_TYPES[base_type]}"
    upload = storage.presign_put(
        key, content_type=base_type, size=size, expires_in=UPLOAD_LINK_SECONDS
    )
    logger.info("admin_write action=presign entity=image id=%s admin=%s", key, ctx.email)
    return key, upload
