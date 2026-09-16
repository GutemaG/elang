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


class SkillModel(Base):
    """Backs the `Skill` aggregate. A node in the (currently linear)
    skill tree.
    """

    __tablename__ = "skills"
    __table_args__ = (UniqueConstraint("order_index", name="uq_skills_order_index"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid_str)
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
    ADR-3. `answer_key` is never read by the presentation layer's response
    schemas (ADR-4) -- only by this bolt's repository (which does not
    return it to the API) and, in a future bolt, by grading logic.
    """

    __tablename__ = "exercises"
    __table_args__ = (
        UniqueConstraint("lesson_id", "order_index", name="uq_exercises_lesson_order"),
        CheckConstraint(
            "type IN ('multiple_choice', 'listening', 'sentence_construction')",
            name="ck_exercises_type",
        ),
        Index("ix_exercises_lesson_id", "lesson_id"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid_str)
    lesson_id: Mapped[str] = mapped_column(String(36), ForeignKey("lessons.id"), nullable=False)
    order_index: Mapped[int] = mapped_column(Integer, nullable=False)
    type: Mapped[str] = mapped_column(String(32), nullable=False)
    prompt: Mapped[str] = mapped_column(Text, nullable=False)
    content: Mapped[dict] = mapped_column(JSON, nullable=False)
    answer_key: Mapped[dict] = mapped_column(JSON, nullable=False)
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
    created lazily on first write; absence = full beans + starting Amole.
    """

    __tablename__ = "user_beans"
    __table_args__ = (
        CheckConstraint("current_count >= 0", name="ck_user_beans_current_count_non_negative"),
        CheckConstraint("amole_balance >= 0", name="ck_user_beans_amole_balance_non_negative"),
    )

    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), primary_key=True)
    current_count: Mapped[int] = mapped_column(Integer, nullable=False)
    last_regen_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    amole_balance: Mapped[int] = mapped_column(Integer, nullable=False)
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
