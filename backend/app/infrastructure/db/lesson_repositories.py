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

from app.domain.course import Course, CourseStatus
from app.domain.lesson.entities import (
    AmoleTransaction,
    Category,
    Exercise,
    Lesson,
    LessonAttempt,
    PracticeAttempt,
    Skill,
    UserBeans,
    UserSkillProgress,
    UserStreak,
    UserVocabProgress,
    VocabItem,
)
from app.domain.lesson.value_objects import (
    AnswerKey,
    ChoiceAnswerKey,
    ExerciseContent,
    ExerciseType,
    GapFillContent,
    LessonCompletionOutcome,
    ListeningContent,
    MatchPairsContent,
    MultipleChoiceContent,
    PairAnswerKey,
    SentenceConstructionContent,
    SequenceAnswerKey,
    SpellTilesContent,
)
from app.domain.lesson.value_objects import Choice as ChoiceVO
from app.infrastructure.db.lesson_models import (
    AmoleTransactionModel,
    CategoryModel,
    CourseModel,
    ExerciseModel,
    LessonAttemptModel,
    LessonModel,
    PracticeAttemptModel,
    SkillModel,
    UserBeansModel,
    UserSkillProgressModel,
    UserStreakModel,
    UserVocabProgressModel,
    VocabItemModel,
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
    if exercise_type is ExerciseType.SENTENCE_CONSTRUCTION:
        return SentenceConstructionContent(word_bank=_choices_from_json(content["word_bank"]))
    if exercise_type is ExerciseType.MATCH_PAIRS:
        return MatchPairsContent(
            left_tiles=_choices_from_json(content["left_tiles"]),
            right_tiles=_choices_from_json(content["right_tiles"]),
        )
    # Every type is now tested explicitly. Until bolt 030 the match-pairs
    # branch was the unguarded fall-through, which meant any type added
    # later was silently read as match-pairs and died on a missing
    # `left_tiles` key -- a confusing failure a long way from its cause.
    if exercise_type is ExerciseType.GAP_FILL:
        return GapFillContent(
            sentence_before=content["sentence_before"],
            sentence_after=content["sentence_after"],
            choices=_choices_from_json(content["choices"]),
        )
    if exercise_type is ExerciseType.SPELL_TILES:
        return SpellTilesContent(tiles=_choices_from_json(content["tiles"]))
    raise ValueError(f"No content mapping for exercise type {exercise_type}")


def _answer_key_from_json(exercise_type: ExerciseType, answer_key: dict[str, Any]) -> AnswerKey:
    if exercise_type in (ExerciseType.SENTENCE_CONSTRUCTION, ExerciseType.SPELL_TILES):
        return SequenceAnswerKey(correct_sequence=tuple(answer_key["correct_sequence"]))
    if exercise_type is ExerciseType.MATCH_PAIRS:
        return PairAnswerKey(
            correct_pairs=tuple(tuple(pair) for pair in answer_key["correct_pairs"])
        )
    # `multiple_choice`, `listening` and `gap_fill` all answer the same
    # question -- which one of these is right -- so they share
    # `ChoiceAnswerKey`.
    #
    # Note this is a fall-through, not an explicit list, which makes it the
    # one place in this module where a new type is absorbed rather than
    # rejected. Bolt 030 needed no edit here because `gap_fill` genuinely
    # does answer with a choice id. Bolt 032 did: `spell_tiles` answers
    # with a sequence, and without being named above it would have fallen
    # through to here and died on a missing `correct_choice_id` -- the
    # exact trap the previous wording warned about. Any future type must
    # be checked against this, not assumed into it.
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
        vocab_item_id=model.vocab_item_id,
    )


def _skill_model_to_domain(model: SkillModel) -> Skill:
    return Skill(
        id=model.id,
        title=model.title,
        order_index=model.order_index,
        category_id=model.category_id,
    )


