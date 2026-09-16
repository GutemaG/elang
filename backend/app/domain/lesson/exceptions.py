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


class InvalidCompletionTimestampError(LessonDomainError):
    """A completion's `client_completed_at` is implausible: more than a
    small clock-skew allowance in the future, or earlier than the
    account's own creation date (bolt 008, story
    002-timestamped-completion-for-streak-attribution). Rejected before
    any ledger effect, distinct from `InvalidCompletionError`'s
    count-mismatch case.
    """

    error_code = "invalid_completion_timestamp"
