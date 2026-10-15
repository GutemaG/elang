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
    AdminAccessUnavailableError,
    AuthDomainError,
    CourseNotAvailableError,
    CourseNotFoundError,
    ExpiredTokenError,
    InvalidPendingSelectionError,
    InvalidPreferenceValueError,
    InvalidSessionError,
    InvalidSettingError,
    InvalidTokenError,
    MissingCredentialsError,
    NotAdminError,
    ProviderUnreachableError,
    SuperAdminOnlyError,
)
from app.domain.lesson.exceptions import (
    AdminContentError,
    AdminMemberExistsError,
    AdminMemberSelfError,
    AudioFileExistsError,
    AudioFileInUseError,
    AudioFileNotFoundError,
    AudioStorageNotConfiguredError,
    AudioStorageUnavailableError,
    BeansExhaustedError,
    ConfirmationRequiredError,
    ContentChangedError,
    ContentExistsError,
    ContentInUseError,
    ContentNotFoundError,
    InsufficientAmoleError,
    InvalidAudioLinkError,
    InvalidCompletionError,
    InvalidCompletionTimestampError,
    InvalidContentError,
    InvalidExerciseError,
    InvalidFeedbackError,
    InvalidImportError,
    InvalidOrderError,
    InvalidPracticeCompletionError,
    InvalidRangeError,
    InvalidUploadLinkError,
    LeagueMemberNotFoundError,
    LeagueWeekClosedError,
    LessonCourseUnavailableError,
    LessonDomainError,
    LessonNotFoundError,
    LessonNotReadyError,
    SkillLockedError,
    SoundChartIncompleteError,
    TooMuchFeedbackError,
    UploadLinkExpiredError,
    VoiceCreditExhaustedError,
    VoiceLanguageMismatchError,
    VoiceNotConfiguredError,
    VoiceRateLimitedError,
    VoiceServiceFailedError,
    VoiceServiceTimeoutError,
    VoiceTextRejectedError,
)

_AUTH_STATUS_BY_EXCEPTION: dict[type[AuthDomainError], int] = {
    InvalidTokenError: 401,
    ExpiredTokenError: 401,
    InvalidPendingSelectionError: 400,
    ProviderUnreachableError: 502,
    MissingCredentialsError: 401,
    InvalidSessionError: 401,
    InvalidPreferenceValueError: 422,
    InvalidSettingError: 422,
    CourseNotFoundError: 404,
    CourseNotAvailableError: 422,
    NotAdminError: 403,
    SuperAdminOnlyError: 403,
    AdminAccessUnavailableError: 503,
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
    InvalidRangeError: 422,
    InvalidFeedbackError: 422,
    TooMuchFeedbackError: 429,
    ContentNotFoundError: 404,
    InvalidContentError: 422,
    InvalidExerciseError: 422,
    InvalidImportError: 422,
    InvalidOrderError: 422,
    ContentInUseError: 409,
    ContentExistsError: 409,
    AdminMemberExistsError: 409,
    AdminMemberSelfError: 409,
    ConfirmationRequiredError: 409,
    ContentChangedError: 409,
    LessonNotReadyError: 409,
    SoundChartIncompleteError: 409,
    InvalidAudioLinkError: 422,
    AudioStorageNotConfiguredError: 503,
    InvalidUploadLinkError: 403,
    UploadLinkExpiredError: 403,
    AudioFileExistsError: 409,
    AudioStorageUnavailableError: 502,
    AudioFileNotFoundError: 404,
    AudioFileInUseError: 409,
    LeagueMemberNotFoundError: 404,
    LeagueWeekClosedError: 409,
    VoiceNotConfiguredError: 503,
    VoiceCreditExhaustedError: 402,
    VoiceRateLimitedError: 429,
    VoiceServiceFailedError: 502,
    VoiceServiceTimeoutError: 504,
    VoiceTextRejectedError: 422,
    VoiceLanguageMismatchError: 422,
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
        content: dict[str, object] = {"error_code": exc.error_code, "message": exc.message}
        # Bolt 035: admin errors say which field, or what a delete would do.
        if isinstance(exc, AdminContentError) and exc.details:
            content["details"] = exc.details
        return JSONResponse(status_code=status_code, content=content)
