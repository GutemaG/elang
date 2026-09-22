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
from dataclasses import dataclass
from typing import Any

from app.domain.lesson.exceptions import (
    ConfirmationRequiredError,
    ContentInUseError,
    ContentNotFoundError,
    InvalidContentError,
    InvalidExerciseError,
    InvalidOrderError,
)
from app.domain.lesson.exercise_parts import validate_exercise
from app.infrastructure.db.admin_content_repository import (
    EXERCISE,
    LESSON,
    LEVELS,
    SECTION,
    Level,
    SqlAlchemyAdminContentRepository,
)
from app.infrastructure.db.lesson_models import (
    CategoryModel,
    CourseModel,
    ExerciseModel,
    LessonModel,
    SkillModel,
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
    CategoryModel: "section",
    SkillModel: "skill",
    LessonModel: "lesson",
    ExerciseModel: "exercise",
}


async def _require(repo: SqlAlchemyAdminContentRepository, model: type[Any], row_id: str) -> Any:
    row = await repo.get(model, row_id)
    if row is None:
        raise ContentNotFoundError(f"No such {_NAMES[model]}", entity=_NAMES[model], id=row_id)
    return row


# --- courses -------------------------------------------------------------


async def rename_course(
    repo: SqlAlchemyAdminContentRepository, ctx: AdminContext, course_id: str, title: str
) -> CourseModel:
    course = await _require(repo, CourseModel, course_id)
    course.title = _clean("title", title)
    await repo.flush()
    _log(ctx, "update", "course", course_id)
    return course


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


__all__ = [
    "LEVELS",
    "AdminContext",
    "create_exercise",
    "create_node",
    "delete_exercise",
    "delete_node",
    "list_exercises",
    "rename_course",
    "rename_node",
    "reorder_children",
    "update_exercise",
]
