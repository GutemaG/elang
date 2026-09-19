"""FastAPI dependency wiring: builds domain services from per-request
repositories (bound to the request's `AsyncSession`) plus the app-level
verifier singletons stored on `app.state` (see `app/main.py`'s lifespan --
the verifiers own long-lived HTTP clients / JWKS caches that must outlive a
single request).
"""

from __future__ import annotations

from datetime import timedelta

from fastapi import Depends, Header, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.application.use_cases import validate_session
from app.config import get_settings
from app.domain.entities import User
from app.domain.exceptions import InvalidSessionError, MissingCredentialsError
from app.domain.services import (
    AuthenticationService,
    OnboardingAttachmentPolicy,
    SessionValidationService,
    UserPreferencesService,
)
from app.infrastructure.db.lesson_repositories import SqlAlchemyCourseRepository
from app.infrastructure.db.repositories import (
    SqlAlchemyAuthSessionRepository,
    SqlAlchemyUserRepository,
)
from app.infrastructure.db.session import get_db_session


async def get_authentication_service(
    request: Request, session: AsyncSession = Depends(get_db_session)
) -> AuthenticationService:
    settings = get_settings()
    user_repo = SqlAlchemyUserRepository(session)
    session_repo = SqlAlchemyAuthSessionRepository(session)
    return AuthenticationService(
        google_verifier=request.app.state.google_verifier,
        apple_verifier=request.app.state.apple_verifier,
        user_repo=user_repo,
        session_repo=session_repo,
        onboarding_policy=OnboardingAttachmentPolicy(),
        course_repo=SqlAlchemyCourseRepository(session),
        session_ttl=timedelta(days=settings.session_ttl_days),
    )


async def get_user_preferences_service(
    session: AsyncSession = Depends(get_db_session),
) -> UserPreferencesService:
    user_repo = SqlAlchemyUserRepository(session)
    return UserPreferencesService(
        user_repo=user_repo,
        onboarding_policy=OnboardingAttachmentPolicy(),
        course_repo=SqlAlchemyCourseRepository(session),
    )


async def get_user_repository(
    session: AsyncSession = Depends(get_db_session),
) -> SqlAlchemyUserRepository:
    return SqlAlchemyUserRepository(session)


async def get_session_validation_service(
    session: AsyncSession = Depends(get_db_session),
) -> SessionValidationService:
    user_repo = SqlAlchemyUserRepository(session)
    session_repo = SqlAlchemyAuthSessionRepository(session)
    return SessionValidationService(session_repo=session_repo, user_repo=user_repo)


async def get_current_user(
    authorization: str | None = Header(default=None),
    service: SessionValidationService = Depends(get_session_validation_service),
) -> User:
    """Shared authenticated-endpoint dependency, reusing the exact same
    `SessionValidationService` `001-auth-service` already exercises via
    `/auth/session` -- no new auth mechanism, per
    `004-lesson-content-service`'s Technical Design (Security Design).

    Unlike `/auth/session` (whose job is *polling* validity, so an invalid
    token is a normal `200 {"valid": false}` outcome), every other
    authenticated endpoint treats an invalid/expired/unknown token as a
    request failure: `InvalidSessionError` (401), distinct from
    `MissingCredentialsError` (401) for a missing/malformed header.
    """
    if not authorization or not authorization.lower().startswith("bearer "):
        raise MissingCredentialsError("Missing or malformed Authorization header")
    token_value = authorization.split(" ", 1)[1].strip()
    if not token_value:
        raise MissingCredentialsError("Missing or malformed Authorization header")

    user = await validate_session(service, token_value)
    if user is None:
        raise InvalidSessionError("Session token is unknown or expired")
    return user
