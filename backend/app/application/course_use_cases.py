"""Application layer for courses (bolt `024-courses-service`, ADR-12/ADR-13):
listing every course for the picker and switching the user's active course.

No direct SQLAlchemy or HTTP imports -- the routers map requests/responses
and commit the transaction the injected repositories share.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass

from app.domain.course import Course, CourseRepository, CourseSummary
from app.domain.entities import User
from app.domain.exceptions import CourseNotFoundError
from app.domain.repositories import UserRepository
from app.domain.services import activate_course_for_user

logger = logging.getLogger("app.courses")


@dataclass(frozen=True)
class CourseListResult:
    active_course_id: str
    courses: list[CourseSummary]


async def list_courses(user: User, course_repo: CourseRepository) -> CourseListResult:
    """Every course (available and coming soon) in stable order, with whether
    it is the user's active course and their completed/total skill counts.
    Three queries regardless of how many courses exist.
    """
    courses = await course_repo.list_all()
    total_by_course = await course_repo.count_skills_by_course()
    completed_by_course = await course_repo.count_completed_skills_by_course(user.id)
    return CourseListResult(
        active_course_id=user.active_course_id,
        courses=[
            CourseSummary(
                course=course,
                is_active=course.id == user.active_course_id,
                completed_skills=completed_by_course.get(course.id, 0),
                total_skills=total_by_course.get(course.id, 0),
            )
            for course in courses
        ],
    )


async def activate_course(
    user: User, course_id: str, course_repo: CourseRepository, user_repo: UserRepository
) -> tuple[User, Course]:
    """Switches the user's active course. Raises `CourseNotFoundError` (404)
    for an unknown id and `CourseNotAvailableError` (422) for a course that
    is coming soon; the active course is unchanged on any error. Selecting
    the course that is already active succeeds with no change.
    """
    course = await course_repo.get_by_id(course_id)
    if course is None:
        raise CourseNotFoundError(f"No course found with id {course_id!r}")
    if course.id == user.active_course_id:
        return user, course
    updated = await user_repo.update(activate_course_for_user(user, course))
    logger.info("active_course_changed user_id=%s course_id=%s", updated.id, course.id)
    return updated, course
