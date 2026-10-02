"""SQL for the admin site's learner pages and reports (`026-learner-reports`).

Read-only: it only reads rows the learner app already writes (accounts,
lesson and practice attempts, skill progress, streaks) and never changes
anything. Grouping by day, week or month happens in Python, in
`admin_learner_use_cases`, so the same code runs on SQLite and Postgres and
the calendar is UTC everywhere, as the streak's is.
"""

from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any

from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.infrastructure.db.lesson_models import (
    CategoryModel,
    CourseModel,
    LessonAttemptModel,
    LessonModel,
    PracticeAttemptModel,
    SkillModel,
    UserSkillProgressModel,
    UserStreakModel,
)
from app.infrastructure.db.models import UserModel


def as_utc(value: datetime) -> datetime:
    """SQLite hands timestamps back without a zone; they were written in UTC."""
    return value.replace(tzinfo=UTC) if value.tzinfo is None else value.astimezone(UTC)


@dataclass(frozen=True)
class LearnerRow:
    """One learner as the list shows them, with their all-time totals."""

    user: UserModel
    lessons: int
    practice_sessions: int
    xp: int
    correct: int
    answered: int
    skills_completed: int
    last_active_at: datetime | None
    streak: UserStreakModel | None


@dataclass(frozen=True)
class CourseOutline:
    """A course's sections and skills in order, and each skill's lesson count."""

    course: CourseModel
    sections: list[CategoryModel]
    skills: list[SkillModel]
    lesson_counts: dict[str, int]


@dataclass(frozen=True)
class Attempt:
    """A finished lesson or practice session, as the reports count it.
    `course_id` is the lesson's course; for practice, which spans lessons,
    it is the learner's course at the time of reading."""

    user_id: str
    at: datetime
    xp: int
    correct: int
    answered: int
    course_id: str | None
    practice: bool


class SqlAlchemyAdminLearnerRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    # --- the learner list ------------------------------------------------

    async def list_learners(
        self, search: str = "", course_id: str | None = None, user_id: str | None = None
    ) -> list[LearnerRow]:
        """Every learner matching `search` (name or email) and, when given,
        on `course_id`, with their totals. Sorting and paging are the
        caller's, so any column can be sorted on the same way."""
        lessons = (
            select(
                LessonAttemptModel.user_id.label("user_id"),
                func.count().label("n"),
                func.sum(LessonAttemptModel.xp_awarded).label("xp"),
                func.sum(LessonAttemptModel.correct_count).label("correct"),
                func.sum(LessonAttemptModel.total_count).label("answered"),
                func.max(LessonAttemptModel.completed_at).label("last"),
            )
            .group_by(LessonAttemptModel.user_id)
            .subquery()
        )
        practice = (
            select(
                PracticeAttemptModel.user_id.label("user_id"),
                func.count().label("n"),
                func.sum(PracticeAttemptModel.xp_awarded).label("xp"),
                func.sum(PracticeAttemptModel.correct_count).label("correct"),
                func.sum(PracticeAttemptModel.total_count).label("answered"),
                func.max(PracticeAttemptModel.completed_at).label("last"),
            )
            .group_by(PracticeAttemptModel.user_id)
            .subquery()
        )
        skills = (
            select(UserSkillProgressModel.user_id.label("user_id"), func.count().label("n"))
            .where(UserSkillProgressModel.completed_at.is_not(None))
            .group_by(UserSkillProgressModel.user_id)
            .subquery()
        )
        stmt = (
            select(
                UserModel,
                lessons.c.n,
                lessons.c.xp,
                lessons.c.correct,
                lessons.c.answered,
                lessons.c.last,
                practice.c.n,
                practice.c.xp,
                practice.c.correct,
                practice.c.answered,
                practice.c.last,
                skills.c.n,
                UserStreakModel,
            )
            .outerjoin(lessons, lessons.c.user_id == UserModel.id)
            .outerjoin(practice, practice.c.user_id == UserModel.id)
            .outerjoin(skills, skills.c.user_id == UserModel.id)
            .outerjoin(UserStreakModel, UserStreakModel.user_id == UserModel.id)
        )
        if search:
            pattern = f"%{search}%"
            stmt = stmt.where(
                or_(UserModel.email.ilike(pattern), UserModel.first_name.ilike(pattern))
            )
        if course_id:
            stmt = stmt.where(UserModel.active_course_id == course_id)
        if user_id:
            stmt = stmt.where(UserModel.id == user_id)

        rows: list[LearnerRow] = []
        for (
            user,
            l_n,
            l_xp,
            l_correct,
            l_answered,
            l_last,
            p_n,
            p_xp,
            p_correct,
            p_answered,
            p_last,
            s_n,
            streak,
        ) in (await self._session.execute(stmt)).all():
            lasts = [as_utc(t) for t in (l_last, p_last) if t is not None]
            rows.append(
                LearnerRow(
                    user=user,
                    lessons=l_n or 0,
                    practice_sessions=p_n or 0,
                    xp=(l_xp or 0) + (p_xp or 0),
                    correct=(l_correct or 0) + (p_correct or 0),
                    answered=(l_answered or 0) + (p_answered or 0),
                    skills_completed=s_n or 0,
                    last_active_at=max(lasts) if lasts else None,
                    streak=streak,
                )
            )
        return rows

    async def get_learner(self, user_id: str) -> LearnerRow | None:
        rows = await self.list_learners(user_id=user_id)
        return rows[0] if rows else None

    # --- one learner -------------------------------------------------------

    async def lesson_attempts_of(self, user_id: str) -> list[Any]:
        """Every lesson the learner finished, newest first, with where it
        sits: (attempt, lesson title, skill id, skill title, course id)."""
        stmt = (
            select(
                LessonAttemptModel,
                LessonModel.title,
                SkillModel.id,
                SkillModel.title,
                CategoryModel.course_id,
            )
            .join(LessonModel, LessonModel.id == LessonAttemptModel.lesson_id)
            .join(SkillModel, SkillModel.id == LessonModel.skill_id)
            .join(CategoryModel, CategoryModel.id == SkillModel.category_id)
            .where(LessonAttemptModel.user_id == user_id)
            .order_by(LessonAttemptModel.completed_at.desc())
        )
        return list((await self._session.execute(stmt)).all())

    async def practice_attempts_of(self, user_id: str) -> list[PracticeAttemptModel]:
        stmt = (
            select(PracticeAttemptModel)
            .where(PracticeAttemptModel.user_id == user_id)
            .order_by(PracticeAttemptModel.completed_at.desc())
        )
        return list((await self._session.execute(stmt)).scalars().all())

    async def skill_progress_of(self, user_id: str) -> list[UserSkillProgressModel]:
        stmt = select(UserSkillProgressModel).where(UserSkillProgressModel.user_id == user_id)
        return list((await self._session.execute(stmt)).scalars().all())

    async def course_outlines(self, course_ids: Sequence[str]) -> dict[str, CourseOutline]:
        """For each course: the course, its sections, skills and how many
        lessons each skill has, all in order."""
        if not course_ids:
            return {}
        courses = (
            (await self._session.execute(select(CourseModel).where(CourseModel.id.in_(course_ids))))
            .scalars()
            .all()
        )
        sections = (
            (
                await self._session.execute(
                    select(CategoryModel)
                    .where(CategoryModel.course_id.in_(course_ids))
                    .order_by(CategoryModel.order_index)
                )
            )
            .scalars()
            .all()
        )
        section_ids = [s.id for s in sections]
        skills = (
            (
                await self._session.execute(
                    select(SkillModel)
                    .where(SkillModel.category_id.in_(section_ids))
                    .order_by(SkillModel.order_index)
                )
            )
            .scalars()
            .all()
            if section_ids
            else []
        )
        skill_ids = [s.id for s in skills]
        lesson_counts: dict[str, int] = {}
        if skill_ids:
            for skill_id, n in (
                await self._session.execute(
                    select(LessonModel.skill_id, func.count())
                    .where(LessonModel.skill_id.in_(skill_ids))
                    .group_by(LessonModel.skill_id)
                )
            ).all():
                lesson_counts[skill_id] = n
        outlines: dict[str, CourseOutline] = {}
        for course in courses:
            own = [s for s in sections if s.course_id == course.id]
            own_ids = {s.id for s in own}
            outlines[course.id] = CourseOutline(
                course, own, [s for s in skills if s.category_id in own_ids], lesson_counts
            )
        return outlines

    # --- reports -------------------------------------------------------------

    async def attempts_between(self, start: datetime, end: datetime) -> list[Attempt]:
        """Every lesson and practice session finished in `[start, end)`."""
        lesson_stmt = (
            select(
                LessonAttemptModel.user_id,
                LessonAttemptModel.completed_at,
                LessonAttemptModel.xp_awarded,
                LessonAttemptModel.correct_count,
                LessonAttemptModel.total_count,
                CategoryModel.course_id,
            )
            .join(LessonModel, LessonModel.id == LessonAttemptModel.lesson_id)
            .join(SkillModel, SkillModel.id == LessonModel.skill_id)
            .join(CategoryModel, CategoryModel.id == SkillModel.category_id)
            .where(LessonAttemptModel.completed_at >= start, LessonAttemptModel.completed_at < end)
        )
        practice_stmt = (
            select(
                PracticeAttemptModel.user_id,
                PracticeAttemptModel.completed_at,
                PracticeAttemptModel.xp_awarded,
                PracticeAttemptModel.correct_count,
                PracticeAttemptModel.total_count,
                UserModel.active_course_id,
            )
            .join(UserModel, UserModel.id == PracticeAttemptModel.user_id)
            .where(
                PracticeAttemptModel.completed_at >= start, PracticeAttemptModel.completed_at < end
            )
        )
        attempts = [
            Attempt(user_id, as_utc(at), xp, correct, answered, course_id, practice=False)
            for user_id, at, xp, correct, answered, course_id in (
                await self._session.execute(lesson_stmt)
            ).all()
        ]
        attempts += [
            Attempt(user_id, as_utc(at), xp, correct, answered, course_id, practice=True)
            for user_id, at, xp, correct, answered, course_id in (
                await self._session.execute(practice_stmt)
            ).all()
        ]
        return attempts

    async def accounts(self) -> list[tuple[str, datetime, str]]:
        """Every account: (id, when it was made, its course now)."""
        stmt = select(UserModel.id, UserModel.created_at, UserModel.active_course_id)
        return [
            (user_id, as_utc(created), course_id)
            for user_id, created, course_id in (await self._session.execute(stmt)).all()
        ]

    async def users_by_id(self, user_ids: Sequence[str]) -> dict[str, UserModel]:
        if not user_ids:
            return {}
        stmt = select(UserModel).where(UserModel.id.in_(user_ids))
        return {u.id: u for u in (await self._session.execute(stmt)).scalars().all()}

    async def skills_completed_between(
        self, start: datetime, end: datetime
    ) -> list[tuple[str, str, datetime]]:
        """Skills first finished in `[start, end)`: (user id, course id, when)."""
        stmt = (
            select(
                UserSkillProgressModel.user_id,
                CategoryModel.course_id,
                UserSkillProgressModel.completed_at,
            )
            .join(SkillModel, SkillModel.id == UserSkillProgressModel.skill_id)
            .join(CategoryModel, CategoryModel.id == SkillModel.category_id)
            .where(
                UserSkillProgressModel.completed_at >= start,
                UserSkillProgressModel.completed_at < end,
            )
        )
        return [
            (user_id, course_id, as_utc(at))
            for user_id, course_id, at in (await self._session.execute(stmt)).all()
        ]

    async def courses_by_id(self) -> dict[str, CourseModel]:
        stmt = select(CourseModel).order_by(CourseModel.order_index)
        return {c.id: c for c in (await self._session.execute(stmt)).scalars().all()}
