"""Content admin use cases (bolt `035-admin-content-api`, stories
003-content-tree-and-crud-api and 004-exercise-write-validation).

Each write runs inside the request's one transaction (the session
dependency commits on success), validates before it touches a row, and logs
one `admin_write` line once it has succeeded. Content text never goes into
the log -- only what was done, to which id, by which admin.
"""

from __future__ import annotations

import logging
import uuid
from collections.abc import Sequence
from dataclasses import dataclass
from typing import Any

from app.domain.lesson.exceptions import (
    ConfirmationRequiredError,
    ContentExistsError,
    ContentInUseError,
    ContentNotFoundError,
    InvalidContentError,
    InvalidExerciseError,
    InvalidImportError,
    InvalidOrderError,
)
from app.domain.lesson.exercise_parts import validate_exercise
from app.domain.value_objects import LANGUAGE_CODE_PATTERN
from app.infrastructure.db.admin_content_repository import (
    EXERCISE,
    LESSON,
    LEVELS,
    SECTION,
    CourseOutline,
    Level,
    SqlAlchemyAdminContentRepository,
    VocabListing,
)
from app.infrastructure.db.lesson_models import (
    CategoryModel,
    CourseModel,
    ExerciseModel,
    LanguageModel,
    LessonModel,
    SkillModel,
    VocabItemModel,
)

logger = logging.getLogger("app.admin")


@dataclass(frozen=True)
class AdminContext:
    """Who is acting, and whether local-only `/media` audio is allowed."""

    email: str
    allow_local_media: bool = False


def _log(ctx: AdminContext, action: str, entity: str, entity_id: str) -> None:
    logger.info(
        "admin_write action=%s entity=%s id=%s admin=%s", action, entity, entity_id, ctx.email
    )


def _clean(field: str, value: str | None, *, required: bool = True) -> str:
    text = (value or "").strip()
    if required and not text:
        raise InvalidContentError(field, f"{field} must not be empty")
    return text


_NAMES: dict[type[Any], str] = {
    CourseModel: "course",
    LanguageModel: "language",
    CategoryModel: "section",
    SkillModel: "skill",
    LessonModel: "lesson",
    ExerciseModel: "exercise",
    VocabItemModel: "vocab",
}


async def _require(repo: SqlAlchemyAdminContentRepository, model: type[Any], row_id: str) -> Any:
    row = await repo.get(model, row_id)
    if row is None:
        raise ContentNotFoundError(f"No such {_NAMES[model]}", entity=_NAMES[model], id=row_id)
    return row


# --- languages -----------------------------------------------------------

LANGUAGE_NAME_MAX = 64


def _language_name(field: str, value: str | None) -> str:
    text = _clean(field, value)
    if len(text) > LANGUAGE_NAME_MAX:
        raise InvalidContentError(field, f"{field} must be at most {LANGUAGE_NAME_MAX} characters")
    return text


async def create_language(
    repo: SqlAlchemyAdminContentRepository,
    ctx: AdminContext,
    *,
    code: str,
    name: str,
    native_name: str,
) -> LanguageModel:
    """A new language courses can use. The code is its ISO 639 code, two
    or three lowercase letters (`ti`, `sid`), and never changes."""
    code = (code or "").strip().lower()
    if not LANGUAGE_CODE_PATTERN.match(code):
        raise InvalidContentError("code", "code must be two or three letters, e.g. ti or sid")
    language = LanguageModel(
        code=code,
        name=_language_name("name", name),
        native_name=_language_name("native_name", native_name),
    )
    if await repo.get(LanguageModel, code) is not None:
        raise ContentExistsError(f"A language with code {code!r} already exists", code=code)
    await repo.add(language)
    _log(ctx, "create", "language", code)
    return language


async def update_language(
    repo: SqlAlchemyAdminContentRepository,
    ctx: AdminContext,
    code: str,
    *,
    name: str | None = None,
    native_name: str | None = None,
) -> LanguageModel:
    language = await _require(repo, LanguageModel, code)
    if name is not None:
        language.name = _language_name("name", name)
    if native_name is not None:
        language.native_name = _language_name("native_name", native_name)
    await repo.flush()
    _log(ctx, "update", "language", code)
    return language


async def delete_language(
    repo: SqlAlchemyAdminContentRepository, ctx: AdminContext, code: str
) -> None:
    """Only a language no course uses can go."""
    language = await _require(repo, LanguageModel, code)
    courses = await repo.count_courses_using(code)
    if courses:
        raise ContentInUseError(
            f"{courses} course(s) use this language, so it cannot be deleted", courses=courses
        )
    await repo.delete_row(language)
    _log(ctx, "delete", "language", code)


# --- courses -------------------------------------------------------------

