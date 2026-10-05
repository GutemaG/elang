"""A course's draft curriculum, admin only (intent
`025-curriculum-workspace`). Learners never see it; a finished lesson is
published into the course.

- `GET /api/v1/admin/courses/{course_id}/curriculum`: the plan, every row
  and the counts.
- `PUT .../curriculum`: imports the curriculum workbook (read into JSON by
  the admin site), merging by ref; `?dry_run=true` saves nothing.
- `PATCH .../curriculum/rows/{ref}`: corrects, reviews or records one row.
- `POST .../curriculum/audio/uploads`: a PUT link for a row's recording.
- `GET` / `PUT .../curriculum/lessons/{ref}/exercises`: a lesson's draft
  exercises (bolt 085).
- `POST .../curriculum/lessons/{ref}/publish`: copies a finished lesson
  into the course (bolt 085).
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.application import curriculum_use_cases as uc
from app.application.admin_content_use_cases import AdminContext
from app.config import get_settings
from app.domain.entities import User
from app.infrastructure.api.admin_routers import get_audio_storage
from app.infrastructure.api.admin_schemas import AudioUploadResponse
from app.infrastructure.api.curriculum_schemas import (
    Curriculum,
    CurriculumCounts,
    CurriculumEntry,
    CurriculumRow,
    CurriculumUploadRequest,
    DraftExercise,
    DraftExerciseList,
    ImportCurriculumRequest,
    ImportCurriculumResponse,
    ImportTally,
    PublishLessonResponse,
    SaveDraftExercisesRequest,
    UpdateCurriculumRowRequest,
    UpdateCurriculumRowResponse,
)
from app.infrastructure.api.dependencies import require_admin
from app.infrastructure.db.admin_content_repository import SqlAlchemyAdminContentRepository
from app.infrastructure.db.curriculum_models import CurriculumExerciseModel, CurriculumRowModel
from app.infrastructure.db.curriculum_repository import SqlAlchemyCurriculumRepository
from app.infrastructure.db.session import get_db_session
from app.infrastructure.external.local_audio_storage import LocalAudioStorage
from app.infrastructure.external.r2_storage import R2Storage

router = APIRouter(
    prefix="/api/v1/admin/courses/{course_id}/curriculum",
    tags=["admin"],
    dependencies=[Depends(require_admin)],
)


async def _repo(session: AsyncSession = Depends(get_db_session)) -> SqlAlchemyCurriculumRepository:
    return SqlAlchemyCurriculumRepository(session)


async def _content(
    session: AsyncSession = Depends(get_db_session),
) -> SqlAlchemyAdminContentRepository:
    """The course's live tree, in the same transaction as the curriculum."""
    return SqlAlchemyAdminContentRepository(session)


async def _ctx(admin: User = Depends(require_admin)) -> AdminContext:
    return AdminContext(
        email=admin.email or "", allow_local_media=get_settings().environment == "local"
    )


def _row(r: CurriculumRowModel) -> CurriculumRow:
    return CurriculumRow(
        ref=r.ref,
        kind=r.kind,
        lesson_ref=r.lesson_ref,
        position=r.position,
        english=r.english,
        text=r.text,
        romanization=r.romanization,
        blank=r.blank,
        accepted=list(r.accepted or []),
        notes=r.notes,
        confidence=r.confidence,
        status=r.status,
        comment=r.comment,
        audio_url=r.audio_url,
        version=r.version,
        updated_by=r.updated_by,
        updated_at=r.updated_at,
    )


def _curriculum(view: uc.CurriculumView) -> Curriculum:
    return Curriculum(
        course_id=view.course.id,
        course_title=view.course.title,
        language=view.course.learning_language,
        entries=[
            CurriculumEntry(
                ref=e.ref,
                kind=e.kind,
                parent_ref=e.parent_ref,
                position=e.position,
                title=e.title,
                goal=e.goal,
                grammar=e.grammar,
                counts=(
                    CurriculumCounts(**view.lesson_counts[e.ref].__dict__)
                    if e.ref in view.lesson_counts
                    else None
                ),
                published_id=e.published_id,
                published_at=e.published_at,
                publish_state=view.publish_states.get(e.ref),
                exercise_count=view.exercise_counts.get(e.ref),
            )
            for e in view.entries
        ],
        rows=[_row(r) for r in view.rows],
        counts=CurriculumCounts(**view.total.__dict__),
    )


@router.get("", response_model=Curriculum)
async def get_curriculum(
    course_id: str, repo: SqlAlchemyCurriculumRepository = Depends(_repo)
) -> Curriculum:
    """The course's plan (entries by position) and rows (by lesson, then
    position), with counts per lesson and in all. Empty lists when nothing
    has been imported."""
    return _curriculum(await uc.get_curriculum(repo, course_id))


