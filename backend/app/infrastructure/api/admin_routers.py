"""FastAPI router for the content admin API: `/api/v1/admin/*`
(`017-content-admin-web`).

`require_admin` is a router-level dependency, so every endpoint added here
is admin-only without having to remember it (ADR-16). Routes stay thin:
request schema -> use case -> response schema.
"""

from __future__ import annotations

from collections import defaultdict
from typing import Any, NamedTuple

from fastapi import APIRouter, Depends, Request, Response
from sqlalchemy.ext.asyncio import AsyncSession

from app.application import admin_audio_use_cases as audio_uc
from app.application import admin_content_use_cases as uc
from app.application import admin_image_use_cases as image_uc
from app.config import get_settings
from app.domain.entities import User
from app.domain.lesson.exceptions import ContentNotFoundError
from app.infrastructure.api.admin_schemas import (
    AdminCourse,
    AdminCourseList,
    AdminCourseTree,
    AdminExercise,
    AdminExerciseList,
    AdminLanguage,
    AdminLanguageList,
    AdminMeResponse,
    AdminNode,
    AdminNodeList,
    AdminTreeExercise,
    AdminTreeLesson,
    AdminTreeSection,
    AdminTreeSkill,
    AdminVocabItem,
    AdminVocabList,
    AdminVocabUse,
    AudioLinkRequest,
    AudioLinkResponse,
    AudioStatus,
    AudioUploadRequest,
    AudioUploadResponse,
    CreateCourseRequest,
    CreateLanguageRequest,
    CreateSectionRequest,
    ExerciseImportCheck,
    ExerciseImportRequest,
    ExerciseRequest,
    ImageUploadRequest,
    ImageUploadResponse,
    ReorderRequest,
    TitleRequest,
    UpdateCourseRequest,
    UpdateLanguageRequest,
    UpdateSectionRequest,
    UpdateTitleRequest,
    UpdateVocabRequest,
)
from app.infrastructure.api.dependencies import require_admin
from app.infrastructure.db.admin_content_repository import (
    EXERCISE,
    LESSON,
    SECTION,
    SKILL,
    CourseOutline,
    SqlAlchemyAdminContentRepository,
)
from app.infrastructure.db.lesson_models import (
    CourseModel,
    ExerciseModel,
    LanguageModel,
    VocabItemModel,
)
from app.infrastructure.db.seed_category_content import PLACEHOLDER_AUDIO_URL
from app.infrastructure.db.session import get_db_session
from app.infrastructure.external.audio_link_checker import AudioLinkChecker
from app.infrastructure.external.local_audio_storage import (
    LocalAudioStorage,
    choose_audio_storage,
    choose_image_storage,
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


def get_image_storage(request: Request) -> R2Storage | LocalAudioStorage | None:
    """Overridable in tests. As `get_audio_storage`, for pictures (bolt 050)."""
    return choose_image_storage(get_settings(), upload_base_url=str(request.base_url))


def get_audio_link_checker() -> AudioLinkChecker:
    """Overridable in tests, which never reach the network."""
    return AudioLinkChecker()


def _course(
    course: CourseModel, section_count: int, languages: dict[str, LanguageModel]
) -> AdminCourse:
    learning = languages.get(course.learning_language)
    source = languages.get(course.from_language)
    return AdminCourse(
        id=course.id,
        title=course.title,
        learning_language=course.learning_language,
        from_language=course.from_language,
        learning_language_name=learning.name if learning else course.learning_language,
        learning_language_native_name=(
            learning.native_name if learning else course.learning_language
        ),
        from_language_name=source.name if source else course.from_language,
        from_language_native_name=source.native_name if source else course.from_language,
        status=course.status,
        section_count=section_count,
    )


def _language(language: LanguageModel, course_count: int) -> AdminLanguage:
    return AdminLanguage(
        code=language.code,
        name=language.name,
        native_name=language.native_name,
        course_count=course_count,
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


class _Place(NamedTuple):
    """Where a lesson sits in its course, numbered as the tree numbers it."""

    key: tuple[int, int, int]
    section_title: str
    skill_title: str
    lesson_title: str


def _places(outline: CourseOutline) -> dict[str, _Place]:
    sections, skills, lessons = outline
    section_at = {s.id: (n, s.title) for n, s in enumerate(sections, start=1)}
    # Children counted per parent, in order: the tree's 1-based numbers.
    counted: dict[str, int] = defaultdict(int)
    skill_at: dict[str, tuple[int, int, str, str]] = {}
    for skill in skills:
        s, section_title = section_at[skill.category_id]
        counted[skill.category_id] += 1
        skill_at[skill.id] = (s, counted[skill.category_id], section_title, skill.title)
    places: dict[str, _Place] = {}
    for lesson in lessons:
        s, k, section_title, skill_title = skill_at[lesson.skill_id]
        counted[lesson.skill_id] += 1
        places[lesson.id] = _Place(
            (s, k, counted[lesson.skill_id]), section_title, skill_title, lesson.title
        )
    return places


def _vocab_items(
    outline: CourseOutline,
    items: list[VocabItemModel],
    uses: list[Any],
    learners: dict[str, int],
) -> list[AdminVocabItem]:
    """Each item with its exercises in curriculum order; items ordered by
    their first exercise, then unused items by word. An exercise outside
    the outline's lessons is left out."""
    places = _places(outline)
    found: dict[str, list[tuple[tuple[int, ...], AdminVocabUse]]] = defaultdict(list)
    for use in uses:
        place = places.get(use.lesson_id)
        if place is None:
            continue
        found[use.vocab_item_id].append(
            (
                (*place.key, use.order_index),
                AdminVocabUse(
                    exercise_id=use.id,
                    type=use.type,
                    prompt=use.prompt,
                    lesson_id=use.lesson_id,
                    number=".".join(str(n) for n in place.key),
                    section_title=place.section_title,
                    skill_title=place.skill_title,
                    lesson_title=place.lesson_title,
                ),
            )
        )
    rows: list[tuple[tuple[Any, ...], AdminVocabItem]] = []
    for item in items:
        item_uses = sorted(found[item.id], key=lambda u: u[0])
        first = item_uses[0][0] if item_uses else None
        rows.append(
            (
                (first is None, first or (), item.word.casefold(), item.id),
                AdminVocabItem(
                    id=item.id,
                    word=item.word,
                    translation=item.translation,
                    learners=learners.get(item.id, 0),
                    used_by=[u for _, u in item_uses],
                ),
            )
        )
    rows.sort(key=lambda r: r[0])
    return [item for _, item in rows]


def _audio_status(exercise_type: str, content: dict[str, Any]) -> AudioStatus | None:
    if exercise_type not in ("listening", "audio_image_choice"):
        return None
    url = content.get("audio_url", "")
    if url == PLACEHOLDER_AUDIO_URL:
        return "placeholder"
    return "local" if url.startswith("/") else "hosted"


@router.get("/me", response_model=AdminMeResponse)
async def get_admin_me(admin: User = Depends(require_admin)) -> AdminMeResponse:
    """Story 001-admin-authorization: who the admin site is signed in as."""
    return AdminMeResponse(email=admin.email or "")


# --- languages -------------------------------------------------------------


@router.get("/languages", response_model=AdminLanguageList)
async def list_languages(
    repo: SqlAlchemyAdminContentRepository = Depends(_repo),
) -> AdminLanguageList:
    return AdminLanguageList(
        languages=[_language(row, n) for row, n in await repo.list_languages()]
    )


@router.post("/languages", response_model=AdminLanguage, status_code=201)
async def create_language(
    body: CreateLanguageRequest,
    repo: SqlAlchemyAdminContentRepository = Depends(_repo),
    ctx: uc.AdminContext = Depends(_ctx),
) -> AdminLanguage:
    language = await uc.create_language(
        repo, ctx, code=body.code, name=body.name, native_name=body.native_name
    )
    return _language(language, 0)


@router.patch("/languages/{code}", response_model=AdminLanguage)
async def update_language(
    code: str,
    body: UpdateLanguageRequest,
    repo: SqlAlchemyAdminContentRepository = Depends(_repo),
    ctx: uc.AdminContext = Depends(_ctx),
) -> AdminLanguage:
    language = await uc.update_language(
        repo, ctx, code, name=body.name, native_name=body.native_name
    )
    return _language(language, await repo.count_courses_using(code))


@router.delete("/languages/{code}", status_code=204)
async def delete_language(
    code: str,
    repo: SqlAlchemyAdminContentRepository = Depends(_repo),
    ctx: uc.AdminContext = Depends(_ctx),
) -> Response:
    await uc.delete_language(repo, ctx, code)
    return Response(status_code=204)


# --- courses and the tree ---------------------------------------------------


@router.get("/courses", response_model=AdminCourseList)
async def list_courses(repo: SqlAlchemyAdminContentRepository = Depends(_repo)) -> AdminCourseList:
    languages = await repo.language_map()
    return AdminCourseList(courses=[_course(c, n, languages) for c, n in await repo.list_courses()])


@router.post("/courses", response_model=AdminCourse, status_code=201)
async def create_course(
    body: CreateCourseRequest,
    repo: SqlAlchemyAdminContentRepository = Depends(_repo),
    ctx: uc.AdminContext = Depends(_ctx),
) -> AdminCourse:
    course = await uc.create_course(
        repo,
        ctx,
        learning_language=body.learning_language,
        from_language=body.from_language,
        title=body.title,
    )
    return _course(course, 0, await repo.language_map())


@router.patch("/courses/{course_id}", response_model=AdminCourse)
async def update_course(
    course_id: str,
    body: UpdateCourseRequest,
    repo: SqlAlchemyAdminContentRepository = Depends(_repo),
    ctx: uc.AdminContext = Depends(_ctx),
) -> AdminCourse:
    course = await uc.update_course(repo, ctx, course_id, title=body.title, status=body.status)
    return _course(course, len(await repo.children(SECTION, course_id)), await repo.language_map())


@router.delete("/courses/{course_id}", status_code=204)
async def delete_course(
    course_id: str,
    repo: SqlAlchemyAdminContentRepository = Depends(_repo),
    ctx: uc.AdminContext = Depends(_ctx),
) -> Response:
    await uc.delete_course(repo, ctx, course_id)
    return Response(status_code=204)


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
        course=_course(course, len(sections), await repo.language_map()),
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


@router.post(
    "/lessons/{lesson_id}/exercises/import",
    response_model=AdminExerciseList | ExerciseImportCheck,
    status_code=201,
)
async def import_exercises(
    lesson_id: str,
    body: ExerciseImportRequest,
    response: Response,
    repo: SqlAlchemyAdminContentRepository = Depends(_repo),
    ctx: uc.AdminContext = Depends(_ctx),
) -> AdminExerciseList | ExerciseImportCheck:
    """Bolt 056: every exercise is checked, then all are saved or none."""
    items = [uc.ExerciseInput(e.type, e.prompt, e.content, e.answer_key) for e in body.exercises]
    if body.dry_run:
        response.status_code = 200
        return ExerciseImportCheck(count=await uc.check_import(repo, ctx, lesson_id, items))
    rows = await uc.import_exercises(repo, ctx, lesson_id, items, replace=body.mode == "replace")
    return AdminExerciseList(exercises=[_exercise(r) for r in rows])


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


# --- vocabulary (bolt 040) ----------------------------------------------------


@router.get("/courses/{course_id}/vocab", response_model=AdminVocabList)
async def list_vocab(
    course_id: str, repo: SqlAlchemyAdminContentRepository = Depends(_repo)
) -> AdminVocabList:
    """Story 006-vocabulary-api: the course's words, where each is
    practised, and how many learners practise it."""
    course, outline, listing = await uc.list_vocab(repo, course_id)
    return AdminVocabList(
        course=_course(course, len(outline[0]), await repo.language_map()),
        items=_vocab_items(outline, listing.items, listing.uses, listing.learners),
        learners=listing.learners_total,
    )


@router.patch("/vocab/{vocab_item_id}", response_model=AdminVocabItem)
async def update_vocab(
    vocab_item_id: str,
    body: UpdateVocabRequest,
    repo: SqlAlchemyAdminContentRepository = Depends(_repo),
    ctx: uc.AdminContext = Depends(_ctx),
) -> AdminVocabItem:
    item = await uc.update_vocab(
        repo, ctx, vocab_item_id, word=body.word, translation=body.translation
    )
    (row,) = _vocab_items(
        await repo.course_outline(item.course_id),
        [item],
        await repo.vocab_uses(item.id),
        {item.id: await repo.vocab_learners(item.id)},
    )
    return row


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


# --- pictures (bolt 050) ------------------------------------------------------


@router.post("/images/uploads", response_model=ImageUploadResponse, status_code=201)
async def create_image_upload(
    body: ImageUploadRequest,
    repo: SqlAlchemyAdminContentRepository = Depends(_repo),
    ctx: uc.AdminContext = Depends(_ctx),
    storage: R2Storage | LocalAudioStorage | None = Depends(get_image_storage),
) -> ImageUploadResponse:
    """A short-lived PUT link for one picture: straight to R2, or to this
    backend in local development without R2."""
    key, upload = await image_uc.presign_image_upload(
        repo, ctx, storage, lesson_id=body.lesson_id, content_type=body.content_type, size=body.size
    )
    return ImageUploadResponse(
        upload_url=upload.url,
        headers=upload.headers,
        key=key,
        public_url=upload.public_url,
        expires_in=upload.expires_in,
    )
