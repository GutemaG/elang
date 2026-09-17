"""Direct unit tests for the shared `get_current_user` dependency
(`app/infrastructure/api/dependencies.py`), called from a normal
pytest-asyncio loop rather than through `TestClient`.

`001-auth-service`'s test report documented that a route/dependency
function's tail lines can show as "missed" under `coverage.py` when only
exercised inside `TestClient`'s background portal thread, despite being
genuinely executed (every behavior is asserted via the HTTP response).
Calling the function directly here, the same way `001-auth-service`'s
`test_use_cases.py` did for its use cases, both closes that reporting gap
and gives direct confidence in `get_current_user`'s branches independent of
the HTTP layer.
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

import pytest

from app.domain.entities import AuthSession, User
from app.domain.exceptions import InvalidSessionError, MissingCredentialsError
from app.domain.services import SessionValidationService
from app.domain.value_objects import (
    AuthProvider,
    DailyXPTarget,
    LanguageCode,
    ProviderIdentity,
    SessionToken,
)
from app.infrastructure.api.dependencies import get_current_user
from tests.fakes import FakeAuthSessionRepository, FakeUserRepository

TOKEN_VALUE = "live-token-value"


async def _build_service_with_live_session() -> SessionValidationService:
    user = User(
        id="u1",
        provider_identity=ProviderIdentity(
            auth_provider=AuthProvider.GOOGLE, provider_user_id="sub-1"
        ),
        selected_language=LanguageCode(code="am"),
        daily_xp_target=DailyXPTarget(xp_per_day=40),
        notification_enabled=True,
        created_at=datetime.now(UTC),
    )
    user_repo = FakeUserRepository([user])
    session_repo = FakeAuthSessionRepository()
    now = datetime.now(UTC)
    session = AuthSession(
        id="s1",
        user_id="u1",
        token=SessionToken(value=TOKEN_VALUE, issued_at=now, expires_at=now + timedelta(days=1)),
    )
    await session_repo.add(session)
    return SessionValidationService(session_repo=session_repo, user_repo=user_repo)


class TestGetCurrentUser:
    async def test_missing_header_raises_missing_credentials(self) -> None:
        service = await _build_service_with_live_session()

        with pytest.raises(MissingCredentialsError):
            await get_current_user(authorization=None, service=service)

    async def test_non_bearer_header_raises_missing_credentials(self) -> None:
        service = await _build_service_with_live_session()

        with pytest.raises(MissingCredentialsError):
            await get_current_user(authorization="Basic abc123", service=service)

    async def test_bearer_with_empty_token_raises_missing_credentials(self) -> None:
        service = await _build_service_with_live_session()

        with pytest.raises(MissingCredentialsError):
            await get_current_user(authorization="Bearer ", service=service)

    async def test_unknown_token_raises_invalid_session(self) -> None:
        service = await _build_service_with_live_session()

        with pytest.raises(InvalidSessionError):
            await get_current_user(authorization="Bearer not-a-real-token", service=service)

    async def test_valid_token_returns_the_user(self) -> None:
        service = await _build_service_with_live_session()

        user = await get_current_user(authorization=f"Bearer {TOKEN_VALUE}", service=service)

        assert user.id == "u1"
