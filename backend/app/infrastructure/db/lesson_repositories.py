"""SQLAlchemy-backed implementations of the lesson-content domain's
repository Protocols.

Owns the mapping between domain entities/value objects and the
`SkillModel`/`LessonModel`/`ExerciseModel`/`UserSkillProgressModel` ORM
rows, including reconstructing the correct `ExerciseContent`/`AnswerKey`
value object from each `ExerciseModel`'s `type` + JSON `content`/
`answer_key` columns (ADR-3).
"""

from __future__ import annotations

from collections.abc import Sequence
from datetime import UTC, date, datetime
from typing import Any

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.domain.lesson.entities import (
    Exercise,
    Lesson,
    LessonAttempt,
    Skill,
    UserBeans,
    UserSkillProgress,
    UserStreak,
)
from app.domain.lesson.value_objects import (
    AnswerKey,
    ChoiceAnswerKey,
    ExerciseContent,
    ExerciseType,
    LessonCompletionOutcome,
    ListeningContent,
    MultipleChoiceContent,
    SentenceConstructionContent,
    SequenceAnswerKey,
)
from app.domain.lesson.value_objects import Choice as ChoiceVO
from app.infrastructure.db.lesson_models import (
    ExerciseModel,
    LessonAttemptModel,
    LessonModel,
    SkillModel,
    UserBeansModel,
    UserSkillProgressModel,
    UserStreakModel,
)


def _ensure_utc(value: datetime) -> datetime:
    """Same SQLite-timezone-round-trip normalization as
    `app/infrastructure/db/repositories.py` -- see that module's docstring
    for why this is necessary (SQLite does not persist tzinfo even on a
    `DateTime(timezone=True)` column).
    """
    if value.tzinfo is None:
        return value.replace(tzinfo=UTC)
    return value.astimezone(UTC)


def _choices_from_json(raw: list[dict[str, Any]]) -> tuple[ChoiceVO, ...]:
    return tuple(ChoiceVO(id=item["id"], text=item["text"]) for item in raw)


def _content_from_json(exercise_type: ExerciseType, content: dict[str, Any]) -> ExerciseContent:
    if exercise_type is ExerciseType.MULTIPLE_CHOICE:
        return MultipleChoiceContent(choices=_choices_from_json(content["choices"]))
    if exercise_type is ExerciseType.LISTENING:
        return ListeningContent(
            audio_url=content["audio_url"], choices=_choices_from_json(content["choices"])
        )
    return SentenceConstructionContent(word_bank=_choices_from_json(content["word_bank"]))


def _answer_key_from_json(exercise_type: ExerciseType, answer_key: dict[str, Any]) -> AnswerKey:
    if exercise_type is ExerciseType.SENTENCE_CONSTRUCTION:
        return SequenceAnswerKey(correct_sequence=tuple(answer_key["correct_sequence"]))
    return ChoiceAnswerKey(correct_choice_id=answer_key["correct_choice_id"])


def _exercise_model_to_domain(model: ExerciseModel) -> Exercise:
    exercise_type = ExerciseType(model.type)
    return Exercise(
        id=model.id,
        lesson_id=model.lesson_id,
        order_index=model.order_index,
        type=exercise_type,
        prompt=model.prompt,
        content=_content_from_json(exercise_type, model.content),
        answer_key=_answer_key_from_json(exercise_type, model.answer_key),
    )


def _skill_model_to_domain(model: SkillModel) -> Skill:
    return Skill(id=model.id, title=model.title, order_index=model.order_index)


def _lesson_model_to_domain(model: LessonModel) -> Lesson:
    return Lesson(
        id=model.id,
        skill_id=model.skill_id,
        title=model.title,
        order_index=model.order_index,
        exercises=[
            _exercise_model_to_domain(e)
            for e in sorted(model.exercises, key=lambda e: e.order_index)
        ],
    )