@router.put("", response_model=ImportCurriculumResponse)
async def import_curriculum(
    course_id: str,
    body: ImportCurriculumRequest,
    dry_run: bool = Query(default=False),
    repo: SqlAlchemyCurriculumRepository = Depends(_repo),
    ctx: AdminContext = Depends(_ctx),
) -> ImportCurriculumResponse:
    """Merges entries and rows by ref, all or nothing: any problem is
    `422 invalid_import` with every one in `details.rows`. A row that is
    reviewed or recorded is kept as it is unless `overwrite_reviewed`.
    Saved items missing from the file are left alone and listed."""
    result = await uc.import_curriculum(
        repo,
        ctx,
        course_id,
        entries=[e.model_dump() for e in body.entries],
        rows=[r.model_dump() for r in body.rows],
        overwrite_reviewed=body.overwrite_reviewed,
        dry_run=dry_run,
    )
    return ImportCurriculumResponse(
        dry_run=result.dry_run,
        entries=ImportTally(**result.entries.__dict__),
        rows=ImportTally(**result.rows.__dict__),
        kept=result.kept,
        missing_entries=result.missing_entries,
        missing_rows=result.missing_rows,
    )


@router.patch("/rows/{ref}", response_model=UpdateCurriculumRowResponse)
async def update_curriculum_row(
    course_id: str,
    ref: str,
    body: UpdateCurriculumRowRequest,
    repo: SqlAlchemyCurriculumRepository = Depends(_repo),
    ctx: AdminContext = Depends(_ctx),
) -> UpdateCurriculumRowResponse:
    """Changes the fields sent. `version` must be the saved one, else
    `409 content_changed` with `details.current_version`. Changing the text
    or romanization of a recorded row sends it back to Draft."""
    changes = body.model_dump(exclude_unset=True, exclude={"version"})
    row, reset = await uc.update_row(
        repo, ctx, course_id, ref, version=body.version, changes=changes
    )
    return UpdateCurriculumRowResponse(row=_row(row), reset_to_draft=reset)


@router.post("/audio/uploads", response_model=AudioUploadResponse, status_code=201)
async def create_curriculum_upload(
    course_id: str,
    body: CurriculumUploadRequest,
    repo: SqlAlchemyCurriculumRepository = Depends(_repo),
    ctx: AdminContext = Depends(_ctx),
    storage: R2Storage | LocalAudioStorage | None = Depends(get_audio_storage),
) -> AudioUploadResponse:
    """A short-lived PUT link for one row's recording; save its
    `public_url` as the row's `audio_url` afterwards."""
    key, upload = await uc.presign_upload(
        repo,
        ctx,
        storage,
        course_id,
        row_ref=body.row_ref,
        content_type=body.content_type,
        size=body.size,
    )
    return AudioUploadResponse(
        upload_url=upload.url,
        headers=upload.headers,
        key=key,
        public_url=upload.public_url,
        expires_in=upload.expires_in,
    )


def _draft(x: CurriculumExerciseModel) -> DraftExercise:
    return DraftExercise(
        type=x.type,
        prompt=x.prompt,
        content=x.content,
        answer_key=x.answer_key,
        vocab_ref=x.vocab_ref,
        generated=x.generated,
        edited=x.edited,
    )


@router.get("/lessons/{ref}/exercises", response_model=DraftExerciseList)
async def list_draft_exercises(
    course_id: str, ref: str, repo: SqlAlchemyCurriculumRepository = Depends(_repo)
) -> DraftExerciseList:
    """A lesson's draft exercises in order; empty until generated."""
    drafts = await uc.list_draft_exercises(repo, course_id, ref)
    return DraftExerciseList(exercises=[_draft(x) for x in drafts])


@router.put("/lessons/{ref}/exercises", response_model=DraftExerciseList)
async def save_draft_exercises(
    course_id: str,
    ref: str,
    body: SaveDraftExercisesRequest,
    repo: SqlAlchemyCurriculumRepository = Depends(_repo),
    ctx: AdminContext = Depends(_ctx),
) -> DraftExerciseList:
    """Replaces the lesson's draft exercises. `409 lesson_not_ready` until
    every row is reviewed and recorded; each one is checked like the
    exercise endpoints, every failure listed by index (`422 invalid_import`)."""
    items = [uc.DraftExerciseInput(**x.model_dump()) for x in body.exercises]
    drafts = await uc.save_draft_exercises(repo, ctx, course_id, ref, items)
    return DraftExerciseList(exercises=[_draft(x) for x in drafts])


@router.post("/lessons/{ref}/publish", response_model=PublishLessonResponse)
async def publish_lesson(
    course_id: str,
    ref: str,
    repo: SqlAlchemyCurriculumRepository = Depends(_repo),
    content: SqlAlchemyAdminContentRepository = Depends(_content),
    ctx: AdminContext = Depends(_ctx),
) -> PublishLessonResponse:
    """Copies the finished lesson into the course beside what is there,
    making its section and skill the first time. Publishing again keeps the
    lesson (and learners' progress) and replaces only the exercises it
    published before. `409 lesson_not_ready` with `details.reason` (`rows`
    or `exercises`) when it cannot be published yet."""
    result = await uc.publish_lesson(repo, content, ctx, course_id, ref)
    return PublishLessonResponse(**result.__dict__)
