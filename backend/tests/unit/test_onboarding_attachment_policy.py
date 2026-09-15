"""Unit tests: OnboardingAttachmentPolicy (pure domain logic, no DB/HTTP)."""

from __future__ import annotations

import pytest

from app.domain.exceptions import InvalidPendingSelectionError
from app.domain.services import OnboardingAttachmentPolicy


@pytest.fixture
def policy() -> OnboardingAttachmentPolicy:
    return OnboardingAttachmentPolicy()


class TestMinutesToXpMapping:
    @pytest.mark.parametrize(
        ("minutes", "expected_xp"),
        [(5, 20), (10, 40), (15, 60), (20, 80)],
    )
    def test_all_four_presets(
        self, policy: OnboardingAttachmentPolicy, minutes: int, expected_xp: int
    ) -> None:
        target = policy.map_minutes_to_daily_xp_target(minutes)
        assert target.xp_per_day == expected_xp

    def test_unsupported_minutes_rejected(self, policy: OnboardingAttachmentPolicy) -> None:
        with pytest.raises(ValueError, match="minutes_per_day"):
            policy.map_minutes_to_daily_xp_target(7)


class TestResolveSelectionForNewUser:
    def test_no_pending_selection_uses_documented_defaults(
        self, policy: OnboardingAttachmentPolicy
    ) -> None:
        language, xp_target = policy.resolve_selection_for_new_user(None, None)
        assert language.code == "am"
        assert xp_target.xp_per_day == 40

    def test_valid_pending_selection_is_applied(self, policy: OnboardingAttachmentPolicy) -> None:
        language, xp_target = policy.resolve_selection_for_new_user("am", 15)
        assert language.code == "am"
        assert xp_target.xp_per_day == 60

    def test_malformed_language_on_new_user_path_raises(
        self, policy: OnboardingAttachmentPolicy
    ) -> None:
        """The mirror image of the bolt's bug #1 regression: on the *new*
        -user path, validation must actually run and reject an unsupported
        language -- unlike the returning-user path, where the exact same
        malformed input must be silently ignored (see
        test_authentication_service.py's returning-user tests)."""
        with pytest.raises(InvalidPendingSelectionError):
            policy.resolve_selection_for_new_user("xx", 10)

    def test_unsupported_minutes_on_new_user_path_raises(
        self, policy: OnboardingAttachmentPolicy
    ) -> None:
        with pytest.raises(ValueError, match="minutes_per_day"):
            policy.resolve_selection_for_new_user("am", 7)
