"""Where stored audio links live, for the Audio library (intent 029, FR-2).

Three places hold links: exercise content, Workbook rows and Sounds
letters. Each read is one query with the names the library shows beside a
file (course, section, lesson, letter).
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from sqlalchemy import and_, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.infrastructure.db.curriculum_models import CurriculumEntryModel, CurriculumRowModel
from app.infrastructure.db.lesson_models import (
    CategoryModel,
    CourseModel,
    ExerciseModel,
    LessonModel,
    SkillModel,
)
from app.infrastructure.db.sound_models import SoundLetterModel


@dataclass(frozen=True)
class CourseRow:
    id: str
    title: str
    learning_language: str
    order_index: int


@dataclass(frozen=True)
class ExerciseRow:
    id: str
    type: str
    prompt: str
    content: dict[str, Any]
    order_index: int
    lesson_id: str
    lesson_title: str
    lesson_order: int
    skill_id: str
    skill_title: str
    skill_order: int
    section_id: str
    section_title: str
    section_order: int
    course_id: str


@dataclass(frozen=True)
class WorkbookRow:
    ref: str
    english: str
    text: str | None
    audio_url: str
    lesson_ref: str
    lesson_title: str | None
    course_id: str


@dataclass(frozen=True)
class LetterRow:
    id: str
    language: str
    group_key: str
    position: int
    glyph: str
    romanization: str
    example_word: str | None
    audio_url: str | None
    example_audio_url: str | None


class SqlAlchemyAudioLibraryRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def courses(self) -> list[CourseRow]:
        rows = await self._session.execute(
            select(
                CourseModel.id,
                CourseModel.title,
                CourseModel.learning_language,
                CourseModel.order_index,
            ).order_by(CourseModel.order_index)
        )
        return [CourseRow(*r) for r in rows.all()]

    async def exercises(self) -> list[ExerciseRow]:
        """Every exercise: any of them may hold a link somewhere in its
        content, so the content is read whole."""
        rows = await self._session.execute(
            select(
                ExerciseModel.id,
                ExerciseModel.type,
                ExerciseModel.prompt,
                ExerciseModel.content,
                ExerciseModel.order_index,
                LessonModel.id,
                LessonModel.title,
                LessonModel.order_index,
                SkillModel.id,
                SkillModel.title,
                SkillModel.order_index,
                CategoryModel.id,
                CategoryModel.title,
                CategoryModel.order_index,
                CategoryModel.course_id,
            )
            .join(LessonModel, LessonModel.id == ExerciseModel.lesson_id)
            .join(SkillModel, SkillModel.id == LessonModel.skill_id)
            .join(CategoryModel, CategoryModel.id == SkillModel.category_id)
        )
        return [ExerciseRow(*r) for r in rows.all()]

    async def workbook_rows(self) -> list[WorkbookRow]:
        rows = await self._session.execute(
            select(
                CurriculumRowModel.ref,
                CurriculumRowModel.english,
                CurriculumRowModel.text,
                CurriculumRowModel.audio_url,
                CurriculumRowModel.lesson_ref,
                CurriculumEntryModel.title,
                CurriculumRowModel.course_id,
            )
            .outerjoin(
                CurriculumEntryModel,
                and_(
                    CurriculumEntryModel.course_id == CurriculumRowModel.course_id,
                    CurriculumEntryModel.ref == CurriculumRowModel.lesson_ref,
                ),
            )
            .where(CurriculumRowModel.audio_url.is_not(None), CurriculumRowModel.audio_url != "")
        )
        return [WorkbookRow(*r) for r in rows.all()]

    async def letters(self) -> list[LetterRow]:
        rows = await self._session.execute(
            select(
                SoundLetterModel.id,
                SoundLetterModel.language,
                SoundLetterModel.group_key,
                SoundLetterModel.position,
                SoundLetterModel.glyph,
                SoundLetterModel.romanization,
                SoundLetterModel.example_word,
                SoundLetterModel.audio_url,
                SoundLetterModel.example_audio_url,
            ).where(
                or_(
                    SoundLetterModel.audio_url.is_not(None),
                    SoundLetterModel.example_audio_url.is_not(None),
                )
            )
        )
        return [LetterRow(*r) for r in rows.all()]
