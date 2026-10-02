"""Pydantic request/response schemas for the course endpoints (bolt
`024-courses-service`, ADR-12).
"""

from __future__ import annotations

from collections.abc import Iterable
from typing import Literal

from pydantic import BaseModel

from app.domain.course import Course, Language


def language_names(course: Course, languages: Iterable[Language]) -> dict[str, str]:
    """The four name fields every course shape carries, so the app can name a
    language added in the admin site without an update. A code with no
    `languages` row is named by the code itself.
    """
    known = {language.code: language for language in languages}

    def names(code: str) -> tuple[str, str]:
        language = known.get(code)
        return (language.name, language.native_name) if language else (code, code)

    learning, learning_native = names(course.learning_language)
    from_, from_native = names(course.from_language)
    return {
        "learning_language_name": learning,
        "learning_language_native_name": learning_native,
        "from_language_name": from_,
        "from_language_native_name": from_native,
    }


class CourseInfoResponse(BaseModel):
    """A course as embedded in other responses (e.g. the skill tree)."""

    id: str
    learning_language: str
    from_language: str
    title: str
    learning_language_name: str
    learning_language_native_name: str
    from_language_name: str
    from_language_native_name: str


class CourseResponse(BaseModel):
    id: str
    learning_language: str
    from_language: str
    title: str
    learning_language_name: str
    learning_language_native_name: str
    from_language_name: str
    from_language_native_name: str
    status: Literal["available", "coming_soon"]
    order_index: int
    is_active: bool
    completed_skills: int
    total_skills: int


class CatalogCourseResponse(BaseModel):
    """A course as shown before sign-in (onboarding): no per-user fields."""

    id: str
    learning_language: str
    from_language: str
    title: str
    learning_language_name: str
    learning_language_native_name: str
    from_language_name: str
    from_language_native_name: str
    status: Literal["available", "coming_soon"]
    order_index: int


class CatalogResponse(BaseModel):
    courses: list[CatalogCourseResponse]


class CourseListResponse(BaseModel):
    active_course_id: str
    courses: list[CourseResponse]


class ActivateCourseRequest(BaseModel):
    course_id: str


class ActivateCourseResponse(BaseModel):
    active_course_id: str
    selected_language: str
    course: CourseInfoResponse
