"""FastAPI dependency wiring: builds domain services from per-request
repositories (bound to the request's `AsyncSession`) plus the app-level
verifier singletons stored on `app.state` (see `app/main.py`'s lifespan --
the verifiers own long-lived HTTP clients / JWKS caches that must outlive a
single request).
"""

from __future__ import annotations

from datetime import timedelta

from fastapi import Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.domain.services import (
    AuthenticationService,
    OnboardingAttachmentPolicy,
    SessionValidationService,
)
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
        session_ttl=timedelta(days=settings.session_ttl_days),
    )


async def get_session_validation_service(
    session: AsyncSession = Depends(get_db_session),
) -> SessionValidationService:
    user_repo = SqlAlchemyUserRepository(session)
    session_repo = SqlAlchemyAuthSessionRepository(session)
    return SessionValidationService(session_repo=session_repo, user_repo=user_repo)
