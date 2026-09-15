"""Unit tests: value object invariants (domain layer, no DB, no HTTP)."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

import pytest

from app.domain.exceptions import InvalidPendingSelectionError
from app.domain.value_objects import (
    AuthProvider,
    DailyGoalPreset,
    DailyXPTarget,
    LanguageCode,
    ProviderIdentity,
    SessionToken,
)


class TestProviderIdentity:
    def test_equal_by_provider_and_id_not_identity(self) -> None:
        a = ProviderIdentity(auth_provider=AuthProvider.GOOGLE, provider_user_id="sub-123")
        b = ProviderIdentity(auth_provider=AuthProvider.GOOGLE, provider_user_id="sub-123")
        assert a == b
        assert a is not b

    def test_not_equal_when_provider_user_id_differs(self) -> None:
        a = ProviderIdentity(auth_provider=AuthProvider.GOOGLE, provider_user_id="sub-123")
        b = ProviderIdentity(auth_provider=AuthProvider.GOOGLE, provider_user_id="sub-456")
        assert a != b

    def test_not_equal_when_provider_differs_same_id(self) -> None:
        a = ProviderIdentity(auth_provider=AuthProvider.GOOGLE, provider_user_id="sub-123")
        b = ProviderIdentity(auth_provider=AuthProvider.APPLE, provider_user_id="sub-123")
        assert a != b

    def test_value_object_carries_no_email_field_at_all(self) -> None:
        # Dedup by (provider, id) can never accidentally fall back to
        # email, because there is nowhere for an email to be stored on this
        # value object -- this is enforced structurally, not just by
        # convention.
        identity = ProviderIdentity(
            auth_provider=AuthProvider.APPLE, provider_user_id="apple-sub-1"
        )
        assert not hasattr(identity, "email")

    def test_rejects_empty_provider_user_id(self) -> None:
        with pytest.raises(ValueError, match="provider_user_id"):
            ProviderIdentity(auth_provider=AuthProvider.GOOGLE, provider_user_id="")


class TestLanguageCode:
    def test_accepts_supported_code(self) -> None:
        assert LanguageCode(code="am").code == "am"

    def test_rejects_unsupported_code(self) -> None:
        with pytest.raises(InvalidPendingSelectionError):
            LanguageCode(code="xx")


class TestDailyGoalPreset:
    @pytest.mark.parametrize("minutes", [5, 10, 15, 20])
    def test_accepts_all_four_presets(self, minutes: int) -> None:
        assert DailyGoalPreset(minutes_per_day=minutes).minutes_per_day == minutes

    def test_rejects_arbitrary_minute_value(self) -> None:
        with pytest.raises(ValueError, match="minutes_per_day"):
            DailyGoalPreset(minutes_per_day=7)


class TestDailyXPTarget:
    def test_accepts_positive_value(self) -> None:
        assert DailyXPTarget(xp_per_day=1).xp_per_day == 1

    @pytest.mark.parametrize("value", [0, -1])
    def test_rejects_non_positive_value(self, value: int) -> None:
        with pytest.raises(ValueError, match="positive"):
            DailyXPTarget(xp_per_day=value)


class TestSessionToken:
    def test_not_expired_before_expiry(self) -> None:
        now = datetime.now(UTC)
        token = SessionToken(value="tok", issued_at=now, expires_at=now + timedelta(days=1))
        assert token.is_expired(now) is False

    def test_expired_after_expiry(self) -> None:
        now = datetime.now(UTC)
        token = SessionToken(
            value="tok", issued_at=now - timedelta(days=2), expires_at=now - timedelta(days=1)
        )
        assert token.is_expired(now) is True

    def test_expired_exactly_at_expiry_boundary(self) -> None:
        # is_expired uses `now >= expires_at` -- the exact boundary instant
        # counts as expired, not valid.
        now = datetime.now(UTC)
        token = SessionToken(value="tok", issued_at=now - timedelta(days=1), expires_at=now)
        assert token.is_expired(now) is True
