"""Repository interfaces (contracts), as `typing.Protocol`s.

Implemented by `app/infrastructure/db/lesson_repositories.py`. The domain
layer only depends on these Protocols, never on SQLAlchemy directly.
"""

from __future__ import annotations

from collections.abc import Sequence
from datetime import date, datetime
from typing import Protocol

from app.domain.lesson.entities import (
    Lesson,
    LessonAttempt,
    Skill,
    UserBeans,
    UserSkillProgress,
    UserStreak,
)


class SkillRepository(Protocol):
    """Entity: `Skill`."""

    async def list_all(self) -> list[Skill]: ...


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


class UserSkillProgressRepository(Protocol):
    """Entity: `UserSkillProgress`."""

    async def list_by_user(self, user_id: str) -> list[UserSkillProgress]: ...

    async def get(self, user_id: str, skill_id: str) -> UserSkillProgress | None: ...

    async def upsert(self, progress: UserSkillProgress) -> None: ...


class UserBeansRepository(Protocol):
    """Entity: `UserBeans`."""

    async def get(self, user_id: str) -> UserBeans | None: ...

    async def upsert(self, beans: UserBeans) -> None: ...


class UserStreakRepository(Protocol):
    """Entity: `UserStreak`."""

    async def get(self, user_id: str) -> UserStreak | None: ...

    async def upsert(self, streak: UserStreak) -> None: ...


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
