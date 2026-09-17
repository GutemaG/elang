"""Application layer: one use case per operation.

Orchestrates domain services, translates results for the presentation layer,
and emits the domain event log entries (per `ddd-02-technical-design.md`'s
NFR Implementation: Observability). No direct SQLAlchemy or HTTP imports —
callers (the FastAPI routers) are responsible for the request/response
mapping and for committing the DB transaction the injected repositories share.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from datetime import UTC, datetime

from app.domain.entities import User
from app.domain.events import (
    AuthenticationRejected,
    SessionIssued,
    UserAuthenticated,
    UserRegistered,
)
from app.domain.exceptions import AuthDomainError
from app.domain.services import (
    AuthenticationService,
    AuthResult,
    SessionValidationService,
    UserPreferencesService,
)
from app.domain.value_objects import AuthProvider

logger = logging.getLogger("app.auth")


@dataclass(frozen=True)
class PendingSelectionInput:
    """Application-layer input shape for a pending onboarding selection, as
    parsed from the API request body.

    Deliberately carries *raw*, unvalidated fields -- `AuthenticationService`
    only validates (and may raise `InvalidPendingSelectionError`) on the
    account-creation branch, never before it knows whether the sign-in
    resolves to a new or returning user (a returning user's pending
    selection "has no effect whatsoever", including no validation error for
    a malformed one, per the domain model).
    """

    language: str
    daily_goal_minutes: int


def _log_auth_success(result: AuthResult, auth_provider: AuthProvider) -> None:
    if result.is_new_user:
        registered_event = UserRegistered(
            user_id=result.user.id,
            auth_provider=auth_provider,
            selected_language=result.user.selected_language.code,
            daily_xp_target=result.user.daily_xp_target.xp_per_day,
            registered_at=result.user.created_at,
        )
        logger.info(
            "user_registered user_id=%s auth_provider=%s",
            registered_event.user_id,
            registered_event.auth_provider.value,
        )
    else:
        authenticated_event = UserAuthenticated(
            user_id=result.user.id,
            auth_provider=auth_provider,
            authenticated_at=datetime.now(UTC),
        )
        logger.info(
            "user_authenticated user_id=%s auth_provider=%s",
            authenticated_event.user_id,
            authenticated_event.auth_provider.value,
        )

    # Deliberately excludes the raw session token -- SessionIssued has no
    # field for it, and nothing here ever reads result.raw_session_token.
    session_event = SessionIssued(
        session_id=result.session.id,
        user_id=result.user.id,
        issued_at=result.session.token.issued_at,
        expires_at=result.session.token.expires_at,
    )
    logger.info(
        "session_issued session_id=%s user_id=%s expires_at=%s",
        session_event.session_id,
        session_event.user_id,
        session_event.expires_at.isoformat(),
    )


def _log_auth_rejected(auth_provider: AuthProvider | None, error: AuthDomainError) -> None:
    event = AuthenticationRejected(
        auth_provider=auth_provider,
        reason=error.error_code,
        attempted_at=datetime.now(UTC),
    )
    logger.warning(
        "authentication_rejected auth_provider=%s reason=%s",
        event.auth_provider.value if event.auth_provider else None,
        event.reason,
    )


async def authenticate_with_google(
    service: AuthenticationService,
    id_token: str,
    pending_selection: PendingSelectionInput | None,
) -> AuthResult:
    """Story 002. Verifies the Google ID token, creates-or-loads the `User`,
    attaches the pending selection only on account creation, and issues a
    session. Raises `AuthDomainError` subclasses on failure (see
    `app.domain.exceptions`); the presentation layer maps those to HTTP.
    """
    try:
        result = await service.authenticate_with_google(
            id_token,
            pending_selection.language if pending_selection else None,
            pending_selection.daily_goal_minutes if pending_selection else None,
        )
    except AuthDomainError as exc:
        _log_auth_rejected(AuthProvider.GOOGLE, exc)
        raise
    _log_auth_success(result, AuthProvider.GOOGLE)
    return result


async def authenticate_with_apple(
    service: AuthenticationService,
    identity_token: str,
    pending_selection: PendingSelectionInput | None,
) -> AuthResult:
    """Story 003. Same flow as `authenticate_with_google`, verifying against
    Apple's JWKS instead of Google's token-info endpoint.
    """
    try:
        result = await service.authenticate_with_apple(
            identity_token,
            pending_selection.language if pending_selection else None,
            pending_selection.daily_goal_minutes if pending_selection else None,
        )
    except AuthDomainError as exc:
        _log_auth_rejected(AuthProvider.APPLE, exc)
        raise
    _log_auth_success(result, AuthProvider.APPLE)
    return result


async def validate_session(service: SessionValidationService, token_value: str) -> User | None:
    """Used on every app restart (stories 002/003's session-recognition ACs).
    Returns `None` for an unknown/expired token -- this is an expected,
    non-error outcome, never raised as an exception.
    """
    return await service.validate(token_value)


async def update_user_preferences(
    service: UserPreferencesService,
    user: User,
    language_code: str | None,
    daily_goal_minutes: int | None,
    notification_enabled: bool | None,
) -> User:
    """Bolt 013, stories 001/002: applies a preference update and logs it
    for observability. No domain event exists for this (the Domain Model
    stage found no event-driven infrastructure anywhere in this codebase
    to extend) -- a plain log line matches the existing observability
    pattern instead. Raises `InvalidPreferenceValueError` (422) on an
    invalid language/goal value; propagated as-is for the presentation
    layer to map.
    """
    updated = await service.update_preferences(
        user, language_code, daily_goal_minutes, notification_enabled
    )
    logger.info("user_preferences_updated user_id=%s", updated.id)
    return updated
