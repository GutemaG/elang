"""FastAPI router for the content admin API: `/api/v1/admin/*`
(`017-content-admin-web`).

`require_admin` is a router-level dependency, so every endpoint added here
is admin-only without having to remember it (ADR-16). Routes stay thin:
request schema -> use case -> response schema.
"""

from __future__ import annotations

from collections import defaultdict
from typing import Any

from fastapi import APIRouter, Depends, Request, Response
from sqlalchemy.ext.asyncio import AsyncSession

from app.application import admin_audio_use_cases as audio_uc
from app.application import admin_content_use_cases as uc
from app.config import get_settings
from app.domain.entities import User
from app.domain.lesson.exceptions import ContentNotFoundError
from app.infrastructure.api.admin_schemas import (
    AdminCourse,
    AdminCourseList,
    AdminCourseTree,
    AdminExercise,
    AdminExerciseList,
    AdminMeResponse,
    AdminNode,
    AdminNodeList,
    AdminTreeExercise,
    AdminTreeLesson,
    AdminTreeSection,
    AdminTreeSkill,
    AudioLinkRequest,
    AudioLinkResponse,
    AudioStatus,
    AudioUploadRequest,
    AudioUploadResponse,
    CreateSectionRequest,
    ExerciseRequest,
    ReorderRequest,
    TitleRequest,
    UpdateSectionRequest,
    UpdateTitleRequest,
)
from app.infrastructure.api.dependencies import require_admin
from app.infrastructure.db.admin_content_repository import (
    EXERCISE,
    LESSON,
    SECTION,
    SKILL,
    SqlAlchemyAdminContentRepository,
)
from app.infrastructure.db.lesson_models import CourseModel, ExerciseModel
from app.infrastructure.db.seed_category_content import PLACEHOLDER_AUDIO_URL
from app.infrastructure.db.session import get_db_session
from app.infrastructure.external.audio_link_checker import AudioLinkChecker
from app.infrastructure.external.local_audio_storage import (
    LocalAudioStorage,
    choose_audio_storage,
)
from app.infrastructure.external.r2_storage import R2Storage

router = APIRouter(prefix="/api/v1/admin", tags=["admin"], dependencies=[Depends(require_admin)])


async def _repo(
    session: AsyncSession = Depends(get_db_session),
) -> SqlAlchemyAdminContentRepository:
    return SqlAlchemyAdminContentRepository(session)


async def _ctx(admin: User = Depends(require_admin)) -> uc.AdminContext:
    return uc.AdminContext(
        email=admin.email or "", allow_local_media=get_settings().environment == "local"
    )


def get_audio_storage(request: Request) -> R2Storage | LocalAudioStorage | None:
    """Overridable in tests. R2 when configured; in local development
    without R2, this backend (bolt 041); otherwise `None` (503)."""
    return choose_audio_storage(get_settings(), upload_base_url=str(request.base_url))


def get_audio_link_checker() -> AudioLinkChecker:
    """Overridable in tests, which never reach the network."""
    return AudioLinkChecker()


def _course(course: CourseModel, section_count: int) -> AdminCourse:
    return AdminCourse(
        id=course.id,
        title=course.title,
        learning_language=course.learning_language,
        from_language=course.from_language,
        status=course.status,
        section_count=section_count,
    )


def _node(row: Any) -> AdminNode:
    return AdminNode(
        id=row.id,
        title=row.title,
        subtitle=getattr(row, "subtitle", None),
        order_index=row.order_index,
    )


def _exercise(row: ExerciseModel) -> AdminExercise:
    return AdminExercise(
        id=row.id,
        lesson_id=row.lesson_id,
        order_index=row.order_index,
        type=row.type,
        prompt=row.prompt,
        content=row.content,
        answer_key=row.answer_key,
        vocab_item_id=row.vocab_item_id,
    )


def _audio_status(exercise_type: str, content: dict[str, Any]) -> AudioStatus | None:
    if exercise_type != "listening":
        return None
    url = content.get("audio_url", "")
    if url == PLACEHOLDER_AUDIO_URL:
        return "placeholder"
    return "local" if url.startswith("/") else "hosted"


