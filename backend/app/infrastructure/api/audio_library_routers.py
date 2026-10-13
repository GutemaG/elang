"""The Audio library's API (intent 029): `/api/v1/admin/audio-files`. Super
admins only, through the router-level `require_super_admin`.

- `GET` lists stored files with their uses, missing files and the trash.
- `GET /export` lists what a backup ZIP holds, with download links; the
  admin site fetches the files and builds the ZIP itself.
- `POST /trash`, `/trash/restore`, `/trash/delete` move unused files to
  the trash, back, or delete them for good.
"""

from __future__ import annotations

from datetime import UTC, datetime

from fastapi import APIRouter, Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.application import audio_library_use_cases as uc
from app.config import get_settings
from app.domain.admin import AdminAccess
from app.domain.lesson.exceptions import AudioStorageNotConfiguredError
from app.infrastructure.api.audio_library_schemas import (
    AudioExportResponse,
    AudioFileResponse,
    AudioKeysRequest,
    AudioKeysResponse,
    AudioLibraryResponse,
    AudioTotals,
    AudioUseResponse,
    ExportFileResponse,
    ExportRowResponse,
    LibraryCourse,
    MissingAudioResponse,
    TrashedAudioResponse,
)
from app.infrastructure.api.dependencies import require_super_admin
from app.infrastructure.db.audio_library_repository import SqlAlchemyAudioLibraryRepository
from app.infrastructure.db.session import get_db_session
from app.infrastructure.external.media_library import MediaLibrary, choose_media_library

router = APIRouter(
    prefix="/api/v1/admin/audio-files",
    tags=["admin"],
    dependencies=[Depends(require_super_admin)],
)


def get_media_library(request: Request) -> MediaLibrary | None:
    """Overridable in tests."""
    return choose_media_library(get_settings(), base_url=str(request.base_url))


def get_now() -> datetime:
    """Overridable in tests."""
    return datetime.now(UTC)


def _library(library: MediaLibrary | None = Depends(get_media_library)) -> MediaLibrary:
    if library is None:
        raise AudioStorageNotConfiguredError("Audio storage is not configured on this server")
    return library


async def _repo(
    session: AsyncSession = Depends(get_db_session),
) -> SqlAlchemyAudioLibraryRepository:
    return SqlAlchemyAudioLibraryRepository(session)


def _use(u: uc.Use) -> AudioUseResponse:
    return AudioUseResponse(
        place=u.place,
        language=u.language,
        admin_path=u.admin_path,
        course_id=u.course_id,
        course_title=u.course_title,
        section=u.section,
        skill=u.skill,
        lesson=u.lesson,
        exercise_id=u.exercise_id,
        exercise_number=u.exercise_number,
        exercise_type=u.exercise_type,
        prompt=u.prompt,
        text=u.text,
        english=u.english,
        letter=u.letter,
    )


@router.get("", response_model=AudioLibraryResponse)
async def list_audio_files(
    repo: SqlAlchemyAudioLibraryRepository = Depends(_repo),
    library: MediaLibrary = Depends(_library),
    now: datetime = Depends(get_now),
) -> AudioLibraryResponse:
    lib = await uc.load_library(repo, library, now=now)
    return AudioLibraryResponse(
        storage=lib.storage,
        totals=AudioTotals(
            files=len(lib.files),
            bytes=sum(f.size for f in lib.files),
            in_use=sum(1 for f in lib.files if f.uses),
            unused=sum(1 for f in lib.files if not f.uses),
            missing=len(lib.missing),
            trash=len(lib.trash),
            trash_bytes=sum(f.size for f in lib.trash),
        ),
        files=[
            AudioFileResponse(
                key=f.key,
                url=f.url,
                size=f.size,
                uploaded_at=f.uploaded_at,
                language=f.language,
                source=f.source,
                status=f.status,
                can_trash=f.can_trash,
                uses=[_use(u) for u in f.uses],
            )
            for f in lib.files
        ],
        missing=[
            MissingAudioResponse(key=m.key, url=m.url, uses=[_use(u) for u in m.uses])
            for m in lib.missing
        ],
        trash=[
            TrashedAudioResponse(
                key=t.key, original_key=t.original_key, size=t.size, moved_at=t.moved_at
            )
            for t in lib.trash
        ],
        external_links=lib.external_links,
        courses=[
            LibraryCourse(id=c.id, title=c.title, learning_language=c.learning_language)
            for c in lib.courses
        ],
    )


@router.get("/export", response_model=AudioExportResponse)
async def export_audio_files(
    course_id: str | None = None,
    include_unused: bool = False,
    repo: SqlAlchemyAudioLibraryRepository = Depends(_repo),
    library: MediaLibrary = Depends(_library),
    now: datetime = Depends(get_now),
) -> AudioExportResponse:
    result = await uc.export(
        repo, library, course_id=course_id, include_unused=include_unused, now=now
    )
    return AudioExportResponse(
        name=result.name,
        files=[
            ExportFileResponse(
                zip_path=f.zip_path, key=f.key, size=f.size, download_url=f.download_url
            )
            for f in result.files
        ],
        rows=[
            ExportRowResponse(
                zip_path=r.zip_path,
                status=r.status,
                key=r.key,
                url=r.url,
                size=r.size,
                uploaded_at=r.uploaded_at,
                use=_use(r.use) if r.use else None,
            )
            for r in result.rows
        ],
    )


@router.post("/trash", response_model=AudioKeysResponse)
async def trash_audio_files(
    body: AudioKeysRequest,
    repo: SqlAlchemyAudioLibraryRepository = Depends(_repo),
    library: MediaLibrary = Depends(_library),
    now: datetime = Depends(get_now),
    access: AdminAccess = Depends(require_super_admin),
) -> AudioKeysResponse:
    count = await uc.trash_files(repo, library, body.keys, email=access.email, now=now)
    return AudioKeysResponse(count=count)


@router.post("/trash/restore", response_model=AudioKeysResponse)
async def restore_audio_files(
    body: AudioKeysRequest,
    library: MediaLibrary = Depends(_library),
    access: AdminAccess = Depends(require_super_admin),
) -> AudioKeysResponse:
    return AudioKeysResponse(count=await uc.restore_files(library, body.keys, email=access.email))


@router.post("/trash/delete", response_model=AudioKeysResponse)
async def delete_audio_files(
    body: AudioKeysRequest,
    library: MediaLibrary = Depends(_library),
    access: AdminAccess = Depends(require_super_admin),
) -> AudioKeysResponse:
    return AudioKeysResponse(count=await uc.delete_files(library, body.keys, email=access.email))