COURSE_STATUSES = ("available", "coming_soon")


async def _language_of(
    repo: SqlAlchemyAdminContentRepository, field: str, code: str
) -> LanguageModel:
    code = (code or "").strip().lower()
    language = await repo.get(LanguageModel, code) if code else None
    if language is None:
        raise InvalidContentError(field, f"{field} must be a known language")
    return language


async def create_course(
    repo: SqlAlchemyAdminContentRepository,
    ctx: AdminContext,
    *,
    learning_language: str,
    from_language: str,
    title: str | None = None,
) -> CourseModel:
    """A new, empty course for a language pair, placed last. It starts as
    coming soon, so learners only see it once it has content and is made
    available. Without a title it is named "<from> to <learning>"."""
    learning = await _language_of(repo, "learning_language", learning_language)
    source = await _language_of(repo, "from_language", from_language)
    if learning.code == source.code:
        raise InvalidContentError(
            "from_language", "A course must teach one language from a different one"
        )
    if await repo.course_for_pair(learning.code, source.code) is not None:
        raise ContentExistsError(
            f"There is already a course teaching {learning.name} from {source.name}",
            learning_language=learning.code,
            from_language=source.code,
        )
    course = CourseModel(
        id=str(uuid.uuid4()),
        learning_language=learning.code,
        from_language=source.code,
        title=_clean("title", title, required=False) or f"{source.name} to {learning.name}",
        status="coming_soon",
        order_index=await repo.next_course_order_index(),
    )
    await repo.add(course)
    _log(ctx, "create", "course", course.id)
    return course


async def update_course(
    repo: SqlAlchemyAdminContentRepository,
    ctx: AdminContext,
    course_id: str,
    *,
    title: str | None = None,
    status: str | None = None,
) -> CourseModel:
    """Renames a course and/or changes its status. It can only become
    available once it has an exercise to play, and only go back to coming
    soon while no learner is studying it."""
    course = await _require(repo, CourseModel, course_id)
    if title is not None:
        course.title = _clean("title", title)
    if status is not None and status != course.status:
        if status not in COURSE_STATUSES:
            raise InvalidContentError("status", "status must be available or coming_soon")
        if status == "available" and not await repo.count_course_exercises(course_id):
            raise InvalidContentError(
                "status", "Add at least one lesson with an exercise before making it available"
            )
        if status == "coming_soon":
            learners = await repo.count_course_learners(course_id)
            if learners:
                raise ContentInUseError(
                    f"{learners} learner(s) are studying this course, so it stays available",
                    learners=learners,
                )
        course.status = status
    await repo.flush()
    _log(ctx, "update", "course", course_id)
    return course


async def delete_course(
    repo: SqlAlchemyAdminContentRepository, ctx: AdminContext, course_id: str
) -> None:
    """Only an empty course goes: no sections, no words, no learners."""
    course = await _require(repo, CourseModel, course_id)
    learners = await repo.count_course_learners(course_id)
    if learners:
        raise ContentInUseError(
            f"{learners} learner(s) are studying this course, so it cannot be deleted",
            learners=learners,
        )
    sections = len(await repo.children(SECTION, course_id))
    words = await repo.count_course_words(course_id)
    if sections or words:
        raise ContentInUseError(
            "Only an empty course can be deleted; remove its sections and words first",
            sections=sections,
            words=words,
        )
    await repo.delete_row(course)
    _log(ctx, "delete", "course", course_id)


# --- sections, skills, lessons --------------------------------------------


async def create_node(
    repo: SqlAlchemyAdminContentRepository,
    ctx: AdminContext,
    level: Level,
    parent_id: str,
    *,
    title: str,
    subtitle: str | None = None,
) -> Any:
    """A new section, skill or lesson, placed last in its parent."""
    await _require(repo, level.parent_model, parent_id)
    fields: dict[str, Any] = {"title": _clean("title", title)}
    if level is SECTION:
        fields["subtitle"] = _clean("subtitle", subtitle, required=False)
    row = level.model(
        id=str(uuid.uuid4()),
        order_index=await repo.next_order_index(level, parent_id),
        **{level.parent_column: parent_id},
        **fields,
    )
    await repo.add(row)
    _log(ctx, "create", level.name, row.id)
    return row


async def rename_node(
    repo: SqlAlchemyAdminContentRepository,
    ctx: AdminContext,
    level: Level,
    row_id: str,
    *,
    title: str | None = None,
    subtitle: str | None = None,
) -> Any:
    row = await _require(repo, level.model, row_id)
    if title is not None:
        row.title = _clean("title", title)
    if subtitle is not None and level is SECTION:
        row.subtitle = _clean("subtitle", subtitle, required=False)
    await repo.flush()
    _log(ctx, "update", level.name, row_id)
    return row