@router.get("/me", response_model=AdminMeResponse)
async def get_admin_me(admin: User = Depends(require_admin)) -> AdminMeResponse:
    """Story 001-admin-authorization: who the admin site is signed in as."""
    return AdminMeResponse(email=admin.email or "")


# --- courses and the tree ---------------------------------------------------


@router.get("/courses", response_model=AdminCourseList)
async def list_courses(repo: SqlAlchemyAdminContentRepository = Depends(_repo)) -> AdminCourseList:
    return AdminCourseList(courses=[_course(c, n) for c, n in await repo.list_courses()])


@router.patch("/courses/{course_id}", response_model=AdminCourse)
async def rename_course(
    course_id: str,
    body: TitleRequest,
    repo: SqlAlchemyAdminContentRepository = Depends(_repo),
    ctx: uc.AdminContext = Depends(_ctx),
) -> AdminCourse:
    course = await uc.rename_course(repo, ctx, course_id, body.title)
    return _course(course, len(await repo.children(SECTION, course_id)))


@router.get("/courses/{course_id}/tree", response_model=AdminCourseTree)
async def get_course_tree(
    course_id: str, repo: SqlAlchemyAdminContentRepository = Depends(_repo)
) -> AdminCourseTree:
    course = await repo.get(CourseModel, course_id)
    if course is None:
        raise ContentNotFoundError("No such course", entity="course", id=course_id)
    sections, skills, lessons, exercises = await repo.course_tree(course_id)

    exercises_by_lesson: dict[str, list[AdminTreeExercise]] = defaultdict(list)
    for e in exercises:
        exercises_by_lesson[e.lesson_id].append(
            AdminTreeExercise(
                id=e.id,
                order_index=e.order_index,
                type=e.type,
                prompt=e.prompt,
                audio=_audio_status(e.type, e.content),
            )
        )
    lessons_by_skill: dict[str, list[AdminTreeLesson]] = defaultdict(list)
    for lesson in lessons:
        items = exercises_by_lesson[lesson.id]
        lessons_by_skill[lesson.skill_id].append(
            AdminTreeLesson(
                id=lesson.id,
                title=lesson.title,
                order_index=lesson.order_index,
                exercise_count=len(items),
                exercises=items,
            )
        )
    skills_by_section: dict[str, list[AdminTreeSkill]] = defaultdict(list)
    for skill in skills:
        items = lessons_by_skill[skill.id]
        skills_by_section[skill.category_id].append(
            AdminTreeSkill(
                id=skill.id,
                title=skill.title,
                order_index=skill.order_index,
                lesson_count=len(items),
                lessons=items,
            )
        )
    return AdminCourseTree(
        course=_course(course, len(sections)),
        sections=[
            AdminTreeSection(
                id=s.id,
                title=s.title,
                subtitle=s.subtitle,
                order_index=s.order_index,
                skill_count=len(skills_by_section[s.id]),
                skills=skills_by_section[s.id],
            )
            for s in sections
        ],
    )


# --- sections -----------------------------------------------------------------


@router.post("/courses/{course_id}/sections", response_model=AdminNode, status_code=201)
async def create_section(
    course_id: str,
    body: CreateSectionRequest,
    repo: SqlAlchemyAdminContentRepository = Depends(_repo),
    ctx: uc.AdminContext = Depends(_ctx),
) -> AdminNode:
    row = await uc.create_node(
        repo, ctx, SECTION, course_id, title=body.title, subtitle=body.subtitle
    )
    return _node(row)


@router.patch("/sections/{section_id}", response_model=AdminNode)
async def update_section(
    section_id: str,
    body: UpdateSectionRequest,
    repo: SqlAlchemyAdminContentRepository = Depends(_repo),
    ctx: uc.AdminContext = Depends(_ctx),
) -> AdminNode:
    row = await uc.rename_node(
        repo, ctx, SECTION, section_id, title=body.title, subtitle=body.subtitle
    )
    return _node(row)


