"""Unit tests for `LeitnerBoxPolicy` (bolt `019-srs-tracking-service`,
story `003-leitner-box-algorithm`) -- pure domain logic, no fakes needed.
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

from app.domain.lesson.services import LeitnerBoxPolicy
from app.domain.lesson.value_objects import INCORRECT_RESET_INTERVAL

_NOW = datetime(2026, 9, 17, 12, 0, tzinfo=UTC)


class TestLeitnerBoxPolicyCorrect:
    def test_moves_up_one_box_and_sets_next_review_by_destination_interval(self) -> None:
        new_box, next_review_at = LeitnerBoxPolicy().apply(2, True, _NOW)

        assert new_box == 3
        assert next_review_at == _NOW + timedelta(days=7)

    def test_caps_at_box_5(self) -> None:
        new_box, next_review_at = LeitnerBoxPolicy().apply(5, True, _NOW)

        assert new_box == 5
        assert next_review_at == _NOW + timedelta(days=30)

    def test_box_1_to_2_uses_box_2s_3_day_interval(self) -> None:
        new_box, next_review_at = LeitnerBoxPolicy().apply(1, True, _NOW)

        assert new_box == 2
        assert next_review_at == _NOW + timedelta(days=3)


class TestLeitnerBoxPolicyIncorrect:
    def test_resets_to_box_1_regardless_of_current_box(self) -> None:
        new_box, _ = LeitnerBoxPolicy().apply(4, False, _NOW)

        assert new_box == 1

    def test_uses_the_dedicated_incorrect_reset_interval_not_box_1s_interval(self) -> None:
        # Both currently resolve to 1 day, but this asserts the policy reads
        # from `INCORRECT_RESET_INTERVAL`, not `LEITNER_BOX_INTERVALS[1]` --
        # a future change to one must not silently change the other
        # (story 003's explicit requirement).
        _, next_review_at = LeitnerBoxPolicy().apply(3, False, _NOW)

        assert next_review_at == _NOW + INCORRECT_RESET_INTERVAL