async def reorder_children(
    repo: SqlAlchemyAdminContentRepository,
    ctx: AdminContext,
    level: Level,
    parent_id: str,
    ids: list[str],
) -> list[Any]:
    """`ids` must be exactly the parent's current children, in the new
    order; anything missing, extra or repeated is refused unchanged."""
    parent = await _require(repo, level.parent_model, parent_id)
    rows = await repo.children(level, parent_id)
    by_id = {row.id: row for row in rows}
    if len(ids) != len(set(ids)) or set(ids) != set(by_id):
        raise InvalidOrderError(
            "ids must list each of this parent's children exactly once",
            expected=len(by_id),
            received=len(ids),
        )
    ordered = [by_id[i] for i in ids]
    await repo.apply_order(ordered)
    if level is EXERCISE:
        await repo.touch_lesson(parent)
    _log(ctx, "reorder", level.name, parent_id)
    return ordered


async def delete_node(
    repo: SqlAlchemyAdminContentRepository,
    ctx: AdminContext,
    level: Level,
    row_id: str,
    *,
    confirm: bool,
) -> None:
    """Refused outright if learners have history anywhere beneath; else
    needs `confirm` (the answer says what would go). Siblings are
    renumbered afterwards so positions stay 1..n."""
    row = await _require(repo, level.model, row_id)
    subtree = await repo.subtree(level, row_id)
    learners = await repo.count_learners(subtree)
    would_delete = {
        "skills": len(subtree.skill_ids) if level is SECTION else 0,
        "lessons": len(subtree.lesson_ids) if level is not LESSON else 0,
        "exercises": subtree.exercise_count,
    }
    if learners:
        raise ContentInUseError(
            f"{learners} learner(s) have progress here, so it cannot be deleted",
            learners=learners,
            **would_delete,
        )
    if not confirm:
        raise ConfirmationRequiredError(
            f"Deleting this {level.name} also deletes everything in it; repeat with confirm=true",
            **would_delete,
        )
    parent_id = getattr(row, level.parent_column)
    await repo.delete_subtree(level, row, subtree)
    await repo.apply_order(await repo.children(level, parent_id))
    _log(ctx, "delete", level.name, row_id)


# --- exercises --------------------------------------------------------------


async def list_exercises(
    repo: SqlAlchemyAdminContentRepository, lesson_id: str
) -> list[ExerciseModel]:
    await _require(repo, LessonModel, lesson_id)
    return await repo.children(EXERCISE, lesson_id)


async def create_exercise(
    repo: SqlAlchemyAdminContentRepository,
    ctx: AdminContext,
    lesson_id: str,
    *,
    exercise_type: str,
    prompt: str,
    content: Any,
    answer_key: Any,
) -> ExerciseModel:
    lesson = await _require(repo, LessonModel, lesson_id)
    parsed = validate_exercise(
        exercise_type, prompt, content, answer_key, allow_local_media=ctx.allow_local_media
    )
    exercise = ExerciseModel(
        id=str(uuid.uuid4()),
        lesson_id=lesson_id,
        order_index=await repo.next_order_index(EXERCISE, lesson_id),
        type=parsed.value,
        prompt=prompt.strip(),
        content=content,
        answer_key=answer_key,
    )
    await repo.add(exercise)
    await repo.touch_lesson(lesson)
    _log(ctx, "create", "exercise", exercise.id)
    return exercise


async def update_exercise(
    repo: SqlAlchemyAdminContentRepository,
    ctx: AdminContext,
    exercise_id: str,
    *,
    exercise_type: str,
    prompt: str,
    content: Any,
    answer_key: Any,
) -> ExerciseModel:
    exercise = await _require(repo, ExerciseModel, exercise_id)
    if exercise_type != exercise.type:
        raise InvalidExerciseError(
            "type", "an exercise's type cannot change; delete it and create a new one"
        )
    validate_exercise(
        exercise_type, prompt, content, answer_key, allow_local_media=ctx.allow_local_media
    )
    exercise.prompt = prompt.strip()
    exercise.content = content
    exercise.answer_key = answer_key
    await repo.flush()
    _log(ctx, "update", "exercise", exercise_id)
    return exercise


# --- importing exercises (bolt 056) ---------------------------------------

# The most exercises one import may hold.
IMPORT_MAX = 200


@dataclass(frozen=True)
class ExerciseInput:
    """One exercise of an import, as the admin site sends it."""

    type: str
    prompt: str
    content: Any
    answer_key: Any


