"""Unit tests: AuthenticationService, with fake TokenVerifier/repositories.

Per `coding-standards.md`, these fakes replace only the network/DB boundary
-- the real `OnboardingAttachmentPolicy` and domain entities/value objects
are exercised for real in every test here.
"""

from __future__ import annotations

import uuid
from datetime import UTC, datetime

import pytest

from app.domain.entities import User
from app.domain.exceptions import (
    InvalidPendingSelectionError,
    InvalidTokenError,
    ProviderUnreachableError,
)
from app.domain.services import AuthenticationService, OnboardingAttachmentPolicy
from app.domain.value_objects import (
    AuthProvider,
    DailyXPTarget,
    LanguageCode,
    ProviderIdentity,
)
from tests.fakes import (
    EN_AM_COURSE_ID,
    FakeAuthSessionRepository,
    FakeCourseRepository,
    FakeTokenVerifier,
    FakeUserRepository,
)


def _make_service(
    google_verifier: FakeTokenVerifier | None = None,
    apple_verifier: FakeTokenVerifier | None = None,
    user_repo: FakeUserRepository | None = None,
    session_repo: FakeAuthSessionRepository | None = None,
) -> tuple[AuthenticationService, FakeUserRepository, FakeAuthSessionRepository]:
    user_repo = user_repo if user_repo is not None else FakeUserRepository()
    session_repo = session_repo if session_repo is not None else FakeAuthSessionRepository()
    service = AuthenticationService(
        google_verifier=google_verifier or FakeTokenVerifier(),
        apple_verifier=apple_verifier or FakeTokenVerifier(),
        user_repo=user_repo,
        session_repo=session_repo,
        onboarding_policy=OnboardingAttachmentPolicy(),
        course_repo=FakeCourseRepository(),
    )
    return service, user_repo, session_repo


class TestNewUserPath:
    async def test_creates_user_with_pending_selection_attached(self) -> None:
        google_verifier = FakeTokenVerifier(subject="google-sub-1")
        service, user_repo, session_repo = _make_service(google_verifier=google_verifier)

        result = await service.authenticate_with_google("id-token", "am", 15)

        assert result.is_new_user is True
        assert result.user.selected_language.code == "am"
        assert result.user.daily_xp_target.xp_per_day == 60
        assert result.user.provider_identity == ProviderIdentity(
            auth_provider=AuthProvider.GOOGLE, provider_user_id="google-sub-1"
        )
        assert len(user_repo._users) == 1
        assert len(session_repo._sessions) == 1

    async def test_creates_user_with_defaults_when_no_pending_selection(self) -> None:
        service, _, _ = _make_service(google_verifier=FakeTokenVerifier(subject="sub-2"))

        result = await service.authenticate_with_google("id-token", None, None)

        assert result.is_new_user is True
        assert result.user.selected_language.code == "am"
        assert result.user.daily_xp_target.xp_per_day == 40

    async def test_malformed_language_rejected_and_no_account_created(self) -> None:
        service, user_repo, session_repo = _make_service(
            google_verifier=FakeTokenVerifier(subject="sub-3")
        )

        with pytest.raises(InvalidPendingSelectionError):
            await service.authenticate_with_google("id-token", "xx", 10)

        assert len(user_repo._users) == 0
        assert len(session_repo._sessions) == 0

    async def test_session_issuance_shape(self) -> None:
        service, _, _ = _make_service(google_verifier=FakeTokenVerifier(subject="sub-4"))

        result = await service.authenticate_with_google("id-token", None, None)

        assert result.raw_session_token
        assert result.session.token.value == result.raw_session_token
        assert result.session.token.expires_at > result.session.token.issued_at
        assert result.session.user_id == result.user.id


class TestReturningUserPath:
    def _seed_existing_user(
        self,
        provider_user_id: str = "google-sub-existing",
        auth_provider: AuthProvider = AuthProvider.GOOGLE,
    ) -> tuple[FakeUserRepository, User]:
        existing = User(
            id=str(uuid.uuid4()),
            provider_identity=ProviderIdentity(
                auth_provider=auth_provider, provider_user_id=provider_user_id
            ),
            selected_language=LanguageCode(code="am"),
            daily_xp_target=DailyXPTarget(xp_per_day=40),
            notification_enabled=True,
            created_at=datetime.now(UTC),
            active_course_id=EN_AM_COURSE_ID,
        )
        return FakeUserRepository([existing]), existing

    async def test_pending_selection_ignored_for_returning_user(self) -> None:
        user_repo, existing = self._seed_existing_user()
        google_verifier = FakeTokenVerifier(subject=existing.provider_identity.provider_user_id)
        service, _, _ = _make_service(google_verifier=google_verifier, user_repo=user_repo)

        result = await service.authenticate_with_google("id-token", "am", 20)

        assert result.is_new_user is False
        assert result.user.id == existing.id
        # Not overwritten -- still the originally-seeded values, not the
        # pending selection's (am/20min -> 80xp) values.
        assert result.user.selected_language.code == "am"
        assert result.user.daily_xp_target.xp_per_day == 40

    async def test_malformed_pending_selection_causes_no_error_for_returning_user(self) -> None:
        """Bug #1 regression (implementation-notes.md 'Key Decisions'):
        pending-selection validation must be skipped ENTIRELY for returning
        users, so even a malformed/unsupported language must not raise."""
        user_repo, existing = self._seed_existing_user()
        google_verifier = FakeTokenVerifier(subject=existing.provider_identity.provider_user_id)
        service, _, session_repo = _make_service(
            google_verifier=google_verifier, user_repo=user_repo
        )

        result = await service.authenticate_with_google("id-token", "totally-not-a-language", 999)

        assert result.is_new_user is False
        assert result.user.id == existing.id
        assert len(session_repo._sessions) == 1

    async def test_returning_user_via_apple_matched_by_stable_id(self) -> None:
        user_repo, existing = self._seed_existing_user(
            provider_user_id="apple-stable-id-1", auth_provider=AuthProvider.APPLE
        )
        apple_verifier = FakeTokenVerifier(subject="apple-stable-id-1")
        service, _, _ = _make_service(apple_verifier=apple_verifier, user_repo=user_repo)

        result = await service.authenticate_with_apple("identity-token", None, None)

        assert result.is_new_user is False
        assert result.user.id == existing.id


class TestTokenVerificationFailures:
    async def test_invalid_token_propagates_and_creates_nothing(self) -> None:
        google_verifier = FakeTokenVerifier(exception=InvalidTokenError("bad token"))
        service, user_repo, session_repo = _make_service(google_verifier=google_verifier)

        with pytest.raises(InvalidTokenError):
            await service.authenticate_with_google("bad-token", None, None)

        assert len(user_repo._users) == 0
        assert len(session_repo._sessions) == 0

    async def test_provider_unreachable_propagates(self) -> None:
        google_verifier = FakeTokenVerifier(exception=ProviderUnreachableError("down"))
        service, _, _ = _make_service(google_verifier=google_verifier)

        with pytest.raises(ProviderUnreachableError):
            await service.authenticate_with_google("token", None, None)
