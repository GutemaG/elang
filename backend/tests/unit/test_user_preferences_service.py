"""Unit tests: `UserPreferencesService` (bolt `013-user-preferences-service`).

Per `coding-standards.md`, `FakeUserRepository` replaces only the DB
boundary -- `LanguageCode`/`DailyXPTarget`/`OnboardingAttachmentPolicy` are
exercised for real in every test here.
"""

from __future__ import annotations

import uuid
from datetime import UTC, datetime

import pytest

from app.domain.entities import User
from app.domain.exceptions import InvalidPreferenceValueError
from app.domain.services import OnboardingAttachmentPolicy, UserPreferencesService
from app.domain.value_objects import AuthProvider, DailyXPTarget, LanguageCode, ProviderIdentity
from tests.fakes import EN_AM_COURSE_ID, FakeCourseRepository, FakeUserRepository


def _make_user(
    *,
    language_code: str = "am",
    daily_xp_target: int = 40,
    notification_enabled: bool = True,
) -> User:
    return User(
        id=str(uuid.uuid4()),
        provider_identity=ProviderIdentity(
            auth_provider=AuthProvider.GOOGLE, provider_user_id="sub-1"
        ),
        selected_language=LanguageCode(code=language_code),
        daily_xp_target=DailyXPTarget(xp_per_day=daily_xp_target),
        notification_enabled=notification_enabled,
        created_at=datetime.now(UTC),
        active_course_id=EN_AM_COURSE_ID,
    )


def _make_service(user: User) -> tuple[UserPreferencesService, FakeUserRepository]:
    repo = FakeUserRepository([user])
    service = UserPreferencesService(
        user_repo=repo,
        onboarding_policy=OnboardingAttachmentPolicy(),
        course_repo=FakeCourseRepository(),
    )
    return service, repo


class TestUpdatePreferences:
    async def test_all_none_is_a_no_op(self) -> None:
        user = _make_user()
        service, repo = _make_service(user)

        updated = await service.update_preferences(user, None, None, None)

        assert updated.selected_language.code == "am"
        assert updated.daily_xp_target.xp_per_day == 40
        assert updated.notification_enabled is True
        assert repo.update_calls == 1

    async def test_resubmitting_current_values_succeeds_as_no_op(self) -> None:
        user = _make_user(language_code="am", daily_xp_target=40, notification_enabled=True)
        service, _ = _make_service(user)

        updated = await service.update_preferences(user, "am", 15, True)

        # daily_goal_minutes=15 maps to xp_per_day=60 (Serious preset) --
        # resubmitting the *language*/notification unchanged still succeeds
        # even though the goal itself legitimately changes here.
        assert updated.selected_language.code == "am"
        assert updated.daily_xp_target.xp_per_day == 60
        assert updated.notification_enabled is True

    async def test_updates_only_the_language(self) -> None:
        user = _make_user(daily_xp_target=40, notification_enabled=False)
        service, _ = _make_service(user)

        updated = await service.update_preferences(user, "am", None, None)

        assert updated.selected_language.code == "am"
        assert updated.daily_xp_target.xp_per_day == 40
        assert updated.notification_enabled is False

    async def test_updates_only_the_daily_goal(self) -> None:
        user = _make_user(daily_xp_target=40)
        service, _ = _make_service(user)

        updated = await service.update_preferences(user, None, 20, None)

        assert updated.daily_xp_target.xp_per_day == 80

    async def test_updates_only_notification_enabled(self) -> None:
        user = _make_user(notification_enabled=True)
        service, _ = _make_service(user)

        updated = await service.update_preferences(user, None, None, False)

        assert updated.notification_enabled is False

    async def test_can_turn_notification_enabled_back_on(self) -> None:
        user = _make_user(notification_enabled=False)
        service, _ = _make_service(user)

        updated = await service.update_preferences(user, None, None, True)

        assert updated.notification_enabled is True

    async def test_invalid_language_code_raises_invalid_preference_value(self) -> None:
        user = _make_user()
        service, repo = _make_service(user)

        with pytest.raises(InvalidPreferenceValueError):
            await service.update_preferences(user, "xx", None, None)

        assert repo.update_calls == 0

    async def test_invalid_daily_goal_minutes_raises_invalid_preference_value(self) -> None:
        user = _make_user()
        service, repo = _make_service(user)

        with pytest.raises(InvalidPreferenceValueError):
            await service.update_preferences(user, None, 7, None)

        assert repo.update_calls == 0

    async def test_preserves_identity_and_creation_time(self) -> None:
        user = _make_user()
        service, _ = _make_service(user)

        updated = await service.update_preferences(user, None, None, False)

        assert updated.id == user.id
        assert updated.provider_identity == user.provider_identity
        assert updated.created_at == user.created_at
