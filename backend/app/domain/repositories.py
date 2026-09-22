"""Repository interfaces (contracts), as `typing.Protocol`s.

Implemented by `app/infrastructure/db/repositories.py`. The domain layer only
depends on these Protocols, never on SQLAlchemy directly.
"""

from __future__ import annotations

from datetime import datetime
from typing import Protocol

from app.domain.entities import AuthSession, User
from app.domain.value_objects import AuthProvider


class UserRepository(Protocol):
    """Entity: `User`."""

    async def find_by_provider_identity(
        self, auth_provider: AuthProvider, provider_user_id: str
    ) -> User | None: ...

    async def add(self, user: User) -> User: ...

    async def get_by_id(self, user_id: str) -> User | None: ...

    async def update(self, user: User) -> User: ...

    async def set_email(self, user_id: str, email: str | None) -> User:
        """Records the provider-verified email from a sign-in (ADR-16).
        Separate from `update` so the authentication path writes only this
        field (User invariants 2 and 5)."""
        ...


class AuthSessionRepository(Protocol):
    """Entity: `AuthSession`.

    `find_by_token` takes the raw token *value* — how that value is matched
    against storage (e.g. hashed at rest, per ADR-1) is an infrastructure-layer
    detail the domain interface deliberately does not expose.
    """

    async def add(self, session: AuthSession) -> AuthSession: ...

    async def find_by_token(self, token_value: str) -> AuthSession | None: ...

    async def get_by_id(self, session_id: str) -> AuthSession | None: ...

    async def extend(self, session_id: str, expires_at: datetime) -> None:
        """Moves a live session's expiry to `expires_at` (sliding renewal)."""
        ...
