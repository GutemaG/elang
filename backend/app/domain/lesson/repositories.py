"""Repository interfaces (contracts), as `typing.Protocol`s.

Implemented by `app/infrastructure/db/lesson_repositories.py`. The domain
layer only depends on these Protocols, never on SQLAlchemy directly.
"""

from __future__ import annotations

from collections.abc import Sequence
from datetime import date, datetime
from typing import Protocol

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


class SkillRepository(Protocol):
    """Entity: `Skill`."""

    async def list_all(self) -> list[Skill]: ...


class CategoryRepository(Protocol):
    """Entity: `Category` (bolt `021-categories-service`)."""

    async def list_all(self) -> list[Category]:
        """Every category, ordered by `order_index`."""
        ...

    async def list_by_course(self, course_id: str) -> list[Category]:
        """The categories of one course (bolt `024-courses-service`), ordered
        by `order_index`.
        """
        ...


class LessonRepository(Protocol):
    """Entity: `Lesson` (aggregate includes its ordered `Exercise` list)."""

    async def get_by_id(self, lesson_id: str) -> Lesson | None: ...

    async def list_lesson_ids_by_skill(self, skill_id: str) -> tuple[str, ...]:
        """Every lesson id belonging to `skill_id`, ordered by
        `order_index` -- a lightweight query (ids only, no exercises
        loaded) used by `LessonCompletionService` (as a set, via
        `frozenset(...)` at the call site) to check whether a full pass
        through the skill is complete. Does not return the `Lesson`
        aggregate itself (which is always whole, including exercises) --
        this is deliberately not that.
        """
        ...

    async def get_content_version(self, lesson_id: str) -> datetime | None:
        """The most recent `updated_at` across this lesson's own row and
        all its exercises (bolt 008) -- a stable, comparable signal a
        client can check against its cached copy to decide whether a
        re-download is needed (FR-1 of `003-offline-caching-and-sync`).
        `None` only for an unknown `lesson_id`.
        """
        ...

    async def list_content_versions_by_skills(
        self, skill_ids: Sequence[str]
    ) -> dict[str, datetime]:
        """The same signal as `get_content_version`, but the most recent
        `updated_at` across each skill's *own* lessons and exercises, for
        every skill in `skill_ids` in one round trip -- same N+1-avoidance
        discipline as `list_lesson_ids_by_skills`. A skill with no lessons
        is simply absent from the result dict.
        """
        ...

    async def list_lesson_ids_by_skills(
        self, skill_ids: Sequence[str]
    ) -> dict[str, tuple[str, ...]]:
        """The same ordered-lesson-ids-per-skill data as
        `list_lesson_ids_by_skill`, but for every skill in `skill_ids` in
        one query -- used by `get_skill_tree` (bolt 007) to compute each
        skill's "next lesson to work on" without a per-skill round trip
        (the skill-tree query-count NFR bolt 004 established still applies
        here). A skill with no lessons is simply absent from the result
        dict, not a `KeyError`.
        """
        ...

    async def list_exercises_by_vocab_item_ids(
        self, vocab_item_ids: Sequence[str]
    ) -> dict[str, Exercise]:
        """Bolt 019/020: resolves each vocab item in `vocab_item_ids` to one
        full `Exercise` that tests it, for the due-items response (story
        `004-due-items-and-count-endpoints`). A vocab item may be tested by
        more than one exercise across different lessons -- this returns an
        arbitrary but deterministic one, not all of them. A vocab item with
        no linked exercise (shouldn't happen with real content) is simply
        absent from the result dict.

        Bolt 020 widened this from returning a bare exercise id to the full
        `Exercise` (content + answer key) -- `GET /lessons/{lesson_id}`
        can't be used to fetch it separately, since that endpoint's
        `LessonAccessPolicy` check would 403 a locked skill's lesson, which
        Practice must not be blocked by (story `002`'s edge case).

        Domain Model originally called this an amendment to a standalone
        `ExerciseRepository` -- reading the real repository layer at this
        stage showed no such Protocol exists (`Exercise` is only ever
        accessed as a member of the `Lesson` aggregate), so this lives on
        `LessonRepository` instead, corrected here rather than in Stage 1-2
        (which are source-reading-restricted).
        """
        ...


