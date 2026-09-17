"""Security-relevant tests: session token secrecy at rest (ADR-1), and
structured, non-crashing error handling for missing/malformed credentials.
"""

from __future__ import annotations

import hashlib
import uuid
from collections.abc import Callable
from datetime import UTC, datetime, timedelta

from fastapi.testclient import TestClient
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
from app.infrastructure.db.models import AuthSessionModel
from app.infrastructure.db.repositories import (
    SqlAlchemyAuthSessionRepository,
    SqlAlchemyUserRepository,
)
from tests.fakes import FakeTokenVerifier

ClientFactory = Callable[[object, object], TestClient]


def _make_user(provider_user_id: str) -> User:
    return User(
        id=str(uuid.uuid4()),
        provider_identity=ProviderIdentity(
            auth_provider=AuthProvider.GOOGLE, provider_user_id=provider_user_id
        ),
        selected_language=LanguageCode(code="am"),
        daily_xp_target=DailyXPTarget(xp_per_day=40),
        notification_enabled=True,
        created_at=datetime.now(UTC),
    )


class TestSessionTokenSecrecyAtRest:
    async def test_stored_token_hash_is_not_the_raw_token(self, db_session: AsyncSession) -> None:
        user = _make_user("sub-sec-1")
        await SqlAlchemyUserRepository(db_session).add(user)

        raw_token = "super-secret-raw-token-value"
        session = AuthSession(
            id=str(uuid.uuid4()),
            user_id=user.id,
            token=SessionToken(
                value=raw_token,
                issued_at=datetime.now(UTC),
                expires_at=datetime.now(UTC) + timedelta(days=1),
            ),
        )
        await SqlAlchemyAuthSessionRepository(db_session).add(session)
        await db_session.commit()

        # Read the raw row directly -- simulates "what a DB leak exposes".
        stmt = select(AuthSessionModel).where(AuthSessionModel.user_id == user.id)
        result = await db_session.execute(stmt)
        model = result.scalar_one()

        assert model.token_hash != raw_token
        assert model.token_hash == hashlib.sha256(raw_token.encode("utf-8")).hexdigest()

    async def test_get_by_id_never_reconstructs_a_usable_raw_token(
        self, db_session: AsyncSession
    ) -> None:
        user = _make_user("sub-sec-2")
        await SqlAlchemyUserRepository(db_session).add(user)
        session_repo = SqlAlchemyAuthSessionRepository(db_session)
        session = AuthSession(
            id=str(uuid.uuid4()),
            user_id=user.id,
            token=SessionToken(
                value="another-raw-token",
                issued_at=datetime.now(UTC),
                expires_at=datetime.now(UTC) + timedelta(days=1),
            ),
        )
        await session_repo.add(session)
        await db_session.commit()

        found = await session_repo.get_by_id(session.id)

        # The only lookup path that yields a live, usable SessionToken is
        # find_by_token with the raw value the client itself presented --
        # get_by_id (metadata-only) must never hand back a recoverable token.
        assert found is not None
        assert found.token.value == ""

    def test_session_token_never_returned_by_the_session_endpoint(
        self, make_client: ClientFactory
    ) -> None:
        """The `/auth/session` response never includes the raw token back
        to the client -- it's returned exactly once, at issuance."""
        client = make_client(FakeTokenVerifier(subject="google-sec-endpoint"), FakeTokenVerifier())
        auth_response = client.post("/api/v1/auth/google", json={"id_token": "t"})
        token = auth_response.json()["session_token"]

        response = client.get("/api/v1/auth/session", headers={"Authorization": f"Bearer {token}"})

        assert response.status_code == 200
        assert "session_token" not in response.json()
        assert "token" not in response.json()


class TestMissingCredentialsHandling:
    def test_missing_header_is_documented_401_not_a_crash(self, make_client: ClientFactory) -> None:
        client = make_client(FakeTokenVerifier(), FakeTokenVerifier())

        response = client.get("/api/v1/auth/session")

        assert response.status_code == 401
        body = response.json()
        assert body["error_code"] == "missing_credentials"
        assert "message" in body

    def test_non_bearer_scheme_is_documented_401_not_a_crash(
        self, make_client: ClientFactory
    ) -> None:
        client = make_client(FakeTokenVerifier(), FakeTokenVerifier())

        response = client.get(
            "/api/v1/auth/session", headers={"Authorization": "Basic dXNlcjpwYXNz"}
        )

        assert response.status_code == 401
        assert response.json()["error_code"] == "missing_credentials"

    def test_bearer_with_empty_token_is_documented_401_not_a_crash(
        self, make_client: ClientFactory
    ) -> None:
        client = make_client(FakeTokenVerifier(), FakeTokenVerifier())

        response = client.get("/api/v1/auth/session", headers={"Authorization": "Bearer "})

        assert response.status_code == 401
        assert response.json()["error_code"] == "missing_credentials"
