"""SQL for the content admin API (bolt `035-admin-content-api`).

Works on the ORM rows directly: these are plain CRUD writes over the
content tables, which the learner-side aggregates only ever read. Every
method stays inside the caller's transaction -- nothing here commits.

Four levels share one shape (a row with a parent and an `order_index`
unique within that parent), described once in `LEVELS`.
"""

from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any

from sqlalchemy import delete, func, select, union
from sqlalchemy.ext.asyncio import AsyncSession

from app.infrastructure.db.lesson_models import (
    CategoryModel,
    CourseModel,
    ExerciseModel,
    LessonAttemptModel,
    LessonModel,
    SkillModel,
    UserSkillProgressModel,
)

# Added to every sibling's `order_index` before the final values are
# written, so no intermediate state collides with the per-parent unique
# constraint. Far above any real position.
_REORDER_OFFSET = 10_000


@dataclass(frozen=True)
class Level:
    name: str
    model: type[Any]
    parent_column: str
    parent_model: type[Any]


SECTION = Level("section", CategoryModel, "course_id", CourseModel)
SKILL = Level("skill", SkillModel, "category_id", CategoryModel)
LESSON = Level("lesson", LessonModel, "skill_id", SkillModel)
EXERCISE = Level("exercise", ExerciseModel, "lesson_id", LessonModel)
LEVELS = {level.name: level for level in (SECTION, SKILL, LESSON, EXERCISE)}


@dataclass(frozen=True)
class Subtree:
    """Everything beneath (and including) a section, skill or lesson."""

    skill_ids: tuple[str, ...]
    lesson_ids: tuple[str, ...]
    exercise_count: int


class SqlAlchemyAdminContentRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    # --- reads -----------------------------------------------------------

    async def list_courses(self) -> list[tuple[CourseModel, int]]:
        """Every course with its number of sections, in catalog order."""
        counts = (
            select(CategoryModel.course_id, func.count().label("n"))
            .group_by(CategoryModel.course_id)
            .subquery()
        )
        stmt = (
            select(CourseModel, func.coalesce(counts.c.n, 0))
            .outerjoin(counts, counts.c.course_id == CourseModel.id)
            .order_by(CourseModel.order_index)
        )
        return [(course, n) for course, n in (await self._session.execute(stmt)).all()]

    async def get(self, model: type[Any], row_id: str) -> Any | None:
        return await self._session.get(model, row_id)

    async def children(self, level: Level, parent_id: str) -> list[Any]:
        column = getattr(level.model, level.parent_column)
        stmt = select(level.model).where(column == parent_id).order_by(level.model.order_index)
        return list((await self._session.execute(stmt)).scalars().all())

    async def course_tree(
        self, course_id: str
    ) -> tuple[list[CategoryModel], list[SkillModel], list[LessonModel], list[Any]]:
        """All four levels of one course, each in order. Exercises come back
        as light rows (no answer key) -- the tree only lists them."""
        sections = await self.children(SECTION, course_id)
        section_ids = [s.id for s in sections]
        skills = list(
            (
                await self._session.execute(
                    select(SkillModel)
                    .where(SkillModel.category_id.in_(section_ids))
                    .order_by(SkillModel.order_index)
                )
            ).scalars()
        )
        lessons = list(
            (
                await self._session.execute(
                    select(LessonModel)
                    .where(LessonModel.skill_id.in_([s.id for s in skills]))
                    .order_by(LessonModel.order_index)
                )
            ).scalars()
        )
        exercises = list(
            (
                await self._session.execute(
                    select(
                        ExerciseModel.id,
                        ExerciseModel.lesson_id,
                        ExerciseModel.order_index,
                        ExerciseModel.type,
                        ExerciseModel.prompt,
                        ExerciseModel.content,
                    )
                    .where(ExerciseModel.lesson_id.in_([lesson.id for lesson in lessons]))
                    .order_by(ExerciseModel.order_index)
                )
            ).all()
        )
        return sections, skills, lessons, exercises

    async def subtree(self, level: Level, row_id: str) -> Subtree:
        if level is SECTION:
            skill_ids = tuple(
                (
                    await self._session.execute(
                        select(SkillModel.id).where(SkillModel.category_id == row_id)
                    )
                ).scalars()
            )
        elif level is SKILL:
            skill_ids = (row_id,)
        else:
            skill_ids = ()
        if level is LESSON:
            lesson_ids: tuple[str, ...] = (row_id,)
        else:
            lesson_ids = tuple(
                (
                    await self._session.execute(
                        select(LessonModel.id).where(LessonModel.skill_id.in_(skill_ids))
                    )
                ).scalars()
            )
        exercise_count = (
            await self._session.execute(
                select(func.count())
                .select_from(ExerciseModel)
                .where(ExerciseModel.lesson_id.in_(lesson_ids))
            )
        ).scalar_one()
        return Subtree(skill_ids=skill_ids, lesson_ids=lesson_ids, exercise_count=exercise_count)

    async def learning_language_of_lesson(self, lesson_id: str) -> str | None:
        """The lesson's course's learning language -- the folder its audio
        goes in (bolt 036)."""
        stmt = (
            select(CourseModel.learning_language)
            .join(CategoryModel, CategoryModel.course_id == CourseModel.id)
            .join(SkillModel, SkillModel.category_id == CategoryModel.id)
            .join(LessonModel, LessonModel.skill_id == SkillModel.id)
            .where(LessonModel.id == lesson_id)
        )
        return (await self._session.execute(stmt)).scalar_one_or_none()

    async def count_learners(self, subtree: Subtree) -> int:
        """Distinct learners with progress on any skill, or an attempt at
        any lesson, in the subtree -- the only two tables that point at
        content (bolt 035 plan, finding 4)."""
        users = union(
            select(UserSkillProgressModel.user_id).where(
                UserSkillProgressModel.skill_id.in_(subtree.skill_ids)
            ),
            select(LessonAttemptModel.user_id).where(
                LessonAttemptModel.lesson_id.in_(subtree.lesson_ids)
            ),
        ).subquery()
        return (await self._session.execute(select(func.count()).select_from(users))).scalar_one()

    # --- writes ----------------------------------------------------------

    async def next_order_index(self, level: Level, parent_id: str) -> int:
        column = getattr(level.model, level.parent_column)
        stmt = select(func.max(level.model.order_index)).where(column == parent_id)
        current = (await self._session.execute(stmt)).scalar_one()
        return 1 if current is None else current + 1

    async def add(self, row: Any) -> Any:
        self._session.add(row)
        await self._session.flush()
        return row

    async def flush(self) -> None:
        await self._session.flush()

    async def apply_order(self, rows: Sequence[Any]) -> None:
        """Renumbers `rows` (all siblings) to 1..n in the given order, in two
        passes so the unique constraint never sees a duplicate."""
        for row in rows:
            row.order_index += _REORDER_OFFSET
        await self._session.flush()
        for position, row in enumerate(rows, start=1):
            row.order_index = position
        await self._session.flush()

    async def delete_subtree(self, level: Level, row: Any, subtree: Subtree) -> None:
        """Deletes `row` and everything beneath it, children first."""
        await self._session.execute(
            delete(ExerciseModel).where(ExerciseModel.lesson_id.in_(subtree.lesson_ids))
        )
        if level is not LESSON:
            await self._session.execute(
                delete(LessonModel).where(LessonModel.id.in_(subtree.lesson_ids))
            )
        if level is SECTION:
            await self._session.execute(
                delete(SkillModel).where(SkillModel.id.in_(subtree.skill_ids))
            )
        await self._session.delete(row)
        await self._session.flush()

    async def delete_row(self, row: Any) -> None:
        await self._session.delete(row)
        await self._session.flush()

    async def touch_lesson(self, lesson: LessonModel) -> None:
        """Moves the lesson's `content_version` (bolt 008) so a downloaded
        copy is refetched. `onupdate` alone misses exercise deletes and some
        reorders, where the lesson row itself is not otherwise written."""
        lesson.updated_at = datetime.now(UTC)
        await self._session.flush()
