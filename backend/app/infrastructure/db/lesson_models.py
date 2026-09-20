"""SQLAlchemy async models mapping the `skills`, `lessons`, `exercises`, and
`user_skill_progress` tables.

Column definitions mirror `database-schema.md` at the repo root (source of
truth). Uses the same `Base` as the existing auth models
(`app/infrastructure/db/models.py`) so both bounded contexts' tables live in
one Alembic-managed metadata, per `ddd-02-technical-design.md`'s note that
`db/` stays a shared top-level folder (not bounded-context-namespaced).
"""

from __future__ import annotations

import uuid
from datetime import UTC, date, datetime

from sqlalchemy import (
    JSON,
    CheckConstraint,
    Date,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.infrastructure.db.models import Base


def _utcnow() -> datetime:
    return datetime.now(UTC)


def _uuid_str() -> str:
    return str(uuid.uuid4())


class CourseModel(Base):
    """Backs the `Course` aggregate (bolt `024-courses-service`, ADR-12): a
    learning language taught from a given from-language, e.g. English to
    Amharic. Content only -- no per-user state.
    """

    __tablename__ = "courses"
    __table_args__ = (
        UniqueConstraint("learning_language", "from_language", name="uq_courses_language_pair"),
        UniqueConstraint("order_index", name="uq_courses_order_index"),
        CheckConstraint("status IN ('available', 'coming_soon')", name="ck_courses_status"),
        CheckConstraint("learning_language <> from_language", name="ck_courses_languages_differ"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid_str)
    learning_language: Mapped[str] = mapped_column(String(8), nullable=False)
    from_language: Mapped[str] = mapped_column(String(8), nullable=False)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    status: Mapped[str] = mapped_column(String(16), nullable=False)
    order_index: Mapped[int] = mapped_column(Integer, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )


class CategoryModel(Base):
    """Backs the `Category` aggregate (bolt `021-categories-service`,
    ADR-11): a named group of skills, e.g. "Family & People". Belongs to one
    course (bolt 024, ADR-12); its `order_index` is its position in it.
    """

    __tablename__ = "categories"
    __table_args__ = (
        UniqueConstraint("course_id", "order_index", name="uq_categories_course_order_index"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid_str)
    course_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("courses.id"), nullable=False, index=True
    )
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    subtitle: Mapped[str] = mapped_column(String(255), nullable=False)
    order_index: Mapped[int] = mapped_column(Integer, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )


class SkillModel(Base):
    """Backs the `Skill` aggregate. A node on its category's linear skill
    path; `order_index` is its position within that category (ADR-11).
    """

    __tablename__ = "skills"
    __table_args__ = (
        UniqueConstraint("category_id", "order_index", name="uq_skills_category_order_index"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid_str)
    category_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("categories.id"), nullable=False, index=True
    )
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    order_index: Mapped[int] = mapped_column(Integer, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )

    lessons: Mapped[list[LessonModel]] = relationship(
        back_populates="skill", order_by="LessonModel.order_index"
    )


class LessonModel(Base):
    """Backs the `Lesson` aggregate, including its ordered `exercises`."""

    __tablename__ = "lessons"
    __table_args__ = (
        UniqueConstraint("skill_id", "order_index", name="uq_lessons_skill_order"),
        Index("ix_lessons_skill_id", "skill_id"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid_str)
    skill_id: Mapped[str] = mapped_column(String(36), ForeignKey("skills.id"), nullable=False)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    order_index: Mapped[int] = mapped_column(Integer, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )
    # Bolt 008: drives this lesson's `content_version` signal (offline
    # staleness check, FR-1 of 003-offline-caching-and-sync) -- bumped
    # automatically by the seed script's idempotent in-place updates.
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow, onupdate=_utcnow
    )

    skill: Mapped[SkillModel] = relationship(back_populates="lessons")
    exercises: Mapped[list[ExerciseModel]] = relationship(
        back_populates="lesson", order_by="ExerciseModel.order_index"
    )


class ExerciseModel(Base):
    """Backs the `Exercise` entity (member of the `Lesson` aggregate).

    Single polymorphic table with JSON `content`/`answer_key` columns per
    ADR-3. `answer_key` is now included in the lesson-content API response
    (ADR-5, superseding ADR-4 -- grading is client-side).

    `ck_exercises_type` was widened from 3 to 4 values by
    `011-match-pairs-service` (migration `c726efa81972`) to add
    `match_pairs`, from 4 to 5 by `030-gap-fill-service` (migration
    `d1b7e4f2a903`) to add `gap_fill`, and from 5 to 6 by
    `032-spell-tiles-service` (migration `f4c2a81e7b56`) to add
    `spell_tiles` -- see any of those migrations for why a batch-mode
    `ALTER` is required (SQLite cannot modify a `CHECK` constraint in
    place).

    Note the constraint is declared twice: here, and in the migration.
    Widening one without the other leaves the ORM and the database
    disagreeing about what is allowed.
    """

    __tablename__ = "exercises"
    __table_args__ = (
        UniqueConstraint("lesson_id", "order_index", name="uq_exercises_lesson_order"),
        CheckConstraint(
            "type IN ('multiple_choice', 'listening', 'sentence_construction', "
            "'match_pairs', 'gap_fill', 'spell_tiles')",
            name="ck_exercises_type",
        ),
        Index("ix_exercises_lesson_id", "lesson_id"),
        Index("ix_exercises_vocab_item_id", "vocab_item_id"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid_str)
    lesson_id: Mapped[str] = mapped_column(String(36), ForeignKey("lessons.id"), nullable=False)
    order_index: Mapped[int] = mapped_column(Integer, nullable=False)
    type: Mapped[str] = mapped_column(String(32), nullable=False)
    prompt: Mapped[str] = mapped_column(Text, nullable=False)
    content: Mapped[dict] = mapped_column(JSON, nullable=False)
    answer_key: Mapped[dict] = mapped_column(JSON, nullable=False)
    # Bolt 019 (008-srs-and-practice): not every exercise tests a specific
    # vocab item -- nullable, not required.
    vocab_item_id: Mapped[str | None] = mapped_column(
        String(36), ForeignKey("vocab_items.id"), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )
    # Bolt 008: contributes to the owning lesson's `content_version` signal
    # (see `LessonModel.updated_at`).
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow, onupdate=_utcnow
    )

    lesson: Mapped[LessonModel] = relationship(back_populates="exercises")


class UserSkillProgressModel(Base):
    """Backs the `UserSkillProgress` aggregate. Read-only in this bolt --
    all writes belong to `005-lesson-engagement-service`.
    """

    __tablename__ = "user_skill_progress"
    __table_args__ = (
        UniqueConstraint("user_id", "skill_id", name="uq_user_skill_progress_user_skill"),
        CheckConstraint(
            "crown_level >= 0 AND crown_level <= 5", name="ck_user_skill_progress_crown_level"
        ),
        Index("ix_user_skill_progress_user_id", "user_id"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid_str)
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), nullable=False)
    skill_id: Mapped[str] = mapped_column(String(36), ForeignKey("skills.id"), nullable=False)
    unlocked: Mapped[bool] = mapped_column(nullable=False, default=True)
    crown_level: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    # Lesson ids (within this skill) completed since the last crown-level
    # milestone -- bolt 005's FR-6 "replay all lessons again" tracking.
    # JSON, not a join table (ADR-3 precedent): never queried *inside*, only
    # read/written whole.
    completed_lesson_ids_this_cycle: Mapped[list[str]] = mapped_column(
        JSON, nullable=False, default=list
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )


class UserBeansModel(Base):
    """Backs the `UserBeans` aggregate (bolt 005). One row per user,
    created lazily on first write; absence = full beans.

    As of bolt `017-amole-service` (ADR-8), no longer carries Amole state --
    see `AmoleTransactionModel` below.
    """

    __tablename__ = "user_beans"
    __table_args__ = (
        CheckConstraint("current_count >= 0", name="ck_user_beans_current_count_non_negative"),
    )

    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), primary_key=True)
    current_count: Mapped[int] = mapped_column(Integer, nullable=False)
    last_regen_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )


