"""FastAPI routers: `GET /api/v1/courses`, `PUT /api/v1/users/me/active-course`
(bolt `024-courses-service`, ADR-12/ADR-13). Parses the request, calls the
application use case, and maps the result. No business logic lives here.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends

from app.application.course_use_cases import activate_course, list_courses
from app.domain.course import CourseRepository
from app.domain.entities import User
from app.domain.repositories import UserRepository
from app.infrastructure.api.course_schemas import (
    ActivateCourseRequest,
    ActivateCourseResponse,
    CourseInfoResponse,
    CourseListResponse,
    CourseResponse,
)
from app.infrastructure.api.dependencies import get_current_user, get_user_repository
from app.infrastructure.api.lesson_dependencies import get_course_repository

router = APIRouter(prefix="/api/v1", tags=["courses"])


@router.get("/courses", response_model=CourseListResponse)
async def list_courses_endpoint(
    user: User = Depends(get_current_user),
    course_repo: CourseRepository = Depends(get_course_repository),
) -> CourseListResponse:
    """Every course (available and coming soon) for the course picker, with
    the caller's active course marked and per-course skill progress.
    """
    result = await list_courses(user, course_repo)
    return CourseListResponse(
        active_course_id=result.active_course_id,
        courses=[
            CourseResponse(
                id=summary.course.id,
                learning_language=summary.course.learning_language,
                from_language=summary.course.from_language,
                title=summary.course.title,
                status=summary.course.status.value,
                order_index=summary.course.order_index,
                is_active=summary.is_active,
                completed_skills=summary.completed_skills,
                total_skills=summary.total_skills,
            )
            for summary in result.courses
        ],
    )


@router.put("/users/me/active-course", response_model=ActivateCourseResponse)
async def activate_course_endpoint(
    body: ActivateCourseRequest,
    user: User = Depends(get_current_user),
    course_repo: CourseRepository = Depends(get_course_repository),
    user_repo: UserRepository = Depends(get_user_repository),
) -> ActivateCourseResponse:
    """Switches the caller's active course. 404 `course_not_found` for an
    unknown id, 422 `course_not_available` for a coming-soon course; the
    active course is unchanged on any error.
    """
    updated, course = await activate_course(user, body.course_id, course_repo, user_repo)
    return ActivateCourseResponse(
        active_course_id=updated.active_course_id,
        selected_language=updated.selected_language.code,
        course=CourseInfoResponse(
            id=course.id,
            learning_language=course.learning_language,
            from_language=course.from_language,
            title=course.title,
        ),
    )
