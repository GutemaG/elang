"""Domain events for the auth service.

Not wired to a message bus/event store in this bolt (Phase 1 has no consumer
yet). Implemented as structured log entries at the application layer, in the
exact payload shape defined here, per `ddd-02-technical-design.md`. This keeps
the event vocabulary ready for a real event bus later (e.g. `gamification-engine`
subscribing to `UserRegistered`) without building speculative pub/sub
infrastructure now.

None of these payloads may ever include a raw token value or provider claim
contents.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime

from app.domain.value_objects import AuthProvider


@dataclass(frozen=True)
class UserRegistered:
    """Trigger: first successful authentication for a `provider_identity`
    never seen before (new account path)."""

    user_id: str
    auth_provider: AuthProvider
    selected_language: str
    daily_xp_target: int
    registered_at: datetime


@dataclass(frozen=True)
class UserAuthenticated:
    """Trigger: successful authentication resolving to an existing `User`
    (returning-user path). Carries no selection/goal data since none changes
    on this path."""

    user_id: str
    auth_provider: AuthProvider
    authenticated_at: datetime


@dataclass(frozen=True)
class SessionIssued:
    """Trigger: any successful authentication (new or returning user).

    Deliberately excludes the raw token value — never log or propagate the
    secret itself.
    """

    session_id: str
    user_id: str
    issued_at: datetime
    expires_at: datetime


@dataclass(frozen=True)
class AuthenticationRejected:
    """Trigger: an invalid, expired, or tampered provider token, or a
    pending-selection payload with an unsupported language code.

    No `user_id` (none reliably identified) and no token/claim contents.
    """

    auth_provider: AuthProvider | None
    reason: str
    attempted_at: datetime