def _category_model_to_domain(model: CategoryModel) -> Category:
    return Category(
        id=model.id,
        title=model.title,
        subtitle=model.subtitle,
        order_index=model.order_index,
        course_id=model.course_id,
    )


def _course_model_to_domain(model: CourseModel) -> Course:
    return Course(
        id=model.id,
        learning_language=model.learning_language,
        from_language=model.from_language,
        title=model.title,
        status=CourseStatus(model.status),
        order_index=model.order_index,
    )


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
    )


def _streak_model_to_domain(model: UserStreakModel) -> UserStreak:
    return UserStreak(
        user_id=model.user_id,
        current_streak=model.current_streak,
        last_completed_date=model.last_completed_date,
        active_freeze_count=model.active_freeze_count,
    )


def _vocab_item_model_to_domain(model: VocabItemModel) -> VocabItem:
    return VocabItem(
        id=model.id,
        word=model.word,
        translation=model.translation,
        created_at=_ensure_utc(model.created_at),
        course_id=model.course_id,
    )


def _vocab_progress_model_to_domain(model: UserVocabProgressModel) -> UserVocabProgress:
    return UserVocabProgress(
        user_id=model.user_id,
        vocab_item_id=model.vocab_item_id,
        box_level=model.box_level,
        next_review_at=_ensure_utc(model.next_review_at),
        last_seen_at=_ensure_utc(model.last_seen_at),
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
        stmt = select(SkillModel).order_by(SkillModel.category_id, SkillModel.order_index)
        result = await self._session.execute(stmt)
        return [_skill_model_to_domain(m) for m in result.scalars().all()]


class SqlAlchemyCategoryRepository:
    """Implements `app.domain.lesson.repositories.CategoryRepository`."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def list_all(self) -> list[Category]:
        stmt = select(CategoryModel).order_by(CategoryModel.course_id, CategoryModel.order_index)
        result = await self._session.execute(stmt)
        return [_category_model_to_domain(m) for m in result.scalars().all()]

    async def list_by_course(self, course_id: str) -> list[Category]:
        stmt = (
            select(CategoryModel)
            .where(CategoryModel.course_id == course_id)
            .order_by(CategoryModel.order_index)
        )
        result = await self._session.execute(stmt)
        return [_category_model_to_domain(m) for m in result.scalars().all()]


class SqlAlchemyCourseRepository:
    """Implements `app.domain.course.CourseRepository` (bolt
    `024-courses-service`, ADR-12).
    """

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def list_all(self) -> list[Course]:
        stmt = select(CourseModel).order_by(CourseModel.order_index)
        result = await self._session.execute(stmt)
        return [_course_model_to_domain(m) for m in result.scalars().all()]

    async def get_by_id(self, course_id: str) -> Course | None:
        model = await self._session.get(CourseModel, course_id)
        return _course_model_to_domain(model) if model is not None else None

    async def get_for_skill(self, skill_id: str) -> Course | None:
        stmt = (
            select(CourseModel)
            .join(CategoryModel, CategoryModel.course_id == CourseModel.id)
            .join(SkillModel, SkillModel.category_id == CategoryModel.id)
            .where(SkillModel.id == skill_id)
        )
        result = await self._session.execute(stmt)
        model = result.scalar_one_or_none()
        return _course_model_to_domain(model) if model is not None else None

    async def count_skills_by_course(self) -> dict[str, int]:
        stmt = (
            select(CategoryModel.course_id, func.count(SkillModel.id))
            .join(SkillModel, SkillModel.category_id == CategoryModel.id)
            .group_by(CategoryModel.course_id)
        )
        result = await self._session.execute(stmt)
        return {course_id: count for course_id, count in result.all()}

    async def count_completed_skills_by_course(self, user_id: str) -> dict[str, int]:
        stmt = (
            select(CategoryModel.course_id, func.count(UserSkillProgressModel.skill_id))
            .join(SkillModel, SkillModel.category_id == CategoryModel.id)
            .join(UserSkillProgressModel, UserSkillProgressModel.skill_id == SkillModel.id)
            .where(
                UserSkillProgressModel.user_id == user_id,
                UserSkillProgressModel.completed_at.is_not(None),
            )
            .group_by(CategoryModel.course_id)
        )
        result = await self._session.execute(stmt)
        return {course_id: count for course_id, count in result.all()}


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

    async def list_exercises_by_vocab_item_ids(
        self, vocab_item_ids: Sequence[str]
    ) -> dict[str, Exercise]:
        if not vocab_item_ids:
            return {}
        stmt = (
            select(ExerciseModel)
            .where(ExerciseModel.vocab_item_id.in_(vocab_item_ids))
            .order_by(ExerciseModel.vocab_item_id, ExerciseModel.id)
        )
        result = await self._session.execute(stmt)
        # First row per vocab_item_id wins (rows arrive ordered by exercise
        # id) -- deterministic, not "first inserted."
        resolved: dict[str, Exercise] = {}
        for model in result.scalars().all():
            resolved.setdefault(model.vocab_item_id, _exercise_model_to_domain(model))
        return resolved


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


class SqlAlchemyAmoleTransactionRepository:
    """Implements `app.domain.lesson.repositories.AmoleTransactionRepository`
    (bolt `017-amole-service`, ADR-8).

    `add_if_new` checks for an existing `(source, reference_id)` row before
    inserting rather than catching a DB-level `IntegrityError` -- same
    check-then-write style already used by every other `upsert` in this
    module, and the DB's own `UNIQUE` constraint still backstops a genuine
    race (this project doesn't guard `LessonAttemptRepository.add`'s
    equivalent race either, so this matches existing risk tolerance, not a
    new gap).
    """

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def add_if_new(self, transaction: AmoleTransaction) -> None:
        stmt = select(AmoleTransactionModel).where(
            AmoleTransactionModel.source == transaction.source,
            AmoleTransactionModel.reference_id == transaction.reference_id,
        )
        result = await self._session.execute(stmt)
        if result.scalar_one_or_none() is not None:
            return
        self._session.add(
            AmoleTransactionModel(
                id=transaction.id,
                user_id=transaction.user_id,
                amount=transaction.amount,
                source=transaction.source,
                reference_id=transaction.reference_id,
                created_at=transaction.created_at,
            )
        )
        # The session factory disables autoflush (`db/session.py`), and
        # callers routinely post a transaction then immediately read
        # `sum_by_user` back in the same request/session (e.g.
        # `get_amole_balance`, `refill_beans`) -- without this flush, that
        # read would not see the row just added until the request-ending
        # commit, undercounting the balance by exactly this transaction.
        await self._session.flush()

    async def sum_by_user(self, user_id: str) -> int:
        stmt = select(func.sum(AmoleTransactionModel.amount)).where(
            AmoleTransactionModel.user_id == user_id
        )
        result = await self._session.execute(stmt)
        return result.scalar() or 0


class SqlAlchemyVocabItemRepository:
    """Implements `app.domain.lesson.repositories.VocabItemRepository`
    (bolt `019-srs-tracking-service`)."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_by_id(self, vocab_item_id: str) -> VocabItem | None:
        stmt = select(VocabItemModel).where(VocabItemModel.id == vocab_item_id)
        result = await self._session.execute(stmt)
        model = result.scalar_one_or_none()
        return _vocab_item_model_to_domain(model) if model is not None else None

    async def list_by_ids(self, vocab_item_ids: Sequence[str]) -> list[VocabItem]:
        if not vocab_item_ids:
            return []
        stmt = select(VocabItemModel).where(VocabItemModel.id.in_(vocab_item_ids))
        result = await self._session.execute(stmt)
        return [_vocab_item_model_to_domain(m) for m in result.scalars().all()]


class SqlAlchemyUserVocabProgressRepository:
    """Implements `app.domain.lesson.repositories.UserVocabProgressRepository`
    (bolt `019-srs-tracking-service`). `upsert` follows the same
    fetch-then-insert-or-update convention as every other `upsert` in this
    module.
    """

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get(self, user_id: str, vocab_item_id: str) -> UserVocabProgress | None:
        stmt = select(UserVocabProgressModel).where(
            UserVocabProgressModel.user_id == user_id,
            UserVocabProgressModel.vocab_item_id == vocab_item_id,
        )
        result = await self._session.execute(stmt)
        model = result.scalar_one_or_none()
        return _vocab_progress_model_to_domain(model) if model is not None else None

    async def upsert(self, progress: UserVocabProgress) -> None:
        stmt = select(UserVocabProgressModel).where(
            UserVocabProgressModel.user_id == progress.user_id,
            UserVocabProgressModel.vocab_item_id == progress.vocab_item_id,
        )
        result = await self._session.execute(stmt)
        model = result.scalar_one_or_none()
        if model is None:
            model = UserVocabProgressModel(
                user_id=progress.user_id, vocab_item_id=progress.vocab_item_id
            )
            self._session.add(model)
        model.box_level = progress.box_level
        model.next_review_at = progress.next_review_at
        model.last_seen_at = progress.last_seen_at

    async def list_due(
        self, user_id: str, now: datetime, limit: int, course_id: str | None = None
    ) -> list[UserVocabProgress]:
        stmt = select(UserVocabProgressModel).where(
            UserVocabProgressModel.user_id == user_id,
            UserVocabProgressModel.next_review_at <= now,
        )
        if course_id is not None:
            stmt = stmt.join(
                VocabItemModel, VocabItemModel.id == UserVocabProgressModel.vocab_item_id
            ).where(VocabItemModel.course_id == course_id)
        stmt = stmt.order_by(UserVocabProgressModel.next_review_at).limit(limit)
        result = await self._session.execute(stmt)
        return [_vocab_progress_model_to_domain(m) for m in result.scalars().all()]

    async def count_due(self, user_id: str, now: datetime, course_id: str | None = None) -> int:
        stmt = select(func.count(UserVocabProgressModel.vocab_item_id)).where(
            UserVocabProgressModel.user_id == user_id,
            UserVocabProgressModel.next_review_at <= now,
        )
        if course_id is not None:
            stmt = stmt.join(
                VocabItemModel, VocabItemModel.id == UserVocabProgressModel.vocab_item_id
            ).where(VocabItemModel.course_id == course_id)
        result = await self._session.execute(stmt)
        return result.scalar() or 0


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
            "is_review": attempt.outcome.is_review,
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


def _practice_attempt_model_to_domain(model: PracticeAttemptModel) -> PracticeAttempt:
    return PracticeAttempt(
        id=model.id,
        user_id=model.user_id,
        correct_count=model.correct_count,
        total_count=model.total_count,
        xp_awarded=model.xp_awarded,
        amole_awarded=model.amole_awarded,
        completed_at=_ensure_utc(model.completed_at),
    )


class SqlAlchemyPracticeAttemptRepository:
    """Implements `app.domain.lesson.repositories.PracticeAttemptRepository`
    (bolt `020-practice-ui`). Same "id is the idempotency key, `add` never
    updates" convention as `SqlAlchemyLessonAttemptRepository`.
    """

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get(self, session_id: str) -> PracticeAttempt | None:
        stmt = select(PracticeAttemptModel).where(PracticeAttemptModel.id == session_id)
        result = await self._session.execute(stmt)
        model = result.scalar_one_or_none()
        return _practice_attempt_model_to_domain(model) if model is not None else None

    async def add(self, attempt: PracticeAttempt) -> None:
        self._session.add(
            PracticeAttemptModel(
                id=attempt.id,
                user_id=attempt.user_id,
                correct_count=attempt.correct_count,
                total_count=attempt.total_count,
                xp_awarded=attempt.xp_awarded,
                amole_awarded=attempt.amole_awarded,
                completed_at=attempt.completed_at,
            )
        )
