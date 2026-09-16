"""Aggregate roots for the lesson-content domain.

Pure Python only -- no framework/DB imports, per the layering rule in
`ddd-02-technical-design.md`.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date, datetime

from app.domain.lesson.value_objects import (
    AnswerKey,
    ExerciseContent,
    ExerciseType,
    LessonCompletionOutcome,
)


@dataclass
class Exercise:
    """Member of the `Lesson` aggregate (not its own aggregate root).

    `answer_key` exists on every exercise but is a server-side-only concern
    -- nothing in the presentation layer ever serializes it back to an API
    caller (ADR-4).
    """

    id: str
    lesson_id: str
    order_index: int
    type: ExerciseType
    prompt: str
    content: ExerciseContent
    answer_key: AnswerKey


@dataclass
class Lesson:
    """Aggregate Root. Invariants:

    1. `order_index` is unique within `skill_id` (enforced by
       repositories/DB constraint, not this entity).
    2. Always loaded and returned with its full, ordered `exercises` list --
       there is no valid partial state where a `Lesson` exists without its
       exercises, matching the "no per-exercise round trip" NFR at the
       aggregate-boundary level.
    """

    id: str
    skill_id: str
    title: str
    order_index: int
    exercises: list[Exercise] = field(default_factory=list)


@dataclass
class Skill:
    """Aggregate Root. Invariants:

    1. `order_index` is globally unique across all skills.
    2. Has no awareness of any specific user -- per-user state lives
       entirely in the separate `UserSkillProgress` aggregate.
    """

    id: str
    title: str
    order_index: int


@dataclass
class UserSkillProgress:
    """Aggregate Root, independent of `Skill`'s transactional boundary
    (same pattern as `001-auth-service`'s `AuthSession` relative to `User`).

    Invariants:

    1. At most one row per `(user_id, skill_id)` pair.
    2. `crown_level > 0` implies `completed_at is not None`.

    `completed_lesson_ids_this_cycle` (bolt `005`) tracks progress toward
    the *current* full-skill pass -- the set of this skill's lesson ids the
    user has completed since the last crown-level milestone. When it grows
    to cover every lesson in the skill, that pass is done: the first time
    this happens `completed_at` is set and `crown_level` becomes 1 (skill
    unlock trigger); every subsequent time, `crown_level` increments
    (capped at `MAX_CROWN_LEVEL`) -- FR-6's "replay all lessons again to
    raise the crown level" rule. The set then resets to empty for the next
    pass. Bolt `004` only ever read this aggregate; bolt `005` is its first
    writer.
    """

    user_id: str
    skill_id: str
    unlocked: bool
    crown_level: int
    completed_at: datetime | None
    completed_lesson_ids_this_cycle: frozenset[str] = field(default_factory=frozenset)


@dataclass
class UserBeans:
    """Aggregate Root. Per-user Beans + Amole wallet state.

    Invariants: `0 <= current_count <= BEANS_MAX`; at most one row per
    `user_id`. A user with no row is a valid default state (full beans,
    `STARTING_AMOLE_BALANCE` Amole, no regen owed) -- same "absence is
    meaningful" pattern as `UserSkillProgress`.
    """

    user_id: str
    current_count: int
    last_regen_at: datetime
    amole_balance: int


@dataclass
class UserStreak:
    """Aggregate Root. Per-user daily-streak state.

    Invariants: `current_streak >= 0`; `active_freeze_count >= 0`; at most
    one row per `user_id`. No row is a valid default state (streak 0, no
    freeze, no completion yet).
    """

    user_id: str
    current_streak: int
    last_completed_date: date | None
    active_freeze_count: int


@dataclass
class LessonAttempt:
    """Aggregate Root. One completed lesson attempt.

    Invariants: `id` (client-generated, see Technical Design's Decision 2)
    is globally unique -- it is the idempotency key for story 003's
    "exactly once" requirement; `correct_count <= total_count`; every field
    is fixed forever once written (a repeat `get(id)` for the same attempt
    must return byte-for-byte the same result it originally computed, never
    recomputed from current state).
    """

    id: str
    user_id: str
    lesson_id: str
    correct_count: int
    total_count: int
    xp_awarded: int
    completed_at: datetime
    outcome: LessonCompletionOutcome