async def check_import(
    repo: SqlAlchemyAdminContentRepository,
    ctx: AdminContext,
    lesson_id: str,
    items: Sequence[ExerciseInput],
) -> int:
    """Validates every exercise without writing, and returns how many there
    are. Refuses with every failure at once, not just the first."""
    await _require(repo, LessonModel, lesson_id)
    if not 1 <= len(items) <= IMPORT_MAX:
        raise InvalidContentError(
            "exercises", f"an import holds 1 to {IMPORT_MAX} exercises, not {len(items)}"
        )
    rows: list[dict[str, object]] = []
    for index, item in enumerate(items):
        try:
            validate_exercise(
                item.type,
                item.prompt,
                item.content,
                item.answer_key,
                allow_local_media=ctx.allow_local_media,
            )
        except InvalidExerciseError as exc:
            rows.append({"index": index, "field": exc.field, "message": exc.message})
    if rows:
        raise InvalidImportError(
            f"{len(rows)} of {len(items)} exercises cannot be saved", rows=rows
        )
    return len(items)


async def import_exercises(
    repo: SqlAlchemyAdminContentRepository,
    ctx: AdminContext,
    lesson_id: str,
    items: Sequence[ExerciseInput],
    *,
    replace: bool = False,
) -> list[ExerciseModel]:
    """Adds every exercise after the lesson's last one, in the given order,
    or in place of all of them with `replace`. All or nothing: it checks
    first, and the request's one transaction covers every write."""
    await check_import(repo, ctx, lesson_id, items)
    lesson = await _require(repo, LessonModel, lesson_id)
    if replace:
        for old in await repo.children(EXERCISE, lesson_id):
            await repo.delete_row(old)
            _log(ctx, "delete", "exercise", old.id)
    start = await repo.next_order_index(EXERCISE, lesson_id)
    for offset, item in enumerate(items):
        exercise = ExerciseModel(
            id=str(uuid.uuid4()),
            lesson_id=lesson_id,
            order_index=start + offset,
            type=item.type,
            prompt=item.prompt.strip(),
            content=item.content,
            answer_key=item.answer_key,
        )
        await repo.add(exercise)
        _log(ctx, "create", "exercise", exercise.id)
    await repo.touch_lesson(lesson)
    return await repo.children(EXERCISE, lesson_id)


async def delete_exercise(
    repo: SqlAlchemyAdminContentRepository, ctx: AdminContext, exercise_id: str
) -> None:
    """Nothing references an exercise, so no guard and no confirmation."""
    exercise = await _require(repo, ExerciseModel, exercise_id)
    lesson = await _require(repo, LessonModel, exercise.lesson_id)
    await repo.delete_row(exercise)
    await repo.apply_order(await repo.children(EXERCISE, lesson.id))
    await repo.touch_lesson(lesson)
    _log(ctx, "delete", "exercise", exercise_id)


# --- vocabulary (bolt 040) ---------------------------------------------------

# The `vocab_items` columns' length.
VOCAB_TEXT_MAX = 255


def _vocab_text(field: str, value: str) -> str:
    text = _clean(field, value)
    if len(text) > VOCAB_TEXT_MAX:
        raise InvalidContentError(field, f"{field} must be at most {VOCAB_TEXT_MAX} characters")
    return text


async def list_vocab(
    repo: SqlAlchemyAdminContentRepository, course_id: str
) -> tuple[CourseModel, CourseOutline, VocabListing]:
    """The course, its outline (to place each exercise) and its words."""
    course = await _require(repo, CourseModel, course_id)
    outline = await repo.course_outline(course_id)
    listing = await repo.course_vocab(course_id, [lesson.id for lesson in outline[2]])
    return course, outline, listing


async def update_vocab(
    repo: SqlAlchemyAdminContentRepository,
    ctx: AdminContext,
    vocab_item_id: str,
    *,
    word: str | None = None,
    translation: str | None = None,
) -> VocabItemModel:
    """Edits the text only. The id stays, so every learner's progress on
    the word stays with it, and Practice keeps serving it."""
    item = await _require(repo, VocabItemModel, vocab_item_id)
    # Both checked before either is written.
    new_word = _vocab_text("word", word) if word is not None else item.word
    new_translation = (
        _vocab_text("translation", translation) if translation is not None else item.translation
    )
    item.word = new_word
    item.translation = new_translation
    await repo.flush()
    _log(ctx, "update", "vocab", vocab_item_id)
    return item


__all__ = [
    "LEVELS",
    "VOCAB_TEXT_MAX",
    "AdminContext",
    "create_exercise",
    "create_node",
    "delete_exercise",
    "delete_node",
    "list_exercises",
    "list_vocab",
    "create_course",
    "create_language",
    "delete_course",
    "delete_language",
    "update_course",
    "update_language",
    "rename_node",
    "reorder_children",
    "update_exercise",
    "update_vocab",
]
