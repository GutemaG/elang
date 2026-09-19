"""Pydantic request/response schemas for the course endpoints (bolt
`024-courses-service`, ADR-12).
"""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel


class CourseInfoResponse(BaseModel):
    """A course as embedded in other responses (e.g. the skill tree)."""

    id: str
    learning_language: str
    from_language: str
    title: str


class CourseResponse(BaseModel):
    id: str
    learning_language: str
    from_language: str
    title: str
    status: Literal["available", "coming_soon"]
    order_index: int
    is_active: bool
    completed_skills: int
    total_skills: int


class CourseListResponse(BaseModel):
    active_course_id: str
    courses: list[CourseResponse]


class ActivateCourseRequest(BaseModel):
    course_id: str


class ActivateCourseResponse(BaseModel):
    active_course_id: str
    selected_language: str
    course: CourseInfoResponse
