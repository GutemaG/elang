"""Domain services for the auth service.

Pure domain orchestration — no FastAPI, SQLAlchemy, or provider-SDK imports.
`TokenVerifier` is a Protocol implemented by the infrastructure layer's
`GoogleTokenVerifier`/`AppleTokenVerifier`; this module only depends on the
Protocol, per the layering rule in `ddd-02-technical-design.md`.
"""

from __future__ import annotations

import secrets
import uuid
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from typing import Protocol

from app.domain.entities import AuthSession, User
from app.domain.exceptions import InvalidPendingSelectionError, InvalidPreferenceValueError
from app.domain.repositories import AuthSessionRepository, UserRepository
from app.domain.value_objects import (
    DEFAULT_DAILY_XP_TARGET,
    DEFAULT_LANGUAGE_CODE,
    MINUTES_TO_XP_TARGET,
    AuthProvider,
    DailyGoalPreset,
    DailyXPTarget,
    LanguageCode,
    PendingOnboardingSelection,
    ProviderIdentity,
    SessionToken,
)

# Session lifetime: an implementation-level constant (per
# ddd-02-technical-design.md's "New Open Questions" note that exact expiry
# policy is a Stage 4 detail, not a Stage 2 architectural decision).
DEFAULT_SESSION_TTL = timedelta(days=30)


class TokenVerifier(Protocol):
    """Verifies a provider credential and returns the provider's stable
    subject identifier (Google's `sub`, Apple's stable user identifier).

    Implementations raise `InvalidTokenError`, `ExpiredTokenError`, or
    `ProviderUnreachableError` (from `app.domain.exceptions`) on failure —
    never return a sentinel for a failed verification.
    """

    async def verify(self, token: str) -> str: ...


@dataclass(frozen=True)
class AuthResult:
    """Result of a successful authentication, returned by `AuthenticationService`."""

    user: User
    session: AuthSession
    raw_session_token: str
    is_new_user: bool


class OnboardingAttachmentPolicy:
    """Pure domain logic — no external dependencies.

    Resolves the `LanguageCode`/`DailyXPTarget` to attach to a *newly created*
    `User` only. `AuthenticationService` must not consult this when resolving
    to an existing `User` (per the domain model's explicit constraint).
    """

    def map_minutes_to_daily_xp_target(self, minutes_per_day: int) -> DailyXPTarget:
        """Minutes -> Daily XP Target, per the fixed lookup table:

        Casual=5min -> 20, Regular=10min -> 40, Serious=15min -> 60,
        Intense=20min -> 80 (ddd-02-technical-design.md, Open Items #1).
        """
        preset = DailyGoalPreset(minutes_per_day=minutes_per_day)
        return DailyXPTarget(xp_per_day=MINUTES_TO_XP_TARGET[preset.minutes_per_day])

    def resolve_selection_for_new_user(
        self,
        pending_language_code: str | None,
        pending_daily_goal_minutes: int | None,
    ) -> tuple[LanguageCode, DailyXPTarget]:
        """Resolves what a brand-new `User` should be created with.

        Takes the *raw*, unvalidated request fields rather than an already
        -constructed `PendingOnboardingSelection` -- validation (which can
        raise `InvalidPendingSelectionError`) must only happen here, on the
        account-creation branch, never before the caller knows whether this
        is a new or returning user. A returning user's pending selection
        "has no effect whatsoever" per the domain model, including no
        validation error for a malformed one.

        No pending selection at all -> documented defaults (`am` / 40 XP,
        ddd-02-technical-design.md Open Items #2), not an error.
        """
        if pending_language_code is None or pending_daily_goal_minutes is None:
            return (
                LanguageCode(code=DEFAULT_LANGUAGE_CODE),
                DailyXPTarget(xp_per_day=DEFAULT_DAILY_XP_TARGET),
            )
        selection = PendingOnboardingSelection(
            language=LanguageCode(code=pending_language_code),
            daily_goal=DailyGoalPreset(minutes_per_day=pending_daily_goal_minutes),
        )
        xp_target = self.map_minutes_to_daily_xp_target(selection.daily_goal.minutes_per_day)
        return selection.language, xp_target


class SessionValidationService:
    """Looks up an `AuthSession` by token, checks expiry, and only then loads
    the referenced `User`. An expired or unknown token validates as `None`,
    never as an error that surfaces account data.
    """

    def __init__(self, session_repo: AuthSessionRepository, user_repo: UserRepository) -> None:
        self._session_repo = session_repo
        self._user_repo = user_repo

    async def validate(self, token_value: str) -> User | None:
        session = await self._session_repo.find_by_token(token_value)
        if session is None:
            return None
        if session.token.is_expired(datetime.now(UTC)):
            return None
        return await self._user_repo.get_by_id(session.user_id)


