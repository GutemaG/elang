"""Unit tests for `CompletionTimestampValidator` (bolt 008, story
002-timestamped-completion-for-streak-attribution): bounds a client-supplied
offline-completion timestamp against reality before it's trusted for
streak/XP-day attribution.
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

import pytest

from app.domain.lesson.exceptions import InvalidCompletionTimestampError
from app.domain.lesson.services import CompletionTimestampValidator

_ACCOUNT_CREATED_AT = datetime(2026, 1, 1, tzinfo=UTC)
_NOW = datetime(2026, 9, 16, 12, 0, tzinfo=UTC)


class TestCompletionTimestampValidator:
    def test_accepts_a_timestamp_equal_to_now(self) -> None:
        CompletionTimestampValidator().validate(_NOW, _ACCOUNT_CREATED_AT, _NOW)

    def test_accepts_a_timestamp_within_the_future_clock_skew_allowance(self) -> None:
        slightly_ahead = _NOW + timedelta(minutes=4)
        CompletionTimestampValidator().validate(slightly_ahead, _ACCOUNT_CREATED_AT, _NOW)

    def test_rejects_a_timestamp_beyond_the_future_clock_skew_allowance(self) -> None:
        too_far_ahead = _NOW + timedelta(minutes=6)
        with pytest.raises(InvalidCompletionTimestampError):
            CompletionTimestampValidator().validate(too_far_ahead, _ACCOUNT_CREATED_AT, _NOW)

    def test_accepts_a_timestamp_from_immediately_after_account_creation(self) -> None:
        just_after_creation = _ACCOUNT_CREATED_AT + timedelta(seconds=1)
        CompletionTimestampValidator().validate(just_after_creation, _ACCOUNT_CREATED_AT, _NOW)

    def test_rejects_a_timestamp_that_predates_account_creation(self) -> None:
        before_creation = _ACCOUNT_CREATED_AT - timedelta(days=1)
        with pytest.raises(InvalidCompletionTimestampError):
            CompletionTimestampValidator().validate(before_creation, _ACCOUNT_CREATED_AT, _NOW)

    def test_accepts_a_timestamp_arbitrarily_far_in_the_past(self) -> None:
        # No upper bound on staleness is deliberate (requirements.md FR-3):
        # supporting long offline gaps without penalizing them is the point,
        # so a completion from months ago (but after account creation) is
        # still valid.
        long_ago_but_after_creation = _ACCOUNT_CREATED_AT + timedelta(days=1)
        far_future_now = _NOW + timedelta(days=180)
        CompletionTimestampValidator().validate(
            long_ago_but_after_creation, _ACCOUNT_CREATED_AT, far_future_now
        )