class AmoleTransactionModel(Base):
    """Backs the `AmoleTransaction` aggregate (bolt `017-amole-service`,
    ADR-8). Append-only -- no code path ever updates or deletes a row.
    Balance is always `SUM(amount)`, computed by the repository, never
    stored here.
    """

    __tablename__ = "amole_transactions"
    __table_args__ = (
        UniqueConstraint("source", "reference_id", name="uq_amole_transactions_source_reference"),
        CheckConstraint(
            "source IN ('wallet_created', 'migration_backfill', 'lesson_completion', "
            "'perfect_lesson', 'streak_milestone_7', 'streak_milestone_30', 'bean_refill', "
            "'practice_session')",
            name="ck_amole_transactions_source",
        ),
        Index("ix_amole_transactions_user_id", "user_id"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid_str)
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), nullable=False)
    amount: Mapped[int] = mapped_column(Integer, nullable=False)
    source: Mapped[str] = mapped_column(String(32), nullable=False)
    reference_id: Mapped[str] = mapped_column(String(64), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )


class UserStreakModel(Base):
    """Backs the `UserStreak` aggregate (bolt 005). One row per user,
    created lazily on first lesson completion; absence = streak 0.
    """

    __tablename__ = "user_streaks"
    __table_args__ = (
        CheckConstraint("current_streak >= 0", name="ck_user_streaks_current_streak_non_negative"),
        CheckConstraint(
            "active_freeze_count >= 0", name="ck_user_streaks_active_freeze_count_non_negative"
        ),
    )

    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), primary_key=True)
    current_streak: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    last_completed_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    active_freeze_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )


class LessonAttemptModel(Base):
    """Backs the `LessonAttempt` aggregate (bolt 005). `id` is
    client-supplied (the idempotency key, story 003) -- never a
    server-generated default.
    """

    __tablename__ = "lesson_attempts"
    __table_args__ = (
        CheckConstraint(
            "correct_count >= 0 AND correct_count <= total_count",
            name="ck_lesson_attempts_correct_le_total",
        ),
        Index("ix_lesson_attempts_user_completed", "user_id", "completed_at"),
    )

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), nullable=False)
    lesson_id: Mapped[str] = mapped_column(String(36), ForeignKey("lessons.id"), nullable=False)
    correct_count: Mapped[int] = mapped_column(Integer, nullable=False)
    total_count: Mapped[int] = mapped_column(Integer, nullable=False)
    xp_awarded: Mapped[int] = mapped_column(Integer, nullable=False)
    completed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    # The rest of `LessonCompletionOutcome` (skill_unlocked_title,
    # crown_level, streak fields, accuracy) -- replayed verbatim on an
    # idempotent retry rather than recomputed, since "what was true at
    # completion time" is what a retry must see again, not "what's true
    # now" (which could have drifted, e.g. today's running XP total).
    result: Mapped[dict] = mapped_column(JSON, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )


class VocabItemModel(Base):
    """Backs the `VocabItem` aggregate (bolt `019-srs-tracking-service`).
    Content only -- no per-user state.
    """

    __tablename__ = "vocab_items"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid_str)
    # Bolt 024 (ADR-12): the course this word is taught in; Practice filters
    # due words by it.
    course_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("courses.id"), nullable=False, index=True
    )
    word: Mapped[str] = mapped_column(String(255), nullable=False)
    translation: Mapped[str] = mapped_column(String(255), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )


class UserVocabProgressModel(Base):
    """Backs the `UserVocabProgress` aggregate (bolt
    `019-srs-tracking-service`). Composite primary key enforces "at most one
    row per `(user_id, vocab_item_id)`" at the DB layer, same style as
    `user_skill_progress`'s `UniqueConstraint`.
    """

    __tablename__ = "user_vocab_progress"
    __table_args__ = (
        CheckConstraint(
            "box_level >= 1 AND box_level <= 5", name="ck_user_vocab_progress_box_level"
        ),
        Index("ix_user_vocab_progress_user_next_review", "user_id", "next_review_at"),
    )

    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), primary_key=True)
    vocab_item_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("vocab_items.id"), primary_key=True
    )
    box_level: Mapped[int] = mapped_column(Integer, nullable=False)
    next_review_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    last_seen_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)


class PracticeAttemptModel(Base):
    """Backs the `PracticeAttempt` aggregate (bolt `020-practice-ui`). `id`
    is client-supplied (the idempotency key), same convention as
    `LessonAttemptModel`. No `lesson_id`/`skill_id` -- a Practice session
    spans arbitrary lessons/skills, so there is nothing single to anchor to.
    """

    __tablename__ = "practice_attempts"
    __table_args__ = (
        CheckConstraint(
            "correct_count >= 0 AND correct_count <= total_count",
            name="ck_practice_attempts_correct_le_total",
        ),
        Index("ix_practice_attempts_user_completed", "user_id", "completed_at"),
    )

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), nullable=False)
    correct_count: Mapped[int] = mapped_column(Integer, nullable=False)
    total_count: Mapped[int] = mapped_column(Integer, nullable=False)
    xp_awarded: Mapped[int] = mapped_column(Integer, nullable=False)
    amole_awarded: Mapped[int] = mapped_column(Integer, nullable=False)
    completed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )
