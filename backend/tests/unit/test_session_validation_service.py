"""Unit tests: SessionValidationService -- valid, expired, and unknown token
outcomes, with fake repositories (no DB, no HTTP)."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta

from app.domain.entities import AuthSession, User
from app.domain.services import SessionValidationService
from app.domain.value_objects import (
    AuthProvider,
    DailyXPTarget,
    LanguageCode,
    ProviderIdentity,
    SessionToken,
)
from tests.fakes import FakeAuthSessionRepository, FakeUserRepository


def _make_user() -> User:
    return User(
        id=str(uuid.uuid4()),
        provider_identity=ProviderIdentity(
            auth_provider=AuthProvider.GOOGLE, provider_user_id="sub-1"
        ),
        selected_language=LanguageCode(code="am"),
        daily_xp_target=DailyXPTarget(xp_per_day=40),
        created_at=datetime.now(UTC),
    )


def _make_session(user_id: str, token_value: str, expires_delta: timedelta) -> AuthSession:
    now = datetime.now(UTC)
    return AuthSession(
        id=str(uuid.uuid4()),
        user_id=user_id,
        token=SessionToken(value=token_value, issued_at=now, expires_at=now + expires_delta),
    )


class TestSessionValidationService:
    async def test_valid_token_returns_user(self) -> None:
        user = _make_user()
        user_repo = FakeUserRepository([user])
        session_repo = FakeAuthSessionRepository()
        await session_repo.add(_make_session(user.id, "valid-tok", timedelta(days=1)))
        service = SessionValidationService(session_repo=session_repo, user_repo=user_repo)

        result = await service.validate("valid-tok")

        assert result is not None
        assert result.id == user.id

    async def test_expired_token_returns_none(self) -> None:
        user = _make_user()
        user_repo = FakeUserRepository([user])
        session_repo = FakeAuthSessionRepository()
        await session_repo.add(_make_session(user.id, "expired-tok", timedelta(days=-1)))
        service = SessionValidationService(session_repo=session_repo, user_repo=user_repo)

        result = await service.validate("expired-tok")

        assert result is None

    async def test_unknown_token_returns_none(self) -> None:
        user_repo = FakeUserRepository()
        session_repo = FakeAuthSessionRepository()
        service = SessionValidationService(session_repo=session_repo, user_repo=user_repo)

        result = await service.validate("never-issued-tok")

        assert result is None
        # An unknown token must never even attempt to load a User -- per the
        # domain model, "an expired or unknown token fails validation
        # cleanly without ever loading or exposing User data."
        assert user_repo.get_by_id_calls == 0