def _progress_model_to_domain(model: UserSkillProgressModel) -> UserSkillProgress:
    return UserSkillProgress(
        user_id=model.user_id,
        skill_id=model.skill_id,
        unlocked=model.unlocked,
        crown_level=model.crown_level,
        completed_at=_ensure_utc(model.completed_at) if model.completed_at else None,
        completed_lesson_ids_this_cycle=frozenset(model.completed_lesson_ids_this_cycle),
    )


def _beans_model_to_domain(model: UserBeansModel) -> UserBeans:
    return UserBeans(
        user_id=model.user_id,
        current_count=model.current_count,
        last_regen_at=_ensure_utc(model.last_regen_at),
        amole_balance=model.amole_balance,
    )


def _streak_model_to_domain(model: UserStreakModel) -> UserStreak:
    return UserStreak(
        user_id=model.user_id,
        current_streak=model.current_streak,
        last_completed_date=model.last_completed_date,
        active_freeze_count=model.active_freeze_count,
    )


def _attempt_model_to_domain(model: LessonAttemptModel) -> LessonAttempt:
    return LessonAttempt(
        id=model.id,
        user_id=model.user_id,
        lesson_id=model.lesson_id,
        correct_count=model.correct_count,
        total_count=model.total_count,
        xp_awarded=model.xp_awarded,
        completed_at=_ensure_utc(model.completed_at),
        outcome=LessonCompletionOutcome(**model.result),
    )


