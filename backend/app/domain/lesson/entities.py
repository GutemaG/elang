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
    # Bolt 019 (008-srs-and-practice): not every exercise tests a specific
    # vocab item, so this is nullable, not required -- `None` means this
    # exercise has no SRS tracking at all, not "not yet linked."
    vocab_item_id: str | None = None


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
class Category:
    """Aggregate Root (bolt `021-categories-service`, ADR-11): a named group
    of related skills, e.g. "Family & People". Content only -- no per-user
    state. It does not *contain* its skills; each `Skill` references it by
    `category_id`, so `Skill`/`Lesson`/`Exercise` aggregates are unaffected.
    """

    id: str
    title: str
    subtitle: str
    order_index: int
    # Bolt 024 (ADR-12): every category belongs to exactly one course, and its
    # `order_index` is its position inside that course.
    course_id: str


@dataclass
class Skill:
    """Aggregate Root. Invariants:

    1. `order_index` is unique within its category (ADR-11) -- it is the
       skill's position inside that category's path, not a global position.
    2. Belongs to exactly one category (`category_id`).
    3. Has no awareness of any specific user -- per-user state lives
       entirely in the separate `UserSkillProgress` aggregate.
    """

    id: str
    title: str
    order_index: int
    category_id: str


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
    """Aggregate Root. Per-user Beans wallet state.

    Invariants: `0 <= current_count <= BEANS_MAX`; at most one row per
    `user_id`. A user with no row is a valid default state (full beans, no
    regen owed) -- same "absence is meaningful" pattern as
    `UserSkillProgress`.

    As of bolt `017-amole-service` (ADR-8), this aggregate no longer holds
    Amole state -- `amole_balance` moved to the `AmoleTransaction` ledger
    below. Beans and Amole are now two independent concerns that happened
    to share a row purely as an implementation detail of bolt `005`.
    """

    user_id: str
    current_count: int
    last_regen_at: datetime


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
class AmoleTransaction:
    """Aggregate Root (bolt `017-amole-service`, ADR-8). One append-only
    ledger row -- a trivial aggregate boundary, since nothing ever needs to
    load "all of a user's transactions" as one consistency unit; balance is
    always `SUM(amount)`, a repository query, never this entity's state.

    Invariants: immutable once created (no update/delete operation exists
    anywhere in this codebase for it); `(source, reference_id)` is unique
    per row -- the idempotency mechanism for every writer (awards and
    spends alike).
    """

    id: str
    user_id: str
    amount: int
    source: str
    reference_id: str
    created_at: datetime


@dataclass
class VocabItem:
    """Aggregate Root (bolt `019-srs-tracking-service`). Content only -- no
    per-user state, same category as `Skill`/`Lesson`.
    """

    id: str
    word: str
    translation: str
    created_at: datetime
    # Bolt 024 (ADR-12): a vocab item is the answer to one question in one
    # direction, so it belongs to exactly one course.
    course_id: str


@dataclass
class UserVocabProgress:
    """Aggregate Root (bolt `019-srs-tracking-service`). Per-user Leitner
    spacing state for one vocab item.

    Invariants: `1 <= box_level <= 5`; at most one row per
    `(user_id, vocab_item_id)` pair -- same "one row per user per X"
    wallet-like shape as `UserSkillProgress`/`UserBeans`, deliberately not a
    ledger (ADR-8's reasoning doesn't apply here: single writer per update,
    no audit-trail requirement).
    """

    user_id: str
    vocab_item_id: str
    box_level: int
    next_review_at: datetime
    last_seen_at: datetime


@dataclass
class PracticeAttempt:
    """Aggregate Root (bolt `020-practice-ui`). One completed Practice
    session -- structurally similar to `LessonAttempt` (client-supplied
    `id` is the idempotency key) but its own table, since a Practice
    session spans arbitrary vocab items/exercises across lessons and skills
    and has no `lesson_id`/`skill_id` to anchor to.

    Invariants: `id` is globally unique (idempotency key); `correct_count
    <= total_count`; every field is fixed forever once written, same as
    `LessonAttempt`.
    """

    id: str
    user_id: str
    correct_count: int
    total_count: int
    xp_awarded: int
    amole_awarded: int
    completed_at: datetime


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