@router.put("/courses/{course_id}/sections/order", response_model=AdminNodeList)
async def reorder_sections(
    course_id: str,
    body: ReorderRequest,
    repo: SqlAlchemyAdminContentRepository = Depends(_repo),
    ctx: uc.AdminContext = Depends(_ctx),
) -> AdminNodeList:
    rows = await uc.reorder_children(repo, ctx, SECTION, course_id, body.ids)
    return AdminNodeList(items=[_node(r) for r in rows])


@router.delete("/sections/{section_id}", status_code=204)
async def delete_section(
    section_id: str,
    confirm: bool = False,
    repo: SqlAlchemyAdminContentRepository = Depends(_repo),
    ctx: uc.AdminContext = Depends(_ctx),
) -> Response:
    await uc.delete_node(repo, ctx, SECTION, section_id, confirm=confirm)
    return Response(status_code=204)


# --- skills -------------------------------------------------------------------


@router.post("/sections/{section_id}/skills", response_model=AdminNode, status_code=201)
async def create_skill(
    section_id: str,
    body: TitleRequest,
    repo: SqlAlchemyAdminContentRepository = Depends(_repo),
    ctx: uc.AdminContext = Depends(_ctx),
) -> AdminNode:
    return _node(await uc.create_node(repo, ctx, SKILL, section_id, title=body.title))


@router.patch("/skills/{skill_id}", response_model=AdminNode)
async def update_skill(
    skill_id: str,
    body: UpdateTitleRequest,
    repo: SqlAlchemyAdminContentRepository = Depends(_repo),
    ctx: uc.AdminContext = Depends(_ctx),
) -> AdminNode:
    return _node(await uc.rename_node(repo, ctx, SKILL, skill_id, title=body.title))


@router.put("/sections/{section_id}/skills/order", response_model=AdminNodeList)
async def reorder_skills(
    section_id: str,
    body: ReorderRequest,
    repo: SqlAlchemyAdminContentRepository = Depends(_repo),
    ctx: uc.AdminContext = Depends(_ctx),
) -> AdminNodeList:
    rows = await uc.reorder_children(repo, ctx, SKILL, section_id, body.ids)
    return AdminNodeList(items=[_node(r) for r in rows])


@router.delete("/skills/{skill_id}", status_code=204)
async def delete_skill(
    skill_id: str,
    confirm: bool = False,
    repo: SqlAlchemyAdminContentRepository = Depends(_repo),
    ctx: uc.AdminContext = Depends(_ctx),
) -> Response:
    await uc.delete_node(repo, ctx, SKILL, skill_id, confirm=confirm)
    return Response(status_code=204)


# --- lessons ------------------------------------------------------------------


@router.post("/skills/{skill_id}/lessons", response_model=AdminNode, status_code=201)
async def create_lesson(
    skill_id: str,
    body: TitleRequest,
    repo: SqlAlchemyAdminContentRepository = Depends(_repo),
    ctx: uc.AdminContext = Depends(_ctx),
) -> AdminNode:
    return _node(await uc.create_node(repo, ctx, LESSON, skill_id, title=body.title))


@router.patch("/lessons/{lesson_id}", response_model=AdminNode)
async def update_lesson(
    lesson_id: str,
    body: UpdateTitleRequest,
    repo: SqlAlchemyAdminContentRepository = Depends(_repo),
    ctx: uc.AdminContext = Depends(_ctx),
) -> AdminNode:
    return _node(await uc.rename_node(repo, ctx, LESSON, lesson_id, title=body.title))


@router.put("/skills/{skill_id}/lessons/order", response_model=AdminNodeList)
async def reorder_lessons(
    skill_id: str,
    body: ReorderRequest,
    repo: SqlAlchemyAdminContentRepository = Depends(_repo),
    ctx: uc.AdminContext = Depends(_ctx),
) -> AdminNodeList:
    rows = await uc.reorder_children(repo, ctx, LESSON, skill_id, body.ids)
    return AdminNodeList(items=[_node(r) for r in rows])