class SqlAlchemySkillRepository:
    """Implements `app.domain.lesson.repositories.SkillRepository`."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def list_all(self) -> list[Skill]:
        stmt = select(SkillModel).order_by(SkillModel.order_index)
        result = await self._session.execute(stmt)
        return [_skill_model_to_domain(m) for m in result.scalars().all()]


class SqlAlchemyLessonRepository:
    """Implements `app.domain.lesson.repositories.LessonRepository`.

    Loads a lesson and its full ordered `exercises` list in a single query
    (`selectinload`) -- no per-exercise round trip, per the aggregate's
    shape and the "one request per lesson" NFR.
    """

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_by_id(self, lesson_id: str) -> Lesson | None:
        stmt = (
            select(LessonModel)
            .where(LessonModel.id == lesson_id)
            .options(selectinload(LessonModel.exercises))
        )
        result = await self._session.execute(stmt)
        model = result.scalar_one_or_none()
        return _lesson_model_to_domain(model) if model is not None else None

    async def get_content_version(self, lesson_id: str) -> datetime | None:
        stmt = (
            select(LessonModel.updated_at, func.max(ExerciseModel.updated_at))
            .outerjoin(ExerciseModel, ExerciseModel.lesson_id == LessonModel.id)
            .where(LessonModel.id == lesson_id)
            .group_by(LessonModel.id, LessonModel.updated_at)
        )
        result = await self._session.execute(stmt)
        row = result.first()
        if row is None:
            return None
        lesson_updated_at, max_exercise_updated_at = row
        version = _ensure_utc(lesson_updated_at)
        if max_exercise_updated_at is not None:
            version = max(version, _ensure_utc(max_exercise_updated_at))
        return version

    async def list_content_versions_by_skills(
        self, skill_ids: Sequence[str]
    ) -> dict[str, datetime]:
        if not skill_ids:
            return {}

        # Two grouped queries (lesson-level, then exercise-level via a join
        # to its owning lesson), not a per-skill round trip -- same
        # discipline as `list_lesson_ids_by_skills`.
        lesson_stmt = (
            select(LessonModel.skill_id, func.max(LessonModel.updated_at))
            .where(LessonModel.skill_id.in_(skill_ids))
            .group_by(LessonModel.skill_id)
        )
        lesson_result = await self._session.execute(lesson_stmt)
        version_by_skill: dict[str, datetime] = {
            skill_id: _ensure_utc(max_updated) for skill_id, max_updated in lesson_result.all()
        }

        exercise_stmt = (
            select(LessonModel.skill_id, func.max(ExerciseModel.updated_at))
            .join(ExerciseModel, ExerciseModel.lesson_id == LessonModel.id)
            .where(LessonModel.skill_id.in_(skill_ids))
            .group_by(LessonModel.skill_id)
        )
        exercise_result = await self._session.execute(exercise_stmt)
        for skill_id, max_updated in exercise_result.all():
            candidate = _ensure_utc(max_updated)
            if skill_id not in version_by_skill or candidate > version_by_skill[skill_id]:
                version_by_skill[skill_id] = candidate

        return version_by_skill

    async def list_lesson_ids_by_skill(self, skill_id: str) -> tuple[str, ...]:
        stmt = (
            select(LessonModel.id)
            .where(LessonModel.skill_id == skill_id)
            .order_by(LessonModel.order_index)
        )
        result = await self._session.execute(stmt)
        return tuple(result.scalars().all())

    async def list_lesson_ids_by_skills(
        self, skill_ids: Sequence[str]
    ) -> dict[str, tuple[str, ...]]:
        if not skill_ids:
            return {}
        stmt = (
            select(LessonModel.skill_id, LessonModel.id)
            .where(LessonModel.skill_id.in_(skill_ids))
            .order_by(LessonModel.skill_id, LessonModel.order_index)
        )
        result = await self._session.execute(stmt)
        grouped: dict[str, list[str]] = {}
        for skill_id, lesson_id in result.all():
            grouped.setdefault(skill_id, []).append(lesson_id)
        return {skill_id: tuple(ids) for skill_id, ids in grouped.items()}


class SqlAlchemyUserSkillProgressRepository:
    """Implements `app.domain.lesson.repositories.UserSkillProgressRepository`.

    `upsert` (bolt 005) does a fetch-then-insert-or-update per row, same
    convention as the seed script's idempotent writes (bolt 004's
    Technical Design, Decision 3) -- no dialect-specific `ON CONFLICT`, for
    SQLite/PostgreSQL portability (`data-stack.md`).
    """

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def list_by_user(self, user_id: str) -> list[UserSkillProgress]:
        stmt = select(UserSkillProgressModel).where(UserSkillProgressModel.user_id == user_id)
        result = await self._session.execute(stmt)
        return [_progress_model_to_domain(m) for m in result.scalars().all()]

    async def get(self, user_id: str, skill_id: str) -> UserSkillProgress | None:
        stmt = select(UserSkillProgressModel).where(
            UserSkillProgressModel.user_id == user_id, UserSkillProgressModel.skill_id == skill_id
        )
        result = await self._session.execute(stmt)
        model = result.scalar_one_or_none()
        return _progress_model_to_domain(model) if model is not None else None

    async def upsert(self, progress: UserSkillProgress) -> None:
        stmt = select(UserSkillProgressModel).where(
            UserSkillProgressModel.user_id == progress.user_id,
            UserSkillProgressModel.skill_id == progress.skill_id,
        )
        result = await self._session.execute(stmt)
        model = result.scalar_one_or_none()
        if model is None:
            model = UserSkillProgressModel(user_id=progress.user_id, skill_id=progress.skill_id)
            self._session.add(model)
        model.unlocked = progress.unlocked
        model.crown_level = progress.crown_level
        model.completed_at = progress.completed_at
        model.completed_lesson_ids_this_cycle = list(progress.completed_lesson_ids_this_cycle)


class SqlAlchemyUserBeansRepository:
    """Implements `app.domain.lesson.repositories.UserBeansRepository`."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get(self, user_id: str) -> UserBeans | None:
        stmt = select(UserBeansModel).where(UserBeansModel.user_id == user_id)
        result = await self._session.execute(stmt)
        model = result.scalar_one_or_none()
        return _beans_model_to_domain(model) if model is not None else None

    async def upsert(self, beans: UserBeans) -> None:
        stmt = select(UserBeansModel).where(UserBeansModel.user_id == beans.user_id)
        result = await self._session.execute(stmt)
        model = result.scalar_one_or_none()
        if model is None:
            model = UserBeansModel(user_id=beans.user_id)
            self._session.add(model)
        model.current_count = beans.current_count
        model.last_regen_at = beans.last_regen_at
        model.amole_balance = beans.amole_balance


