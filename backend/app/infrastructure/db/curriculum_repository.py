"""Reads and writes a course's draft curriculum (`curriculum_models.py`)."""

from __future__ import annotations

from collections.abc import Sequence

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.infrastructure.db.curriculum_models import (
    CurriculumEntryModel,
    CurriculumExerciseModel,
    CurriculumRowModel,
)
from app.infrastructure.db.lesson_models import CourseModel


class SqlAlchemyCurriculumRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def course(self, course_id: str) -> CourseModel | None:
        return await self._session.get(CourseModel, course_id)

    async def entries(self, course_id: str) -> list[CurriculumEntryModel]:
        stmt = (
            select(CurriculumEntryModel)
            .where(CurriculumEntryModel.course_id == course_id)
            .order_by(CurriculumEntryModel.position, CurriculumEntryModel.ref)
        )
        return list((await self._session.execute(stmt)).scalars())

    async def rows(self, course_id: str) -> list[CurriculumRowModel]:
        stmt = (
            select(CurriculumRowModel)
            .where(CurriculumRowModel.course_id == course_id)
            .order_by(
                CurriculumRowModel.lesson_ref, CurriculumRowModel.position, CurriculumRowModel.ref
            )
        )
        return list((await self._session.execute(stmt)).scalars())

    async def row(self, course_id: str, ref: str) -> CurriculumRowModel | None:
        stmt = select(CurriculumRowModel).where(
            CurriculumRowModel.course_id == course_id, CurriculumRowModel.ref == ref
        )
        return (await self._session.execute(stmt)).scalar_one_or_none()

    async def exercises(
        self, course_id: str, lesson_ref: str | None = None
    ) -> list[CurriculumExerciseModel]:
        """A lesson's draft exercises in order, or every lesson's."""
        stmt = select(CurriculumExerciseModel).where(CurriculumExerciseModel.course_id == course_id)
        if lesson_ref is not None:
            stmt = stmt.where(CurriculumExerciseModel.lesson_ref == lesson_ref)
        stmt = stmt.order_by(CurriculumExerciseModel.lesson_ref, CurriculumExerciseModel.position)
        return list((await self._session.execute(stmt)).scalars())

    async def clear_exercises(self, course_id: str, lesson_ref: str) -> None:
        await self._session.execute(
            delete(CurriculumExerciseModel).where(
                CurriculumExerciseModel.course_id == course_id,
                CurriculumExerciseModel.lesson_ref == lesson_ref,
            )
        )
        await self._session.flush()

    async def add_all(
        self, items: Sequence[CurriculumEntryModel | CurriculumRowModel | CurriculumExerciseModel]
    ) -> None:
        self._session.add_all(items)
        await self._session.flush()

    async def flush(self) -> None:
        await self._session.flush()
