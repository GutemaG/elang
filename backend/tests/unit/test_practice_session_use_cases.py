"""Unit tests for bolt 020's `complete_practice_session` use case (story
002), exercised against fake repositories.
"""

from __future__ import annotations

from datetime import UTC, datetime

import pytest

from app.application.lesson_use_cases import complete_practice_session
from app.domain.lesson.exceptions import InvalidPracticeCompletionError
from app.domain.lesson.value_objects import (
    AMOLE_PRACTICE_SESSION_AWARD,
    XP_PER_CORRECT_ANSWER,
)
from tests.fakes import FakeAmoleTransactionRepository, FakeUserVocabProgressRepository

_NOW = datetime(2026, 9, 18, 12, 0, tzinfo=UTC)


class FakePracticeAttemptRepository:
    def __init__(self) -> None:
        self._rows: dict[str, object] = {}
        self.add_calls = 0

    async def get(self, session_id: str):
        return self._rows.get(session_id)

    async def add(self, attempt) -> None:
        self.add_calls += 1
        self._rows[attempt.id] = attempt


def _repos():
    return {
        "vocab_progress_repo": FakeUserVocabProgressRepository(),
        "amole_repo": FakeAmoleTransactionRepository(),
        "practice_attempt_repo": FakePracticeAttemptRepository(),
    }


class TestCompletePracticeSession:
    async def test_awards_xp_per_correct_answer_and_a_flat_amole_bonus(self) -> None:
        repos = _repos()

        result = await complete_practice_session(
            user_id="u1",
            session_id="session-1",
            results=[("v1", True), ("v2", True), ("v3", False)],
            now=_NOW,
            **repos,
        )

        assert result.correct_count == 2
        assert result.total_count == 3
        assert result.xp_earned == 2 * XP_PER_CORRECT_ANSWER
        assert result.amole_earned == AMOLE_PRACTICE_SESSION_AWARD
        assert result.accuracy_percent == round(2 / 3 * 100)

    async def test_updates_vocab_progress_for_every_result(self) -> None:
        repos = _repos()

        await complete_practice_session(
            user_id="u1",
            session_id="session-1",
            results=[("v1", True), ("v2", False)],
            now=_NOW,
            **repos,
        )

        v1 = await repos["vocab_progress_repo"].get("u1", "v1")
        v2 = await repos["vocab_progress_repo"].get("u1", "v2")
        assert v1 is not None and v1.box_level == 1
        assert v2 is not None and v2.box_level == 1

    async def test_posts_amole_exactly_once(self) -> None:
        repos = _repos()

        await complete_practice_session(
            user_id="u1", session_id="session-1", results=[("v1", True)], now=_NOW, **repos
        )

        assert repos["amole_repo"].add_calls == 1
        assert await repos["amole_repo"].sum_by_user("u1") == AMOLE_PRACTICE_SESSION_AWARD

    async def test_raises_for_an_empty_results_list(self) -> None:
        repos = _repos()

        with pytest.raises(InvalidPracticeCompletionError):
            await complete_practice_session(
                user_id="u1", session_id="session-1", results=[], now=_NOW, **repos
            )

    async def test_is_idempotent_on_session_id(self) -> None:
        repos = _repos()
        kwargs = dict(
            user_id="u1", session_id="session-1", results=[("v1", True)], now=_NOW, **repos
        )

        first = await complete_practice_session(**kwargs)
        second = await complete_practice_session(**kwargs)

        assert first == second
        assert repos["practice_attempt_repo"].add_calls == 1

    async def test_retried_session_does_not_double_update_vocab_progress(self) -> None:
        repos = _repos()
        kwargs = dict(
            user_id="u1", session_id="session-1", results=[("v1", True)], now=_NOW, **repos
        )

        await complete_practice_session(**kwargs)
        await complete_practice_session(**kwargs)

        progress = await repos["vocab_progress_repo"].get("u1", "v1")
        assert progress.box_level == 1  # first-appearance box, not advanced twice
