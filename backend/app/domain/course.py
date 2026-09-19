"""Course model shared by the auth/user and lesson-content bounded contexts
(bolt `024-courses-service`, ADR-12/ADR-13).

A course is a (learning language, from-language) pair, e.g. English to
Amharic, so an Amharic speaker can learn Afaan Oromo and the reverse. Pure
Python only -- no framework/DB imports.
"""

from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass
from enum import StrEnum
from typing import Protocol

from app.domain.exceptions import CourseNotAvailableError


class CourseStatus(StrEnum):
    """A course can be studied or selected only while `AVAILABLE`."""

    AVAILABLE = "available"
    COMING_SOON = "coming_soon"


@dataclass(frozen=True)
class LanguagePair:
    """The (learning, from) combination that identifies a course. Equality by
    value; the two languages must differ.
    """

    learning: str
    from_language: str

    def __post_init__(self) -> None:
        if self.learning == self.from_language:
            raise ValueError("A course's learning language and from-language must differ")


@dataclass(frozen=True)
class Course:
    """Aggregate Root. Content only -- no per-user state. Categories and
    vocab items reference it by `course_id`; it does not contain them.

    Invariants: the language pair is unique across courses (DB constraint),
    the two languages differ, and only an `AVAILABLE` course can be studied
    or selected.
    """

    id: str
    learning_language: str
    from_language: str
    title: str
    status: CourseStatus
    order_index: int

    @property
    def pair(self) -> LanguagePair:
        return LanguagePair(learning=self.learning_language, from_language=self.from_language)

    @property
    def is_available(self) -> bool:
        return self.status is CourseStatus.AVAILABLE


@dataclass(frozen=True)
class CourseSummary:
    """Read-side view of one course for the course list -- derived, never
    stored: `completed_skills` counts the user's completed skills in it.
    """

    course: Course
    is_active: bool
    completed_skills: int
    total_skills: int


class CourseSelectionPolicy:
    """Pure domain logic -- no external dependencies."""

    def can_activate(self, course: Course) -> bool:
        return course.is_available

    def ensure_activatable(self, course: Course) -> None:
        if not self.can_activate(course):
            raise CourseNotAvailableError(f"Course {course.title!r} is not available yet")

    def resolve_for_pair(self, pair: LanguagePair, courses: Sequence[Course]) -> Course | None:
        """The `AVAILABLE` course for `pair`, or `None` if there is none."""
        for course in courses:
            if course.is_available and course.pair == pair:
                return course
        return None

    def fallback_course(self, courses: Sequence[Course]) -> Course | None:
        """Deterministic fallback if a user's active course stops being
        available: the first available course by `order_index`.
        """
        available = sorted((c for c in courses if c.is_available), key=lambda c: c.order_index)
        return available[0] if available else None


class CourseRepository(Protocol):
    """Entity: `Course` (bolt `024-courses-service`)."""

    async def list_all(self) -> list[Course]:
        """Every course, ordered by `order_index`."""
        ...

    async def get_by_id(self, course_id: str) -> Course | None: ...

    async def get_for_skill(self, skill_id: str) -> Course | None:
        """The course a skill belongs to (skill to category to course), or
        `None` for an unknown skill.
        """
        ...

    async def count_skills_by_course(self) -> dict[str, int]:
        """Total skills per course id (a course with none is absent)."""
        ...

    async def count_completed_skills_by_course(self, user_id: str) -> dict[str, int]:
        """How many skills `user_id` has completed, per course id (a course
        with none is absent).
        """
        ...