class SqlAlchemyUserStreakRepository:
    """Implements `app.domain.lesson.repositories.UserStreakRepository`."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get(self, user_id: str) -> UserStreak | None:
        stmt = select(UserStreakModel).where(UserStreakModel.user_id == user_id)
        result = await self._session.execute(stmt)
        model = result.scalar_one_or_none()
        return _streak_model_to_domain(model) if model is not None else None

    async def upsert(self, streak: UserStreak) -> None:
        stmt = select(UserStreakModel).where(UserStreakModel.user_id == streak.user_id)
        result = await self._session.execute(stmt)
        model = result.scalar_one_or_none()
        if model is None:
            model = UserStreakModel(user_id=streak.user_id)
            self._session.add(model)
        model.current_streak = streak.current_streak
        model.last_completed_date = streak.last_completed_date
        model.active_freeze_count = streak.active_freeze_count


class SqlAlchemyLessonAttemptRepository:
    """Implements `app.domain.lesson.repositories.LessonAttemptRepository`.

    `add` never updates an existing row -- `id` is the idempotency key
    (story 003); the application layer always checks `get(attempt_id)`
    first and short-circuits before ever calling `add` a second time for
    the same id.
    """

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get(self, attempt_id: str) -> LessonAttempt | None:
        stmt = select(LessonAttemptModel).where(LessonAttemptModel.id == attempt_id)
        result = await self._session.execute(stmt)
        model = result.scalar_one_or_none()
        return _attempt_model_to_domain(model) if model is not None else None

    async def add(self, attempt: LessonAttempt) -> None:
        outcome_dict = {
            "xp_awarded": attempt.outcome.xp_awarded,
            "daily_xp_total": attempt.outcome.daily_xp_total,
            "daily_xp_target": attempt.outcome.daily_xp_target,
            "streak_count": attempt.outcome.streak_count,
            "streak_increased_today": attempt.outcome.streak_increased_today,
            "accuracy_percent": attempt.outcome.accuracy_percent,
            "correct_count": attempt.outcome.correct_count,
            "total_count": attempt.outcome.total_count,
            "time_spent_seconds": attempt.outcome.time_spent_seconds,
            "skill_unlocked_title": attempt.outcome.skill_unlocked_title,
            "crown_level": attempt.outcome.crown_level,
            "crown_leveled_up": attempt.outcome.crown_leveled_up,
            "streak_freeze_unlocked": attempt.outcome.streak_freeze_unlocked,
        }
        self._session.add(
            LessonAttemptModel(
                id=attempt.id,
                user_id=attempt.user_id,
                lesson_id=attempt.lesson_id,
                correct_count=attempt.correct_count,
                total_count=attempt.total_count,
                xp_awarded=attempt.xp_awarded,
                completed_at=attempt.completed_at,
                result=outcome_dict,
            )
        )

    async def sum_xp_by_user(self, user_id: str) -> int:
        stmt = select(func.sum(LessonAttemptModel.xp_awarded)).where(
            LessonAttemptModel.user_id == user_id
        )
        result = await self._session.execute(stmt)
        return result.scalar() or 0

    async def sum_xp_by_user_between(self, user_id: str, start: date, end: date) -> int:
        start_dt = datetime(start.year, start.month, start.day, tzinfo=UTC)
        end_dt = datetime(end.year, end.month, end.day, tzinfo=UTC)
        stmt = select(func.sum(LessonAttemptModel.xp_awarded)).where(
            LessonAttemptModel.user_id == user_id,
            LessonAttemptModel.completed_at >= start_dt,
            LessonAttemptModel.completed_at < end_dt,
        )
        result = await self._session.execute(stmt)
        return result.scalar() or 0
