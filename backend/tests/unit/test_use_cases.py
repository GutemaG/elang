"""Unit tests: the application layer (`app/application/use_cases.py`)
directly, with fake `TokenVerifier`/repositories -- no DB, no HTTP.

These exist alongside the full endpoint tests in
`tests/integration/test_auth_endpoints.py` (which exercise the very same
use-case functions indirectly, through the FastAPI router) specifically so
the use cases' success-path return statements are also covered from a
normal pytest-asyncio call, not only from inside `TestClient`'s background
thread (where `coverage.py` can under-report the final line of a function).
"""

from __future__ import annotations

import pytest

from app.application.use_cases import (
    PendingSelectionInput,
    authenticate_with_apple,
    authenticate_with_google,
    validate_session,
)
from app.domain.exceptions import InvalidTokenError
from app.domain.services import (
    AuthenticationService,
    OnboardingAttachmentPolicy,
    SessionValidationService,
)
from tests.fakes import (
    FakeAuthSessionRepository,
    FakeCourseRepository,
    FakeTokenVerifier,
    FakeUserRepository,
)


def _make_service(
    google_verifier: FakeTokenVerifier, apple_verifier: FakeTokenVerifier
) -> AuthenticationService:
    return AuthenticationService(
        google_verifier=google_verifier,
        apple_verifier=apple_verifier,
        user_repo=FakeUserRepository(),
        session_repo=FakeAuthSessionRepository(),
        onboarding_policy=OnboardingAttachmentPolicy(),
        course_repo=FakeCourseRepository(),
    )


class TestAuthenticateWithGoogleUseCase:
    async def test_success_returns_auth_result(self) -> None:
        service = _make_service(FakeTokenVerifier(subject="uc-google-1"), FakeTokenVerifier())

        result = await authenticate_with_google(
            service, "id-token", PendingSelectionInput(language="am", daily_goal_minutes=10)
        )

        assert result.is_new_user is True
        assert result.user.selected_language.code == "am"

    async def test_success_with_no_pending_selection(self) -> None:
        service = _make_service(FakeTokenVerifier(subject="uc-google-2"), FakeTokenVerifier())

        result = await authenticate_with_google(service, "id-token", None)

        assert result.is_new_user is True
        assert result.user.daily_xp_target.xp_per_day == 40

    async def test_rejection_propagates(self) -> None:
        service = _make_service(
            FakeTokenVerifier(exception=InvalidTokenError("bad")), FakeTokenVerifier()
        )

        with pytest.raises(InvalidTokenError):
            await authenticate_with_google(service, "bad-token", None)


class TestAuthenticateWithAppleUseCase:
    async def test_success_returns_auth_result(self) -> None:
        service = _make_service(FakeTokenVerifier(), FakeTokenVerifier(subject="uc-apple-1"))

        result = await authenticate_with_apple(
            service, "identity-token", PendingSelectionInput(language="am", daily_goal_minutes=20)
        )

        assert result.is_new_user is True
        assert result.user.daily_xp_target.xp_per_day == 80

    async def test_rejection_propagates(self) -> None:
        service = _make_service(
            FakeTokenVerifier(), FakeTokenVerifier(exception=InvalidTokenError("bad"))
        )

        with pytest.raises(InvalidTokenError):
            await authenticate_with_apple(service, "bad-token", None)


class TestValidateSessionUseCase:
    async def test_unknown_token_returns_none(self) -> None:
        service = SessionValidationService(
            session_repo=FakeAuthSessionRepository(), user_repo=FakeUserRepository()
        )

        result = await validate_session(service, "never-issued")

        assert result is None
