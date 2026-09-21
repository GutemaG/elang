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
from tests.fakes import EN_AM_COURSE_ID, FakeAuthSessionRepository, FakeUserRepository


def _make_user() -> User:
    return User(
        id=str(uuid.uuid4()),
        provider_identity=ProviderIdentity(
            auth_provider=AuthProvider.GOOGLE, provider_user_id="sub-1"
        ),
        selected_language=LanguageCode(code="am"),
        daily_xp_target=DailyXPTarget(xp_per_day=40),
        notification_enabled=True,
        created_at=datetime.now(UTC),
        active_course_id=EN_AM_COURSE_ID,
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


_TTL = timedelta(days=30)


def _session_expiring(
    user_id: str, token_value: str, now: datetime, left: timedelta
) -> AuthSession:
    """A session that, at `now`, has `left` until it expires -- i.e. was
    issued (or last renewed) `_TTL - left` ago."""
    expires_at = now + left
    return AuthSession(
        id=str(uuid.uuid4()),
        user_id=user_id,
        token=SessionToken(value=token_value, issued_at=expires_at - _TTL, expires_at=expires_at),
    )


class TestSlidingRenewal:
    """Using the app pushes the session back out to a full 30 days, so only
    someone who stays away for 30 days has to sign in again."""

    async def test_a_session_used_after_a_day_is_renewed_to_a_full_ttl(self) -> None:
        now = datetime(2026, 9, 21, 12, tzinfo=UTC)
        user = _make_user()
        session_repo = FakeAuthSessionRepository()
        await session_repo.add(_session_expiring(user.id, "tok", now, timedelta(days=20)))
        service = SessionValidationService(
            session_repo=session_repo, user_repo=FakeUserRepository([user]), session_ttl=_TTL
        )

        validated = await service.validate_and_renew("tok", now=now)

        assert validated is not None
        assert validated.user.id == user.id
        assert validated.expires_at == now + _TTL
        stored = await session_repo.find_by_token("tok")
        assert stored is not None
        assert stored.token.expires_at == now + _TTL

    async def test_a_session_renewed_within_the_last_day_is_not_written_again(self) -> None:
        now = datetime(2026, 9, 21, 12, tzinfo=UTC)
        user = _make_user()
        session_repo = FakeAuthSessionRepository()
        left = _TTL - timedelta(hours=3)
        await session_repo.add(_session_expiring(user.id, "tok", now, left))
        service = SessionValidationService(
            session_repo=session_repo, user_repo=FakeUserRepository([user]), session_ttl=_TTL
        )

        validated = await service.validate_and_renew("tok", now=now)

        assert validated is not None
        assert validated.expires_at == now + left
        assert session_repo.extend_calls == 0

    async def test_a_session_one_hour_from_expiry_is_saved_by_using_it(self) -> None:
        now = datetime(2026, 9, 21, 12, tzinfo=UTC)
        user = _make_user()
        session_repo = FakeAuthSessionRepository()
        await session_repo.add(_session_expiring(user.id, "tok", now, timedelta(hours=1)))
        service = SessionValidationService(
            session_repo=session_repo, user_repo=FakeUserRepository([user]), session_ttl=_TTL
        )

        validated = await service.validate_and_renew("tok", now=now)

        assert validated is not None
        assert validated.expires_at == now + _TTL

    async def test_an_expired_session_is_never_revived(self) -> None:
        now = datetime(2026, 9, 21, 12, tzinfo=UTC)
        user = _make_user()
        session_repo = FakeAuthSessionRepository()
        await session_repo.add(_session_expiring(user.id, "tok", now, timedelta(seconds=-1)))
        service = SessionValidationService(
            session_repo=session_repo, user_repo=FakeUserRepository([user]), session_ttl=_TTL
        )

        assert await service.validate_and_renew("tok", now=now) is None
        assert session_repo.extend_calls == 0
