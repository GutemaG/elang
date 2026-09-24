"""Custom domain exceptions for the lesson-content bounded context.

Each exception carries a stable `error_code` mapped to an HTTP status by the
second exception handler registered in
`app/infrastructure/api/error_handlers.py`, kept separate from (but
alongside) the existing `AuthDomainError` handler per
`ddd-02-technical-design.md`'s Error Handling section.
"""

from __future__ import annotations


class LessonDomainError(Exception):
    """Base class for all lesson-content-service domain exceptions."""

    error_code: str = "lesson_domain_error"

    def __init__(self, message: str) -> None:
        super().__init__(message)
        self.message = message


class LessonNotFoundError(LessonDomainError):
    """No lesson exists with the given id."""

    error_code = "lesson_not_found"


class SkillLockedError(LessonDomainError):
    """The lesson's owning skill is locked for this user.

    Enforced even for a direct lesson-id request, per story 001's edge case
    ("a locked skill's lesson must be unreachable even by direct ID").
    """

    error_code = "skill_locked"


class LessonCourseUnavailableError(LessonDomainError):
    """The lesson belongs to a course that is not `available` (bolt
    `024-courses-service`, ADR-12), so it cannot be started or completed.
    """

    error_code = "course_not_available"


class BeansExhaustedError(LessonDomainError):
    """A completion's implied wrong-answer count exceeds the account's
    actual beans balance at attempt start (ADR-5, Decision 1) -- the
    attempt should have been interrupted client-side, not completed.
    """

    error_code = "beans_exhausted"


class InvalidCompletionError(LessonDomainError):
    """The completion request's `total_count` doesn't match the lesson's
    actual exercise count, or `correct_count` exceeds `total_count` --
    a malformed or inconsistent request, rejected before any state change.
    """

    error_code = "invalid_completion"


class InsufficientAmoleError(LessonDomainError):
    """A Beans refill was attempted without enough Amole balance."""

    error_code = "insufficient_amole"


class InvalidPracticeCompletionError(LessonDomainError):
    """A Practice-session completion request is malformed: no results,
    or a `correct_count` implied by the results that doesn't match
    `total_count` -- rejected before any state change (bolt
    `020-practice-ui`), same category as `InvalidCompletionError` but kept
    distinct since Practice completions are a different domain concept
    from a lesson completion (no `lesson_id`, no Beans).
    """

    error_code = "invalid_practice_completion"


class InvalidCompletionTimestampError(LessonDomainError):
    """A completion's `client_completed_at` is implausible: more than a
    small clock-skew allowance in the future, or earlier than the
    account's own creation date (bolt 008, story
    002-timestamped-completion-for-streak-attribution). Rejected before
    any ledger effect, distinct from `InvalidCompletionError`'s
    count-mismatch case.
    """

    error_code = "invalid_completion_timestamp"


# --- Content admin API (bolt 035-admin-content-api, 017-content-admin-web) ---


class AdminContentError(LessonDomainError):
    """Base for content admin API failures. `details` travels to the client
    in the error body alongside `error_code` and `message`."""

    error_code = "admin_content_error"

    def __init__(self, message: str, **details: object) -> None:
        super().__init__(message)
        self.details = details


class ContentNotFoundError(AdminContentError):
    """No course, section, skill, lesson or exercise has the given id."""

    error_code = "content_not_found"


class InvalidContentError(AdminContentError):
    """A write's input is unusable; `details["field"]` names the part."""

    error_code = "invalid_content"

    def __init__(self, field: str, message: str) -> None:
        super().__init__(message, field=field)
        self.field = field


class InvalidExerciseError(InvalidContentError):
    """An exercise the app could not play: bad shape, broken invariant, or
    an answer key naming ids its content does not have."""

    error_code = "invalid_exercise"


class InvalidOrderError(AdminContentError):
    """A reorder's ids are not exactly the parent's current children."""

    error_code = "invalid_order"


class ContentInUseError(AdminContentError):
    """A delete would remove content that learners have progress or
    attempts on. Refused even when confirmed."""

    error_code = "content_in_use"


class ConfirmationRequiredError(AdminContentError):
    """A delete of unused content that removes children too; repeat it with
    `confirm=true`. `details` says what would go."""

    error_code = "confirmation_required"


class InvalidAudioLinkError(AdminContentError):
    """A pasted audio link that cannot be used; `details["reason"]` says
    why (`not_https`, `private_address`, `unreachable`, `timeout`,
    `bad_status`, `not_audio`). Bolt 036."""

    error_code = "invalid_audio_link"


class AudioStorageNotConfiguredError(AdminContentError):
    """Uploads need `AUDIO_BASE_URL` and every `R2_*` setting. Bolt 036."""

    error_code = "audio_storage_not_configured"


class InvalidUploadLinkError(AdminContentError):
    """A local upload link that this backend did not issue, or that was
    altered after it was issued. Bolt 041."""

    error_code = "invalid_upload_link"


class UploadLinkExpiredError(InvalidUploadLinkError):
    """A local upload link used after its 10 minutes. Bolt 041."""

    error_code = "upload_link_expired"


class AudioFileExistsError(AdminContentError):
    """A local upload would replace a file already saved. Bolt 041."""

    error_code = "audio_file_exists"