class UserSkillProgressRepository(Protocol):
    """Entity: `UserSkillProgress`."""

    async def list_by_user(self, user_id: str) -> list[UserSkillProgress]: ...

    async def get(self, user_id: str, skill_id: str) -> UserSkillProgress | None: ...

    async def upsert(self, progress: UserSkillProgress) -> None: ...


class UserBeansRepository(Protocol):
    """Entity: `UserBeans`."""

    async def get(self, user_id: str) -> UserBeans | None: ...

    async def upsert(self, beans: UserBeans) -> None: ...


class AmoleTransactionRepository(Protocol):
    """Entity: `AmoleTransaction` (bolt `017-amole-service`, ADR-8).
    Append-only -- no update/delete method exists by design.
    """

    async def add_if_new(self, transaction: AmoleTransaction) -> None:
        """Inserts unless a row for `(source, reference_id)` already
        exists, in which case this is a no-op -- the idempotency mechanism
        for every ledger writer (awards and, per ADR-9, best-effort for
        spends).
        """
        ...

    async def sum_by_user(self, user_id: str) -> int:
        """The account's Amole balance -- always computed, never cached."""
        ...


class UserStreakRepository(Protocol):
    """Entity: `UserStreak`."""

    async def get(self, user_id: str) -> UserStreak | None: ...

    async def upsert(self, streak: UserStreak) -> None: ...


class VocabItemRepository(Protocol):
    """Entity: `VocabItem` (bolt `019-srs-tracking-service`)."""

    async def get_by_id(self, vocab_item_id: str) -> VocabItem | None: ...

    async def list_by_ids(self, vocab_item_ids: Sequence[str]) -> list[VocabItem]:
        """Every `VocabItem` in `vocab_item_ids` found, in no particular
        order -- for resolving the due-items response's word/translation
        content in one round trip, not one per item.
        """
        ...


class UserVocabProgressRepository(Protocol):
    """Entity: `UserVocabProgress` (bolt `019-srs-tracking-service`)."""

    async def get(self, user_id: str, vocab_item_id: str) -> UserVocabProgress | None: ...

    async def upsert(self, progress: UserVocabProgress) -> None: ...

    async def list_due(
        self, user_id: str, now: datetime, limit: int, course_id: str | None = None
    ) -> list[UserVocabProgress]:
        """`WHERE user_id = ? AND next_review_at <= now ORDER BY
        next_review_at LIMIT limit` -- shares its predicate with
        `count_due` (FR-4) so the two can never disagree. Bolt 024
        (ADR-12): when `course_id` is given, only words belonging to that
        course; `None` means unscoped (used by unit tests, never by the
        HTTP routers, which always pass the active course).
        """
        ...

    async def count_due(self, user_id: str, now: datetime, course_id: str | None = None) -> int:
        """The same predicate as `list_due`, without the `LIMIT`."""
        ...


class PracticeAttemptRepository(Protocol):
    """Entity: `PracticeAttempt` (bolt `020-practice-ui`). `id` is the
    idempotency key (client-supplied), same convention as
    `LessonAttemptRepository`.
    """

    async def get(self, session_id: str) -> PracticeAttempt | None: ...

    async def add(self, attempt: PracticeAttempt) -> None: ...


class LessonAttemptRepository(Protocol):
    """Entity: `LessonAttempt`. `id` is the idempotency key (client-supplied,
    never server-generated).
    """

    async def get(self, attempt_id: str) -> LessonAttempt | None: ...

    async def add(self, attempt: LessonAttempt) -> None: ...

    async def sum_xp_by_user(self, user_id: str) -> int:
        """Lifetime XP total -- for the skill-tree HUD's `total_xp`."""
        ...

    async def sum_xp_by_user_between(self, user_id: str, start: date, end: date) -> int:
        """XP total for attempts with `completed_at` in `[start, end)`
        (UTC calendar-day boundaries) -- for `daily_xp_total`.
        """
        ...
