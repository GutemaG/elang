"""Value objects for the auth service domain (immutable, equality by value).

Pure Python only — zero dependencies on FastAPI, SQLAlchemy, or provider SDKs,
per `ddd-02-technical-design.md`'s layering rule.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from enum import StrEnum

from app.domain.exceptions import InvalidPendingSelectionError

# --- Minutes -> Daily XP Target mapping (ddd-02-technical-design.md, Open Items #1) ---
# Casual=5min, Regular=10min, Serious=15min, Intense=20min.
MINUTES_TO_XP_TARGET: dict[int, int] = {
    5: 20,
    10: 40,
    15: 60,
    20: 80,
}

# --- Defaults applied when no pending onboarding selection arrives at all
# (ddd-02-technical-design.md, Open Items #2). ---
DEFAULT_LANGUAGE_CODE = "am"
DEFAULT_DAILY_XP_TARGET = 40

# The from-language assumed when a client (e.g. the shipped app) sends only a
# language to learn (bolt `024-courses-service`, ADR-12).
DEFAULT_FROM_LANGUAGE_CODE = "en"

# Known language codes (Amharic, Afaan Oromo, English). Whether a language can
# actually be *learned* is decided by a course existing for it (ADR-12), not by
# this set -- e.g. no course teaches English, so learning `en` is rejected.
SUPPORTED_LANGUAGE_CODES: frozenset[str] = frozenset({"am", "om", "en"})


class AuthProvider(StrEnum):
    """The OAuth/identity provider a `ProviderIdentity` belongs to."""

    GOOGLE = "google"
    APPLE = "apple"


@dataclass(frozen=True)
class ProviderIdentity:
    """The `(auth_provider, provider_user_id)` pair — the sole account-dedup key.

    `provider_user_id` is always the provider's stable subject identifier
    (Google's `sub` claim, Apple's stable user identifier) and is never
    derived from or compared against email.
    """

    auth_provider: AuthProvider
    provider_user_id: str

    def __post_init__(self) -> None:
        if not self.provider_user_id:
            raise ValueError("provider_user_id must be a non-empty string")


@dataclass(frozen=True)
class VerifiedIdentity:
    """What a `TokenVerifier` vouches for after checking a provider token.

    `subject` is the provider's stable subject identifier, which becomes
    `ProviderIdentity.provider_user_id`. `email` is set only when the
    provider itself verified it (Google's `email_verified`); it is used for
    the admin allow-list (ADR-16) and never for identifying an account.
    """

    subject: str
    email: str | None = None


@dataclass(frozen=True)
class LanguageCode:
    """A supported course language code (e.g. `am` for Amharic).

    An unsupported/invalid code is rejected with `InvalidPendingSelectionError`
    rather than silently defaulted, per the domain model's constraint on
    `PendingOnboardingSelection`.
    """

    code: str

    def __post_init__(self) -> None:
        if self.code not in SUPPORTED_LANGUAGE_CODES:
            raise InvalidPendingSelectionError(f"Unsupported language code: {self.code!r}")


@dataclass(frozen=True)
class DailyGoalPreset:
    """One of the four fixed daily-goal presets (Casual/Regular/Serious/Intense)."""

    minutes_per_day: int

    def __post_init__(self) -> None:
        if self.minutes_per_day not in MINUTES_TO_XP_TARGET:
            raise ValueError(
                f"minutes_per_day must be one of {sorted(MINUTES_TO_XP_TARGET)}, "
                f"got {self.minutes_per_day}"
            )


@dataclass(frozen=True)
class DailyXPTarget:
    """The server-side numeric XP target a `DailyGoalPreset` maps to."""

    xp_per_day: int

    def __post_init__(self) -> None:
        if self.xp_per_day <= 0:
            raise ValueError("xp_per_day must be a positive integer")


@dataclass(frozen=True)
class PendingOnboardingSelection:
    """Client-held, pre-auth language + daily-goal choice.

    Not a persisted entity — arrives as an optional request payload alongside
    the auth token on first sign-in only. Has no effect when sign-in resolves
    to an existing (returning) `User`.
    """

    language: LanguageCode
    daily_goal: DailyGoalPreset
    # Bolt 024: the language the learner speaks (the course's from-language).
    from_language: LanguageCode = LanguageCode(code=DEFAULT_FROM_LANGUAGE_CODE)


@dataclass(frozen=True)
class SessionToken:
    """An opaque, high-entropy session credential.

    Carries no decodable identity claims. Must never appear in logs. Storage
    representation (hashed at rest, per ADR-1) is an infrastructure-layer
    concern — this value object always holds the raw value in memory.
    """

    value: str
    issued_at: datetime
    expires_at: datetime

    def is_expired(self, now: datetime) -> bool:
        return now >= self.expires_at
