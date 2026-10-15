"""The admin activity log's storage (intent 030): writing entries, naming
what a route changes, and reading the log back with filters."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any

from sqlalchemy import Select, delete, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.activity import ActivityEntry, ActivityTarget
from app.infrastructure.db.activity_models import AdminActivityModel
from app.infrastructure.db.admin_member_models import AdminMemberModel
from app.infrastructure.db.curriculum_models import CurriculumEntryModel, CurriculumRowModel
from app.infrastructure.db.feedback_models import FeedbackModel
from app.infrastructure.db.league_models import LeagueMemberModel
from app.infrastructure.db.lesson_models import (
    CategoryModel,
    CourseModel,
    ExerciseModel,
    LanguageModel,
    LessonModel,
    SkillModel,
    VocabItemModel,
)
from app.infrastructure.db.models import UserModel
from app.infrastructure.db.sound_models import SoundLetterModel


def _utc(value: datetime) -> datetime:
    """SQLite hands timestamps back without a time zone; they are UTC."""
    return value.replace(tzinfo=UTC) if value.tzinfo is None else value.astimezone(UTC)


def _short(value: str | None, limit: int = 120) -> str | None:
    if value is None:
        return None
    value = " ".join(value.split())
    return value if len(value) <= limit else value[: limit - 1] + "…"


@dataclass(frozen=True)
class ActivityFilters:
    admin_email: str | None = None
    area: str | None = None
    course_id: str | None = None
    since: datetime | None = None
    before: datetime | None = None
    search: str = ""


@dataclass(frozen=True)
class ActivityCursor:
    """The last entry of a page: the next page starts after it."""

    created_at: datetime
    id: str


class SqlAlchemyActivityRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    # --- Writing -------------------------------------------------------------

    async def add(self, entry: ActivityEntry) -> None:
        # A savepoint: if the entry can't be written, the admin's change
        # (already in this transaction) still commits.
        async with self._session.begin_nested():
            self._session.add(
                AdminActivityModel(
                    id=entry.id,
                    created_at=entry.created_at,
                    admin_email=entry.admin_email,
                    admin_role=entry.admin_role,
                    method=entry.method,
                    route=entry.route,
                    area=entry.area,
                    action=entry.action,
                    target_kind=entry.target_kind,
                    target_id=entry.target_id,
                    target_name=entry.target_name,
                    course_id=entry.course_id,
                    link=entry.link,
                    details=entry.details,
                )
            )

    async def prune(self, older_than: datetime) -> None:
        await self._session.execute(
            delete(AdminActivityModel).where(AdminActivityModel.created_at < older_than)
        )

    # --- Naming the target ---------------------------------------------------

    async def describe(self, kind: str, params: dict[str, str]) -> ActivityTarget:
        """The target's name, course and admin-site link, read before the
        change, so a delete still has its name. Unknown ids keep only the
        id."""
        describe = getattr(self, f"_describe_{kind}", None)
        target = ActivityTarget(kind=kind)
        if describe is not None:
            await describe(target, params)
        return target

    async def _one(self, stmt: Select[Any]) -> Any:
        return (await self._session.execute(stmt.limit(1))).one_or_none()

    async def _describe_course(self, t: ActivityTarget, p: dict[str, str]) -> None:
        t.id = p["course_id"]
        t.course_id = t.id
        row = await self._one(select(CourseModel.title).where(CourseModel.id == t.id))
        if row is not None:
            t.name, t.link = row[0], f"/courses/{t.id}"

    async def _describe_section(self, t: ActivityTarget, p: dict[str, str]) -> None:
        t.id = p["section_id"]
        row = await self._one(
            select(CategoryModel.title, CategoryModel.course_id).where(CategoryModel.id == t.id)
        )
        if row is not None:
            t.name, t.course_id = row
            t.link = f"/courses/{t.course_id}"

    async def _describe_skill(self, t: ActivityTarget, p: dict[str, str]) -> None:
        t.id = p["skill_id"]
        row = await self._one(
            select(SkillModel.title, CategoryModel.course_id)
            .join(CategoryModel, CategoryModel.id == SkillModel.category_id)
            .where(SkillModel.id == t.id)
        )
        if row is not None:
            t.name, t.course_id = row
            t.link = f"/courses/{t.course_id}"

    async def _describe_lesson(self, t: ActivityTarget, p: dict[str, str]) -> None:
        t.id = p["lesson_id"]
        row = await self._one(
            select(LessonModel.title, CategoryModel.course_id)
            .join(SkillModel, SkillModel.id == LessonModel.skill_id)
            .join(CategoryModel, CategoryModel.id == SkillModel.category_id)
            .where(LessonModel.id == t.id)
        )
        if row is not None:
            t.name, t.course_id = row
            t.link = f"/courses/{t.course_id}"

    async def _describe_exercise(self, t: ActivityTarget, p: dict[str, str]) -> None:
        t.id = p["exercise_id"]
        row = await self._one(
            select(
                ExerciseModel.type,
                ExerciseModel.lesson_id,
                LessonModel.title,
                CategoryModel.course_id,
            )
            .join(LessonModel, LessonModel.id == ExerciseModel.lesson_id)
            .join(SkillModel, SkillModel.id == LessonModel.skill_id)
            .join(CategoryModel, CategoryModel.id == SkillModel.category_id)
            .where(ExerciseModel.id == t.id)
        )
        if row is not None:
            kind, lesson_id, lesson_title, t.course_id = row
            t.name = f"{kind.replace('_', ' ')} in {lesson_title}"
            t.link = f"/courses/{t.course_id}/lessons/{lesson_id}/exercises/{t.id}"

    async def _describe_vocab(self, t: ActivityTarget, p: dict[str, str]) -> None:
        t.id = p["vocab_item_id"]
        row = await self._one(
            select(VocabItemModel.word, VocabItemModel.course_id).where(VocabItemModel.id == t.id)
        )
        if row is not None:
            t.name, t.course_id = row
            t.link = f"/courses/{t.course_id}/vocabulary"

    async def _describe_workbook_row(self, t: ActivityTarget, p: dict[str, str]) -> None:
        t.id, t.course_id = p["ref"], p["course_id"]
        row = await self._one(
            select(CurriculumRowModel.english, CurriculumRowModel.lesson_ref).where(
                CurriculumRowModel.course_id == t.course_id, CurriculumRowModel.ref == t.id
            )
        )
        if row is not None:
            english, lesson_ref = row
            t.name = _short(english)
            t.link = f"/courses/{t.course_id}/workbook/lessons/{lesson_ref}"

    async def _describe_workbook_lesson(self, t: ActivityTarget, p: dict[str, str]) -> None:
        t.id, t.course_id = p["ref"], p["course_id"]
        row = await self._one(
            select(CurriculumEntryModel.title).where(
                CurriculumEntryModel.course_id == t.course_id, CurriculumEntryModel.ref == t.id
            )
        )
        if row is not None:
            t.name = row[0]
            t.link = f"/courses/{t.course_id}/workbook/lessons/{t.id}"

    async def _language_name(self, code: str) -> str | None:
        row = await self._one(select(LanguageModel.name).where(LanguageModel.code == code))
        return row[0] if row is not None else None

    async def _describe_sound_chart(self, t: ActivityTarget, p: dict[str, str]) -> None:
        t.id = p["language"]
        t.name = await self._language_name(t.id) or t.id
        t.link = f"/sounds/{t.id}"

    async def _describe_sound_letter(self, t: ActivityTarget, p: dict[str, str]) -> None:
        t.id = p["letter_id"]
        language = p["language"]
        row = await self._one(
            select(SoundLetterModel.glyph, SoundLetterModel.romanization).where(
                SoundLetterModel.id == t.id, SoundLetterModel.language == language
            )
        )
        if row is not None:
            glyph, romanization = row
            t.name = f"{glyph} ({romanization})" if romanization else glyph
            t.link = f"/sounds/{language}/letters/{t.id}"

    async def _describe_language(self, t: ActivityTarget, p: dict[str, str]) -> None:
        t.id = p["code"]
        name = await self._language_name(t.id)
        if name is not None:
            t.name, t.link = name, "/languages"

    async def _describe_voice_language(self, t: ActivityTarget, p: dict[str, str]) -> None:
        t.id = p["language"]
        t.name = await self._language_name(t.id) or t.id
        t.link = "/voices"

    async def _describe_team_member(self, t: ActivityTarget, p: dict[str, str]) -> None:
        t.id = p["member_id"]
        row = await self._one(select(AdminMemberModel.email).where(AdminMemberModel.id == t.id))
        if row is not None:
            t.name, t.link = row[0], "/team"

    async def _describe_feedback(self, t: ActivityTarget, p: dict[str, str]) -> None:
        t.id = p["feedback_id"]
        row = await self._one(
            select(FeedbackModel.category, UserModel.first_name, UserModel.email)
            .join(UserModel, UserModel.id == FeedbackModel.user_id)
            .where(FeedbackModel.id == t.id)
        )
        if row is not None:
            category, first_name, email = row
            t.name = f"{category.capitalize()} from {first_name or email or 'a learner'}"
            t.link = "/feedback"

    async def _describe_league_member(self, t: ActivityTarget, p: dict[str, str]) -> None:
        t.id = p["member_id"]
        row = await self._one(
            select(LeagueMemberModel.week_start, UserModel.first_name, UserModel.email)
            .join(UserModel, UserModel.id == LeagueMemberModel.user_id)
            .where(LeagueMemberModel.id == t.id)
        )
        if row is not None:
            week, first_name, email = row
            t.name = " · ".join(v for v in (first_name, email) if v) or "Learner"
            t.link = f"/leagues?week={week.isoformat()}"

    # --- Reading -------------------------------------------------------------

    def _filtered(self, f: ActivityFilters) -> Select[Any]:
        stmt = select(AdminActivityModel)
        if f.admin_email:
            stmt = stmt.where(AdminActivityModel.admin_email == f.admin_email)
        if f.area:
            stmt = stmt.where(AdminActivityModel.area == f.area)
        if f.course_id:
            stmt = stmt.where(AdminActivityModel.course_id == f.course_id)
        if f.since is not None:
            stmt = stmt.where(AdminActivityModel.created_at >= f.since)
        if f.before is not None:
            stmt = stmt.where(AdminActivityModel.created_at < f.before)
        if f.search:
            like = f"%{f.search.lower()}%"
            stmt = stmt.where(
                or_(
                    func.lower(AdminActivityModel.action).like(like),
                    func.lower(AdminActivityModel.target_name).like(like),
                    func.lower(AdminActivityModel.target_id).like(like),
                    func.lower(AdminActivityModel.admin_email).like(like),
                )
            )
        return stmt

    async def entries(
        self, filters: ActivityFilters, after: ActivityCursor | None, limit: int
    ) -> list[ActivityEntry]:
        stmt = self._filtered(filters)
        if after is not None:
            stmt = stmt.where(
                or_(
                    AdminActivityModel.created_at < after.created_at,
                    (AdminActivityModel.created_at == after.created_at)
                    & (AdminActivityModel.id < after.id),
                )
            )
        stmt = stmt.order_by(
            AdminActivityModel.created_at.desc(), AdminActivityModel.id.desc()
        ).limit(limit)
        rows = (await self._session.execute(stmt)).scalars().all()
        return [
            ActivityEntry(
                id=r.id,
                created_at=_utc(r.created_at),
                admin_email=r.admin_email,
                admin_role=r.admin_role,
                method=r.method,
                route=r.route,
                area=r.area,
                action=r.action,
                target_kind=r.target_kind,
                target_id=r.target_id,
                target_name=r.target_name,
                course_id=r.course_id,
                link=r.link,
                details=dict(r.details or {}),
            )
            for r in rows
        ]

    async def count(self, filters: ActivityFilters) -> int:
        stmt = select(func.count()).select_from(self._filtered(filters).subquery())
        return int((await self._session.execute(stmt)).scalar_one())

    async def admins(self) -> list[str]:
        stmt = select(AdminActivityModel.admin_email).distinct()
        return sorted(r[0] for r in (await self._session.execute(stmt)).all())

    async def areas(self) -> list[str]:
        stmt = select(AdminActivityModel.area).distinct()
        return [r[0] for r in (await self._session.execute(stmt)).all()]

    async def courses(self) -> list[tuple[str, str]]:
        """(id, title) of the courses entries name, deleted ones left out."""
        stmt = (
            select(CourseModel.id, CourseModel.title)
            .where(
                CourseModel.id.in_(
                    select(AdminActivityModel.course_id)
                    .where(AdminActivityModel.course_id.is_not(None))
                    .distinct()
                )
            )
            .order_by(CourseModel.order_index)
        )
        return [(r[0], r[1]) for r in (await self._session.execute(stmt)).all()]
