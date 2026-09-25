"""Receives uploads for the local media store: `PUT /api/v1/audio-files/{key}`
(bolt `041-local-audio-storage`) and `PUT /api/v1/image-files/{key}` (bolt
`050-image-choice-service`).

Deliberately outside the admin router: like an R2 presigned link, the
request is authorised by the signature `POST /admin/audio/uploads` or
`POST /admin/images/uploads` put in its query string, not by a bearer
token, so the admin site uploads the same way to either store. Answers
`404` whenever the local store is not the one in use -- in production, or
once R2 is configured -- so the routes might as well not exist there.
"""

from __future__ import annotations

import logging

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel

from app.application.admin_audio_use_cases import MAX_UPLOAD_BYTES
from app.application.admin_image_use_cases import MAX_IMAGE_UPLOAD_BYTES
from app.config import get_settings
from app.domain.lesson.exceptions import InvalidContentError
from app.infrastructure.external.local_audio_storage import (
    AUDIO,
    IMAGES,
    LocalAudioStorage,
    MediaKind,
    choose_audio_storage,
    is_valid_key,
)

logger = logging.getLogger("app.admin")

router = APIRouter(prefix=AUDIO.upload_route, tags=["audio"])
image_router = APIRouter(prefix=IMAGES.upload_route, tags=["images"])


class AudioFileResponse(BaseModel):
    key: str
    public_url: str


def _local_storage(request: Request, kind: MediaKind) -> LocalAudioStorage | None:
    storage = choose_audio_storage(get_settings(), upload_base_url=str(request.base_url), kind=kind)
    return storage if isinstance(storage, LocalAudioStorage) else None


def get_local_audio_storage(request: Request) -> LocalAudioStorage | None:
    """Overridable in tests; `None` unless the local store is in use."""
    return _local_storage(request, AUDIO)


def get_local_image_storage(request: Request) -> LocalAudioStorage | None:
    """Overridable in tests; `None` unless the local store is in use."""
    return _local_storage(request, IMAGES)


async def _read_at_most(request: Request, limit: int) -> bytes | None:
    """The body, or `None` as soon as it passes `limit` bytes -- so an
    oversized upload is never held in memory."""
    chunks: list[bytes] = []
    total = 0
    async for chunk in request.stream():
        total += len(chunk)
        if total > limit:
            return None
        chunks.append(chunk)
    return b"".join(chunks)


async def _receive(
    kind: MediaKind,
    max_bytes: int,
    key: str,
    request: Request,
    *,
    content_type: str,
    size: int,
    expires: int,
    sig: str,
    storage: LocalAudioStorage | None,
) -> AudioFileResponse:
    if storage is None or storage.kind is not kind or not is_valid_key(key, kind):
        raise HTTPException(status_code=404)

    storage.verify(key, content_type=content_type, size=size, expires=expires, signature=sig)

    sent_type = request.headers.get("content-type", "").split(";")[0].strip().lower()
    if sent_type != content_type:
        raise InvalidContentError(
            "content_type", f"Send the file with Content-Type {content_type}, as the link says"
        )
    body = await _read_at_most(request, min(size, max_bytes))
    if body is None or len(body) != size:
        raise InvalidContentError(
            "size", f"The file must be exactly {size} bytes, as the link says"
        )

    storage.save(key, body)
    logger.info("admin_write action=upload entity=%s id=%s bytes=%d", kind.name, key, size)
    return AudioFileResponse(key=key, public_url=f"{kind.url_prefix}/{key}")


@router.put("/{key:path}", response_model=AudioFileResponse, status_code=201)
async def put_audio_file(
    key: str,
    request: Request,
    content_type: str = Query(alias="type"),
    size: int = Query(),
    expires: int = Query(),
    sig: str = Query(),
    storage: LocalAudioStorage | None = Depends(get_local_audio_storage),
) -> AudioFileResponse:
    return await _receive(
        AUDIO,
        MAX_UPLOAD_BYTES,
        key,
        request,
        content_type=content_type,
        size=size,
        expires=expires,
        sig=sig,
        storage=storage,
    )


@image_router.put("/{key:path}", response_model=AudioFileResponse, status_code=201)
async def put_image_file(
    key: str,
    request: Request,
    content_type: str = Query(alias="type"),
    size: int = Query(),
    expires: int = Query(),
    sig: str = Query(),
    storage: LocalAudioStorage | None = Depends(get_local_image_storage),
) -> AudioFileResponse:
    return await _receive(
        IMAGES,
        MAX_IMAGE_UPLOAD_BYTES,
        key,
        request,
        content_type=content_type,
        size=size,
        expires=expires,
        sig=sig,
        storage=storage,
    )
