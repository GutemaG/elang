"""Repository interfaces (contracts), as `typing.Protocol`s.

Implemented by `app/infrastructure/db/repositories.py`. The domain layer only
depends on these Protocols, never on SQLAlchemy directly.
"""

from __future__ import annotations

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


class AuthSessionRepository(Protocol):
    """Entity: `AuthSession`.

    `find_by_token` takes the raw token *value* — how that value is matched
    against storage (e.g. hashed at rest, per ADR-1) is an infrastructure-layer
    detail the domain interface deliberately does not expose.
    """

    async def add(self, session: AuthSession) -> AuthSession: ...

    async def find_by_token(self, token_value: str) -> AuthSession | None: ...

    async def get_by_id(self, session_id: str) -> AuthSession | None: ...