class AuthenticationService:
    """Encapsulates the shared "verify token -> find-or-create User by
    ProviderIdentity -> attach pending selection only if newly created ->
    issue AuthSession" flow common to stories 002 and 003.
    """

    def __init__(
        self,
        google_verifier: TokenVerifier,
        apple_verifier: TokenVerifier,
        user_repo: UserRepository,
        session_repo: AuthSessionRepository,
        onboarding_policy: OnboardingAttachmentPolicy,
        session_ttl: timedelta = DEFAULT_SESSION_TTL,
    ) -> None:
        self._verifiers: dict[AuthProvider, TokenVerifier] = {
            AuthProvider.GOOGLE: google_verifier,
            AuthProvider.APPLE: apple_verifier,
        }
        self._user_repo = user_repo
        self._session_repo = session_repo
        self._onboarding_policy = onboarding_policy
        self._session_ttl = session_ttl

    async def authenticate_with_google(
        self,
        id_token: str,
        pending_language_code: str | None,
        pending_daily_goal_minutes: int | None,
    ) -> AuthResult:
        return await self._authenticate(
            AuthProvider.GOOGLE,
            id_token,
            pending_language_code,
            pending_daily_goal_minutes,
        )

    async def authenticate_with_apple(
        self,
        identity_token: str,
        pending_language_code: str | None,
        pending_daily_goal_minutes: int | None,
    ) -> AuthResult:
        return await self._authenticate(
            AuthProvider.APPLE,
            identity_token,
            pending_language_code,
            pending_daily_goal_minutes,
        )

    async def _authenticate(
        self,
        auth_provider: AuthProvider,
        token: str,
        pending_language_code: str | None,
        pending_daily_goal_minutes: int | None,
    ) -> AuthResult:
        verifier = self._verifiers[auth_provider]
        # Raises InvalidTokenError / ExpiredTokenError / ProviderUnreachableError
        # on failure -- caller (application layer) is responsible for logging
        # AuthenticationRejected and re-raising for the presentation layer.
        provider_user_id = await verifier.verify(token)
        identity = ProviderIdentity(auth_provider=auth_provider, provider_user_id=provider_user_id)

        existing_user = await self._user_repo.find_by_provider_identity(
            identity.auth_provider, identity.provider_user_id
        )
        is_new_user = existing_user is None

        if existing_user is not None:
            user = existing_user
        else:
            # Only ever consulted on the account-creation branch -- pending
            # selections on a returning-user sign-in are ignored entirely,
            # including skipping validation of a malformed one.
            language, xp_target = self._onboarding_policy.resolve_selection_for_new_user(
                pending_language_code, pending_daily_goal_minutes
            )
            new_user = User(
                id=str(uuid.uuid4()),
                provider_identity=identity,
                selected_language=language,
                daily_xp_target=xp_target,
                notification_enabled=True,
                created_at=datetime.now(UTC),
            )
            user = await self._user_repo.add(new_user)

        raw_token = secrets.token_urlsafe(32)
        now = datetime.now(UTC)
        session_token = SessionToken(
            value=raw_token, issued_at=now, expires_at=now + self._session_ttl
        )
        new_session = AuthSession(id=str(uuid.uuid4()), user_id=user.id, token=session_token)
        session = await self._session_repo.add(new_session)

        return AuthResult(
            user=user,
            session=session,
            raw_session_token=raw_token,
            is_new_user=is_new_user,
        )


class UserPreferencesService:
    """Bolt `013-user-preferences-service` (FR-2/FR-3/FR-4). The one
    sanctioned post-creation mutation path for `User.selected_language`/
    `daily_xp_target`, per ADR-7. Also freely updates `notification_enabled`,
    which carries no write-once restriction.

    Reuses `OnboardingAttachmentPolicy.map_minutes_to_daily_xp_target` for
    the minutes->XP mapping so the allowed daily-goal values stay defined
    in exactly one place (the same lookup table onboarding already uses) --
    this service introduces no new allowed values for either field.
    """

    def __init__(
        self, user_repo: UserRepository, onboarding_policy: OnboardingAttachmentPolicy
    ) -> None:
        self._user_repo = user_repo
        self._onboarding_policy = onboarding_policy

    async def update_preferences(
        self,
        user: User,
        language_code: str | None,
        daily_goal_minutes: int | None,
        notification_enabled: bool | None,
    ) -> User:
        """Applies only the non-`None` fields; omitted fields, and fields
        resubmitted with their current value, are a no-op (per story
        001-update-daily-goal-and-language's edge cases).

        Raises `InvalidPreferenceValueError` (422) for an unsupported
        language code or daily-goal value -- re-wrapping the value objects'
        own validation errors rather than letting sign-up's
        `InvalidPendingSelectionError` (400) leak into this endpoint's
        distinct error contract.
        """
        language = user.selected_language
        daily_xp_target = user.daily_xp_target
        try:
            if language_code is not None:
                language = LanguageCode(code=language_code)
            if daily_goal_minutes is not None:
                daily_xp_target = self._onboarding_policy.map_minutes_to_daily_xp_target(
                    daily_goal_minutes
                )
        except (InvalidPendingSelectionError, ValueError) as exc:
            raise InvalidPreferenceValueError(str(exc)) from exc

        updated_user = User(
            id=user.id,
            provider_identity=user.provider_identity,
            selected_language=language,
            daily_xp_target=daily_xp_target,
            notification_enabled=(
                user.notification_enabled
                if notification_enabled is None
                else notification_enabled
            ),
            created_at=user.created_at,
        )
        return await self._user_repo.update(updated_user)
