"""Unit tests for `BeanLedger` (bolt 005): lazy regeneration, consumption
bounded by the regenerated balance (ADR-5), and refill.
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

import pytest

from app.domain.lesson.entities import UserBeans
from app.domain.lesson.exceptions import BeansExhaustedError
from app.domain.lesson.services import BeanLedger
from app.domain.lesson.value_objects import BEAN_REGEN_MINUTES, BEANS_MAX

_NOW = datetime(2026, 9, 16, 12, 0, tzinfo=UTC)


def _beans(current_count: int, last_regen_at: datetime = _NOW) -> UserBeans:
    return UserBeans(user_id="u1", current_count=current_count, last_regen_at=last_regen_at)


class TestRegenerate:
    def test_no_change_when_already_full(self) -> None:
        beans = _beans(BEANS_MAX, _NOW - timedelta(hours=10))

        result = BeanLedger().regenerate(beans, _NOW)

        assert result.current_count == BEANS_MAX
        assert result.last_regen_at == beans.last_regen_at

    def test_no_change_when_less_than_one_interval_has_passed(self) -> None:
        beans = _beans(2, _NOW - timedelta(minutes=BEAN_REGEN_MINUTES - 1))

        result = BeanLedger().regenerate(beans, _NOW)

        assert result.current_count == 2
        assert result.last_regen_at == beans.last_regen_at

    def test_regenerates_one_bean_per_whole_interval_elapsed(self) -> None:
        beans = _beans(2, _NOW - timedelta(minutes=BEAN_REGEN_MINUTES * 2))

        result = BeanLedger().regenerate(beans, _NOW)

        assert result.current_count == 4
        assert result.last_regen_at == _NOW

    def test_caps_at_beans_max_and_preserves_leftover_partial_progress(self) -> None:
        # 3 intervals have passed but only 2 beans were missing -- the
        # excess interval's worth of elapsed time should not be "spent"
        # advancing last_regen_at past what was actually needed.
        start = _NOW - timedelta(minutes=BEAN_REGEN_MINUTES * 3)
        beans = _beans(BEANS_MAX - 2, start)

        result = BeanLedger().regenerate(beans, _NOW)

        assert result.current_count == BEANS_MAX
        assert result.last_regen_at == start + timedelta(minutes=BEAN_REGEN_MINUTES * 2)

    def test_does_not_regenerate_backwards_for_a_future_last_regen_at(self) -> None:
        # Clock skew: last_regen_at is in the future relative to `now`.
        # Never treat negative elapsed time as a positive regen amount.
        beans = _beans(2, _NOW + timedelta(hours=1))

        result = BeanLedger().regenerate(beans, _NOW)

        assert result.current_count == 2


class TestNextBeanAt:
    def test_none_when_already_full(self) -> None:
        assert BeanLedger().next_bean_at(_beans(BEANS_MAX)) is None

    def test_last_regen_at_plus_one_interval_when_not_full(self) -> None:
        beans = _beans(2, _NOW)

        assert BeanLedger().next_bean_at(beans) == _NOW + timedelta(minutes=BEAN_REGEN_MINUTES)


class TestConsume:
    def test_subtracts_wrong_count_after_regenerating(self) -> None:
        beans = _beans(2, _NOW - timedelta(minutes=BEAN_REGEN_MINUTES))  # regenerates to 3

        result = BeanLedger().consume(beans, wrong_count=1, now=_NOW)

        assert result.current_count == 2

    def test_zero_wrong_count_never_changes_the_balance(self) -> None:
        beans = _beans(3)

        result = BeanLedger().consume(beans, wrong_count=0, now=_NOW)

        assert result.current_count == 3

    def test_raises_beans_exhausted_when_wrong_count_exceeds_regenerated_balance(self) -> None:
        beans = _beans(2)

        with pytest.raises(BeansExhaustedError):
            BeanLedger().consume(beans, wrong_count=3, now=_NOW)

    def test_exactly_depleting_the_balance_is_allowed(self) -> None:
        beans = _beans(2)

        result = BeanLedger().consume(beans, wrong_count=2, now=_NOW)

        assert result.current_count == 0


class TestRefill:
    def test_sets_to_max_and_advances_last_regen_at_to_now(self) -> None:
        beans = _beans(0, _NOW - timedelta(hours=5))

        result = BeanLedger().refill(beans, _NOW)

        assert result.current_count == BEANS_MAX
        assert result.last_regen_at == _NOW
