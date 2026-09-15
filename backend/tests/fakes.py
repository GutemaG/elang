"""Shared in-memory/fake test doubles.

Per `coding-standards.md`: mock at the network/DB boundary only, never the
domain logic under test. These doubles replace `TokenVerifier` (network) and
the `UserRepository`/`AuthSessionRepository` Protocols (DB) -- never
`AuthenticationService`, `OnboardingAttachmentPolicy`, or
`SessionValidationService` themselves, which are always exercised for real.
"""

from __future__ import annotations

from app.domain.entities import AuthSession, User
from app.domain.value_objects import AuthProvider


class FakeTokenVerifier:
    """Stands in for `GoogleTokenVerifier`/`AppleTokenVerifier`.

    Configure `subject` to succeed with that provider_user_id, or
    `exception` to simulate `InvalidTokenError`/`ExpiredTokenError`/
    `ProviderUnreachableError`. Never makes a real network call.
    """

    def __init__(self, *, subject: str | None = None, exception: Exception | None = None) -> None:
        self.next_subject = subject
        self.next_exception = exception
        self.calls: list[str] = []

    async def verify(self, token: str) -> str:
        self.calls.append(token)
        if self.next_exception is not None:
            raise self.next_exception
        if self.next_subject is None:
            raise AssertionError("FakeTokenVerifier: no subject or exception configured")
        return self.next_subject

    async def aclose(self) -> None:
        """No-op -- matches AppleTokenVerifier's interface for lifespan/teardown symmetry."""


class FakeUserRepository:
    """In-memory stand-in for `app.domain.repositories.UserRepository`."""

    def __init__(self, users: list[User] | None = None) -> None:
        self._users: dict[str, User] = {u.id: u for u in (users or [])}
        self.get_by_id_calls = 0

    async def find_by_provider_identity(
        self, auth_provider: AuthProvider, provider_user_id: str
    ) -> User | None:
        for user in self._users.values():
            if (
                user.provider_identity.auth_provider == auth_provider
                and user.provider_identity.provider_user_id == provider_user_id
            ):
                return user
        return None

    async def add(self, user: User) -> User:
        self._users[user.id] = user
        return user

    async def get_by_id(self, user_id: str) -> User | None:
        self.get_by_id_calls += 1
        return self._users.get(user_id)


class FakeAuthSessionRepository:
    """In-memory stand-in for `app.domain.repositories.AuthSessionRepository`."""

    def __init__(self) -> None:
        self._sessions: dict[str, AuthSession] = {}
        self._session_id_by_token: dict[str, str] = {}

    async def add(self, session: AuthSession) -> AuthSession:
        self._sessions[session.id] = session
        self._session_id_by_token[session.token.value] = session.id
        return session

    async def find_by_token(self, token_value: str) -> AuthSession | None:
        session_id = self._session_id_by_token.get(token_value)
        if session_id is None:
            return None
        return self._sessions.get(session_id)

    async def get_by_id(self, session_id: str) -> AuthSession | None:
        return self._sessions.get(session_id)