@router.delete("/lessons/{lesson_id}", status_code=204)
async def delete_lesson(
    lesson_id: str,
    confirm: bool = False,
    repo: SqlAlchemyAdminContentRepository = Depends(_repo),
    ctx: uc.AdminContext = Depends(_ctx),
) -> Response:
    await uc.delete_node(repo, ctx, LESSON, lesson_id, confirm=confirm)
    return Response(status_code=204)


# --- exercises ----------------------------------------------------------------


@router.get("/lessons/{lesson_id}/exercises", response_model=AdminExerciseList)
async def list_exercises(
    lesson_id: str, repo: SqlAlchemyAdminContentRepository = Depends(_repo)
) -> AdminExerciseList:
    rows = await uc.list_exercises(repo, lesson_id)
    return AdminExerciseList(exercises=[_exercise(r) for r in rows])


@router.post("/lessons/{lesson_id}/exercises", response_model=AdminExercise, status_code=201)
async def create_exercise(
    lesson_id: str,
    body: ExerciseRequest,
    repo: SqlAlchemyAdminContentRepository = Depends(_repo),
    ctx: uc.AdminContext = Depends(_ctx),
) -> AdminExercise:
    row = await uc.create_exercise(
        repo,
        ctx,
        lesson_id,
        exercise_type=body.type,
        prompt=body.prompt,
        content=body.content,
        answer_key=body.answer_key,
    )
    return _exercise(row)


@router.put("/exercises/{exercise_id}", response_model=AdminExercise)
async def update_exercise(
    exercise_id: str,
    body: ExerciseRequest,
    repo: SqlAlchemyAdminContentRepository = Depends(_repo),
    ctx: uc.AdminContext = Depends(_ctx),
) -> AdminExercise:
    row = await uc.update_exercise(
        repo,
        ctx,
        exercise_id,
        exercise_type=body.type,
        prompt=body.prompt,
        content=body.content,
        answer_key=body.answer_key,
    )
    return _exercise(row)


@router.put("/lessons/{lesson_id}/exercises/order", response_model=AdminExerciseList)
async def reorder_exercises(
    lesson_id: str,
    body: ReorderRequest,
    repo: SqlAlchemyAdminContentRepository = Depends(_repo),
    ctx: uc.AdminContext = Depends(_ctx),
) -> AdminExerciseList:
    rows = await uc.reorder_children(repo, ctx, EXERCISE, lesson_id, body.ids)
    return AdminExerciseList(exercises=[_exercise(r) for r in rows])


@router.delete("/exercises/{exercise_id}", status_code=204)
async def delete_exercise(
    exercise_id: str,
    repo: SqlAlchemyAdminContentRepository = Depends(_repo),
    ctx: uc.AdminContext = Depends(_ctx),
) -> Response:
    await uc.delete_exercise(repo, ctx, exercise_id)
    return Response(status_code=204)


# --- audio (bolt 036) ---------------------------------------------------------


@router.post("/audio/uploads", response_model=AudioUploadResponse, status_code=201)
async def create_audio_upload(
    body: AudioUploadRequest,
    repo: SqlAlchemyAdminContentRepository = Depends(_repo),
    ctx: uc.AdminContext = Depends(_ctx),
    storage: R2Storage | LocalAudioStorage | None = Depends(get_audio_storage),
) -> AudioUploadResponse:
    """A short-lived PUT link for one recording or file: straight to R2, or
    to this backend in local development without R2."""
    key, upload = await audio_uc.presign_upload(
        repo, ctx, storage, lesson_id=body.lesson_id, content_type=body.content_type, size=body.size
    )
    return AudioUploadResponse(
        upload_url=upload.url,
        headers=upload.headers,
        key=key,
        public_url=upload.public_url,
        expires_in=upload.expires_in,
    )


@router.post("/audio/links", response_model=AudioLinkResponse)
async def check_audio_link(
    body: AudioLinkRequest, checker: AudioLinkChecker = Depends(get_audio_link_checker)
) -> AudioLinkResponse:
    """Checks a pasted link answers with audio before the admin saves it."""
    url, content_type = await audio_uc.check_audio_link(checker, body.url)
    return AudioLinkResponse(url=url, content_type=content_type)
