"""FastAPI dependency wiring: builds domain services from per-request
repositories (bound to the request's `AsyncSession`) plus the app-level
verifier singletons stored on `app.state` (see `app/main.py`'s lifespan --
the verifiers own long-lived HTTP clients / JWKS caches that must outlive a
single request).
"""

from __future__ import annotations

import logging
from datetime import timedelta

from fastapi import Depends, Header, Request
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncSession

from app.application.use_cases import validate_session
from app.config import get_settings
from app.domain.admin import AdminAccess, parse_admin_emails, resolve_access
from app.domain.entities import User
from app.domain.exceptions import (
    AdminAccessUnavailableError,
    InvalidSessionError,
    MissingCredentialsError,
    NotAdminError,
    SuperAdminOnlyError,
)
from app.domain.lesson.exceptions import ContentNotFoundError
from app.domain.services import (
    AuthenticationService,
    OnboardingAttachmentPolicy,
    SessionValidationService,
    UserPreferencesService,
)
from app.infrastructure.db.admin_content_repository import SqlAlchemyAdminContentRepository
from app.infrastructure.db.admin_member_repository import SqlAlchemyAdminMemberRepository
from app.infrastructure.db.league_repository import SqlAlchemyLeagueRepository
from app.infrastructure.db.lesson_repositories import SqlAlchemyCourseRepository
from app.infrastructure.db.repositories import (
    SqlAlchemyAppConfigRepository,
    SqlAlchemyAuthSessionRepository,
    SqlAlchemyUserRepository,
)
from app.infrastructure.db.session import get_db_session

logger = logging.getLogger("app.admin")


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


async def get_league_repository(
    session: AsyncSession = Depends(get_db_session),
) -> SqlAlchemyLeagueRepository:
    return SqlAlchemyLeagueRepository(session)


async def get_app_config_repository(
    session: AsyncSession = Depends(get_db_session),
) -> SqlAlchemyAppConfigRepository:
    return SqlAlchemyAppConfigRepository(session)


async def get_session_validation_service(
    session: AsyncSession = Depends(get_db_session),
) -> SessionValidationService:
    user_repo = SqlAlchemyUserRepository(session)
    session_repo = SqlAlchemyAuthSessionRepository(session)
    return SessionValidationService(
        session_repo=session_repo,
        user_repo=user_repo,
        session_ttl=timedelta(days=get_settings().session_ttl_days),
    )


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


async def require_admin(
    user: User = Depends(get_current_user), session: AsyncSession = Depends(get_db_session)
) -> AdminAccess:
    """Who the signed-in admin is, and what they may reach (ADR-16; intent
    028, bolt 102). An email in `ADMIN_EMAILS` is an owner: a super admin,
    with no database read. Anyone else must be on the team. Layered on
    `get_current_user`, so a missing or invalid session is still its 401;
    a valid session that is neither is a 403. Read on every request, so
    removing someone, or a course from them, takes effect on the next one.
    A team that can't be read is a 503: access is never granted on error.
    """
    owners = parse_admin_emails(get_settings().admin_emails)
    member = None
    if user.email and user.email.strip().lower() not in owners:
        try:
            member = await SqlAlchemyAdminMemberRepository(session).find_by_email(user.email)
        except SQLAlchemyError as e:
            logger.exception("admin_access_unavailable")
            raise AdminAccessUnavailableError(
                "Admin access can't be checked right now. Try again."
            ) from e
    access = resolve_access(user.email, owners, member)
    if access is None:
        raise NotAdminError("This account is not an admin")
    return access


async def require_super_admin(access: AdminAccess = Depends(require_admin)) -> AdminAccess:
    """Intent 028: only an owner or a stored super admin passes; a course
    admin is a 403 `super_admin_only`."""
    if not access.is_super:
        raise SuperAdminOnlyError("Only a super admin can do this")
    return access


async def require_course(course_id: str, access: AdminAccess = Depends(require_admin)) -> None:
    """Intent 028: a route named by `{course_id}` is only for an admin who
    has that course. Anyone else gets the same 404 as an unknown course,
    so other courses' ids aren't revealed. A super admin always passes;
    an unknown id still gets its 404 from the route."""
    if not access.can_open_course(course_id):
        raise ContentNotFoundError("No such course", entity="course", id=course_id)


async def check_course_of(
    access: AdminAccess | None,
    repo: SqlAlchemyAdminContentRepository,
    kind: str,
    item_id: str | None,
) -> None:
    """Intent 028: refuses a course admin a section, skill, lesson,
    exercise or vocab item outside their courses, with the same 404 as an
    unknown id. A super admin, or no id, always passes. Routes whose id is
    in the body (uploads, generation) call this themselves."""
    if item_id is None or access is None or access.is_super:
        return
    course_id = await repo.course_of(kind, item_id)
    if course_id is None or not access.can_open_course(course_id):
        raise ContentNotFoundError(f"No such {kind}", entity=kind, id=item_id)


def _content_repo(
    session: AsyncSession = Depends(get_db_session),
) -> SqlAlchemyAdminContentRepository:
    return SqlAlchemyAdminContentRepository(session)


async def require_section_course(
    section_id: str,
    access: AdminAccess = Depends(require_admin),
    repo: SqlAlchemyAdminContentRepository = Depends(_content_repo),
) -> None:
    await check_course_of(access, repo, "section", section_id)


async def require_skill_course(
    skill_id: str,
    access: AdminAccess = Depends(require_admin),
    repo: SqlAlchemyAdminContentRepository = Depends(_content_repo),
) -> None:
    await check_course_of(access, repo, "skill", skill_id)


async def require_lesson_course(
    lesson_id: str,
    access: AdminAccess = Depends(require_admin),
    repo: SqlAlchemyAdminContentRepository = Depends(_content_repo),
) -> None:
    await check_course_of(access, repo, "lesson", lesson_id)


async def require_exercise_course(
    exercise_id: str,
    access: AdminAccess = Depends(require_admin),
    repo: SqlAlchemyAdminContentRepository = Depends(_content_repo),
) -> None:
    await check_course_of(access, repo, "exercise", exercise_id)


async def require_vocab_course(
    vocab_item_id: str,
    access: AdminAccess = Depends(require_admin),
    repo: SqlAlchemyAdminContentRepository = Depends(_content_repo),
) -> None:
    await check_course_of(access, repo, "vocab", vocab_item_id)


async def languages_of(
    access: AdminAccess | None, repo: SqlAlchemyAdminContentRepository
) -> frozenset[str] | None:
    """The languages an admin may work on outside a course: None (all) for
    a super admin, else the learning languages of their courses (intent
    028)."""
    if access is None or access.is_super or access.course_ids is None:
        return None
    return await repo.learning_languages(access.course_ids)


async def require_language(
    language: str,
    access: AdminAccess = Depends(require_admin),
    repo: SqlAlchemyAdminContentRepository = Depends(_content_repo),
) -> None:
    """A sounds chart route is only for a language one of the admin's
    courses teaches; any other is the same 404 as a language with no
    chart."""
    allowed = await languages_of(access, repo)
    if allowed is not None and language not in allowed:
        raise ContentNotFoundError(
            "This language has no sounds chart", entity="sound_chart", id=language
        )


def get_owner_emails() -> frozenset[str]:
    """The owners: `ADMIN_EMAILS`, always super admins (intent 028)."""
    return parse_admin_emails(get_settings().admin_emails)
