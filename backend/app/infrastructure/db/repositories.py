"""SQLAlchemy-backed implementations of the domain's repository Protocols.

Owns the mapping between domain entities/value objects and the `UserModel`/
`AuthSessionModel` ORM rows, and the token-hashing detail (ADR-1) that the
domain's `AuthSessionRepository.find_by_token` interface deliberately hides.
"""

from __future__ import annotations

import hashlib
from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.entities import AuthSession, User
from app.domain.value_objects import (
    AuthProvider,
    DailyXPTarget,
    LanguageCode,
    ProviderIdentity,
    SessionToken,
)
from app.infrastructure.db.models import AuthSessionModel, UserModel


def _hash_token(token_value: str) -> str:
    """SHA-256 hex digest of the raw token value, per ADR-1."""
    return hashlib.sha256(token_value.encode("utf-8")).hexdigest()


def _ensure_utc(value: datetime) -> datetime:
    """Normalizes a datetime read back from storage to timezone-aware UTC.

    SQLite (local dev/test, per `data-stack.md`) does not actually persist
    timezone info even for a `DateTime(timezone=True)` column -- values come
    back naive. PostgreSQL round-trips them correctly. The domain layer
    assumes every datetime it handles is timezone-aware (e.g.
    `SessionToken.is_expired` compares against `datetime.now(timezone.utc)`),
    so this normalization happens once, at the infrastructure boundary,
    rather than leaking a SQLite-specific quirk into domain logic.
    """
    if value.tzinfo is None:
        return value.replace(tzinfo=UTC)
    return value.astimezone(UTC)


def _user_model_to_domain(model: UserModel) -> User:
    return User(
        id=model.id,
        provider_identity=ProviderIdentity(
            auth_provider=AuthProvider(model.auth_provider),
            provider_user_id=model.provider_user_id,
        ),
        selected_language=LanguageCode(code=model.selected_language),
        daily_xp_target=DailyXPTarget(xp_per_day=model.daily_xp_target),
        notification_enabled=model.notification_enabled,
        created_at=_ensure_utc(model.created_at),
        active_course_id=model.active_course_id,
    )


def _user_domain_to_model(user: User) -> UserModel:
    return UserModel(
        id=user.id,
        auth_provider=user.provider_identity.auth_provider.value,
        provider_user_id=user.provider_identity.provider_user_id,
        selected_language=user.selected_language.code,
        daily_xp_target=user.daily_xp_target.xp_per_day,
        notification_enabled=user.notification_enabled,
        created_at=user.created_at,
        active_course_id=user.active_course_id,
    )


class SqlAlchemyUserRepository:
    """Implements `app.domain.repositories.UserRepository`."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def find_by_provider_identity(
        self, auth_provider: AuthProvider, provider_user_id: str
    ) -> User | None:
        stmt = select(UserModel).where(
            UserModel.auth_provider == auth_provider.value,
            UserModel.provider_user_id == provider_user_id,
        )
        result = await self._session.execute(stmt)
        model = result.scalar_one_or_none()
        return _user_model_to_domain(model) if model is not None else None

    async def add(self, user: User) -> User:
        model = _user_domain_to_model(user)
        self._session.add(model)
        await self._session.flush()
        return _user_model_to_domain(model)

    async def get_by_id(self, user_id: str) -> User | None:
        stmt = select(UserModel).where(UserModel.id == user_id)
        result = await self._session.execute(stmt)
        model = result.scalar_one_or_none()
        return _user_model_to_domain(model) if model is not None else None

    async def update(self, user: User) -> User:
        """Bolt 013: persists the one sanctioned post-creation change to
        `daily_xp_target` (ADR-7), plus `notification_enabled`. Bolt 024
        (ADR-13): also the active course and its `selected_language`
        mirror, which the domain only ever changes together through
        `activate_course_for_user`. `user.id` must already exist.
        """
        stmt = select(UserModel).where(UserModel.id == user.id)
        result = await self._session.execute(stmt)
        model = result.scalar_one()
        model.selected_language = user.selected_language.code
        model.active_course_id = user.active_course_id
        model.daily_xp_target = user.daily_xp_target.xp_per_day
        model.notification_enabled = user.notification_enabled
        await self._session.flush()
        return _user_model_to_domain(model)


class SqlAlchemyAuthSessionRepository:
    """Implements `app.domain.repositories.AuthSessionRepository`.

    Hashes the raw token value before every write/lookup -- the raw value is
    never persisted (ADR-1).
    """

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def add(self, session: AuthSession) -> AuthSession:
        model = AuthSessionModel(
            id=session.id,
            user_id=session.user_id,
            token_hash=_hash_token(session.token.value),
            issued_at=session.token.issued_at,
            expires_at=session.token.expires_at,
        )
        self._session.add(model)
        await self._session.flush()
        # The raw token value lives only in the domain object returned here
        # (and ultimately in the HTTP response) -- never re-read from storage.
        return session

    async def find_by_token(self, token_value: str) -> AuthSession | None:
        token_hash = _hash_token(token_value)
        stmt = select(AuthSessionModel).where(AuthSessionModel.token_hash == token_hash)
        result = await self._session.execute(stmt)
        model = result.scalar_one_or_none()
        if model is None:
            return None
        return AuthSession(
            id=model.id,
            user_id=model.user_id,
            token=SessionToken(
                value=token_value,
                issued_at=_ensure_utc(model.issued_at),
                expires_at=_ensure_utc(model.expires_at),
            ),
        )

    async def get_by_id(self, session_id: str) -> AuthSession | None:
        stmt = select(AuthSessionModel).where(AuthSessionModel.id == session_id)
        result = await self._session.execute(stmt)
        model = result.scalar_one_or_none()
        if model is None:
            return None
        # The raw token value is never recoverable from storage -- this path
        # (get_by_id) is not used to reconstruct a usable token, only session
        # metadata. Callers that need a live SessionToken must go through
        # find_by_token with the raw value the client presented.
        return AuthSession(
            id=model.id,
            user_id=model.user_id,
            token=SessionToken(
                value="",
                issued_at=_ensure_utc(model.issued_at),
                expires_at=_ensure_utc(model.expires_at),
            ),
        )
