"""FastAPI exception handlers mapping domain exceptions to the Error Codes
tables in `ddd-02-technical-design.md` (auth) and this bolt's own
`ddd-02-technical-design.md` (lesson content).

Two handlers, one per bounded context's exception base class, registered
together here so all exception-to-HTTP mapping stays centralized in one
file per `coding-standards.md`'s custom-domain-exception convention --
without forcing lesson exceptions to pretend to be auth exceptions (see
`004-lesson-content-service`'s Technical Design, Error Handling section).
"""

from __future__ import annotations

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

from app.domain.exceptions import (
    AuthDomainError,
    CourseNotAvailableError,
    CourseNotFoundError,
    ExpiredTokenError,
    InvalidPendingSelectionError,
    InvalidPreferenceValueError,
    InvalidSessionError,
    InvalidTokenError,
    MissingCredentialsError,
    ProviderUnreachableError,
)
from app.domain.lesson.exceptions import (
    BeansExhaustedError,
    InsufficientAmoleError,
    InvalidCompletionError,
    InvalidCompletionTimestampError,
    InvalidPracticeCompletionError,
    LessonCourseUnavailableError,
    LessonDomainError,
    LessonNotFoundError,
    SkillLockedError,
)

_AUTH_STATUS_BY_EXCEPTION: dict[type[AuthDomainError], int] = {
    InvalidTokenError: 401,
    ExpiredTokenError: 401,
    InvalidPendingSelectionError: 400,
    ProviderUnreachableError: 502,
    MissingCredentialsError: 401,
    InvalidSessionError: 401,
    InvalidPreferenceValueError: 422,
    CourseNotFoundError: 404,
    CourseNotAvailableError: 422,
}
_AUTH_DEFAULT_STATUS = 400

_LESSON_STATUS_BY_EXCEPTION: dict[type[LessonDomainError], int] = {
    LessonNotFoundError: 404,
    SkillLockedError: 403,
    LessonCourseUnavailableError: 403,
    BeansExhaustedError: 422,
    InvalidCompletionError: 422,
    InsufficientAmoleError: 422,
    InvalidCompletionTimestampError: 422,
    InvalidPracticeCompletionError: 422,
}
_LESSON_DEFAULT_STATUS = 400


def register_exception_handlers(app: FastAPI) -> None:
    @app.exception_handler(AuthDomainError)
    async def handle_auth_domain_error(request: Request, exc: AuthDomainError) -> JSONResponse:
        status_code = _AUTH_STATUS_BY_EXCEPTION.get(type(exc), _AUTH_DEFAULT_STATUS)
        return JSONResponse(
            status_code=status_code,
            content={"error_code": exc.error_code, "message": exc.message},
        )

    @app.exception_handler(LessonDomainError)
    async def handle_lesson_domain_error(request: Request, exc: LessonDomainError) -> JSONResponse:
        status_code = _LESSON_STATUS_BY_EXCEPTION.get(type(exc), _LESSON_DEFAULT_STATUS)
        return JSONResponse(
            status_code=status_code,
            content={"error_code": exc.error_code, "message": exc.message},
        )
