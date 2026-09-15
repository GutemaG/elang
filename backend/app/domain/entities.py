"""Aggregate roots for the auth service domain.

Pure Python only — no framework/DB imports, per the layering rule in
`ddd-02-technical-design.md`.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime

from app.domain.value_objects import (
    DailyXPTarget,
    LanguageCode,
    ProviderIdentity,
    SessionToken,
)


@dataclass
class User:
    """Aggregate Root. Invariants (enforced by domain services / repositories):

    1. `provider_identity` is globally unique across all users (sole dedup key).
    2. `selected_language` and `daily_xp_target` are written exactly once, at
       creation, and never overwritten by a later authentication.
    3. A `User` cannot exist without a valid, non-empty `provider_user_id`
       (enforced by `ProviderIdentity.__post_init__`).
    """

    id: str
    provider_identity: ProviderIdentity
    selected_language: LanguageCode
    daily_xp_target: DailyXPTarget
    created_at: datetime


@dataclass
class AuthSession:
    """Aggregate Root, independent of `User`'s transactional boundary.

    `user_id` is a plain reference, not a loaded `User`, so that validating a
    session never mutates or requires loading the referenced `User`. Invariants:

    1. `token.value` is globally unique.
    2. `user_id` must correspond to an existing `User` at issuance time
       (enforced by the application/service layer, not this entity).
    3. An expired or otherwise invalid token fails validation cleanly without
       ever loading or exposing `User` data.
    """

    id: str
    user_id: str
    token: SessionToken
