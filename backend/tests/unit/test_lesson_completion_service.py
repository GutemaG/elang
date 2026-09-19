"""Unit tests for `LessonCompletionService` (bolt 005): XP award, FR-6's
skill-unlock/crown-level progression (including the "replay every lesson
again" cycle-tracking rule), and streak-freeze-at-crown-5 integration.
Streak evaluation itself is covered by `test_streak_policy.py` -- these
tests check that it's wired in correctly, not its internal branches.
"""

from __future__ import annotations

from datetime import UTC, date, datetime

import pytest

from app.domain.lesson.entities import Skill, UserSkillProgress, UserStreak
from app.domain.lesson.exceptions import InvalidCompletionError
from app.domain.lesson.services import LessonCompletionService
from app.domain.lesson.value_objects import FREEZE_GRANTED_AT_CROWN_LEVEL, XP_PER_CORRECT_ANSWER

_NOW = datetime(2026, 9, 16, 12, 0, tzinfo=UTC)
_TODAY = date(2026, 9, 16)

_SKILLS = [
    Skill(category_id="cat-1", id="skill-a", title="Greetings & Basics", order_index=1),
    Skill(category_id="cat-1", id="skill-b", title="Food & Drink", order_index=2),
]


def _progress(
    skill_id: str = "skill-a",
    crown_level: int = 0,
    completed_at: datetime | None = None,
    completed_lesson_ids_this_cycle: frozenset[str] = frozenset(),
) -> UserSkillProgress:
    return UserSkillProgress(
        user_id="u1",
        skill_id=skill_id,
        unlocked=True,
        crown_level=crown_level,
        completed_at=completed_at,
        completed_lesson_ids_this_cycle=completed_lesson_ids_this_cycle,
    )


def _streak(freezes: int = 0) -> UserStreak:
    return UserStreak(
        user_id="u1", current_streak=0, last_completed_date=None, active_freeze_count=freezes
    )


def _complete(**overrides):
    defaults = dict(
        lesson_id="lesson-a2",
        skill_lesson_ids=frozenset({"lesson-a1", "lesson-a2"}),
        all_skills=_SKILLS,
        progress=_progress(),
        streak=_streak(),
        correct_count=4,
        total_count=4,
        time_spent_seconds=60.0,
        daily_xp_total_before=0,
        daily_xp_target=40,
        now=_NOW,
        completion_date=_TODAY,
    )
    defaults.update(overrides)
    return LessonCompletionService().complete(**defaults)


class TestXPAward:
    def test_xp_equals_correct_count_times_the_per_answer_constant(self) -> None:
        result = _complete(correct_count=3, total_count=4)

        assert result.outcome.xp_awarded == 3 * XP_PER_CORRECT_ANSWER

    def test_daily_xp_total_adds_to_the_running_total(self) -> None:
        result = _complete(correct_count=4, total_count=4, daily_xp_total_before=20)

        assert result.outcome.daily_xp_total == 20 + 4 * XP_PER_CORRECT_ANSWER

    def test_accuracy_percent_is_rounded(self) -> None:
        result = _complete(correct_count=1, total_count=3)  # 33.33...%

        assert result.outcome.accuracy_percent == 33


class TestValidation:
    def test_rejects_zero_total_count(self) -> None:
        with pytest.raises(InvalidCompletionError):
            _complete(correct_count=0, total_count=0)

    def test_rejects_correct_count_greater_than_total_count(self) -> None:
        with pytest.raises(InvalidCompletionError):
            _complete(correct_count=5, total_count=4)

    def test_rejects_negative_correct_count(self) -> None:
        with pytest.raises(InvalidCompletionError):
            _complete(correct_count=-1, total_count=4)


class TestCycleTrackingAndSkillUnlock:
    def test_completing_a_non_final_lesson_does_not_complete_the_cycle(self) -> None:
        result = _complete(
            lesson_id="lesson-a1",
            skill_lesson_ids=frozenset({"lesson-a1", "lesson-a2"}),
            progress=_progress(completed_lesson_ids_this_cycle=frozenset()),
        )

        assert result.progress.completed_at is None
        assert result.progress.crown_level == 0
        assert "lesson-a1" in result.progress.completed_lesson_ids_this_cycle
        assert result.unlocked_progress is None
        assert result.outcome.skill_unlocked_title is None

    def test_completing_the_final_lesson_first_time_unlocks_the_skill_and_the_next_one(
        self,
    ) -> None:
        # lesson-a1 already done this cycle; completing lesson-a2 finishes it.
        result = _complete(
            lesson_id="lesson-a2",
            skill_lesson_ids=frozenset({"lesson-a1", "lesson-a2"}),
            progress=_progress(completed_lesson_ids_this_cycle=frozenset({"lesson-a1"})),
        )

        assert result.progress.completed_at is not None
        assert result.progress.crown_level == 1
        assert result.progress.completed_lesson_ids_this_cycle == frozenset()
        assert result.unlocked_progress is not None
        assert result.unlocked_progress.skill_id == "skill-b"
        assert result.unlocked_progress.completed_at is None
        assert result.outcome.skill_unlocked_title == "Food & Drink"
        assert result.outcome.crown_leveled_up is False  # first completion, not a "level up"

    def test_completing_the_last_skill_in_the_curriculum_has_no_unlock(self) -> None:
        result = _complete(
            lesson_id="lesson-b1",
            skill_lesson_ids=frozenset({"lesson-b1"}),
            progress=_progress(skill_id="skill-b", completed_lesson_ids_this_cycle=frozenset()),
        )

        assert result.progress.completed_at is not None
        assert result.progress.crown_level == 1
        assert result.unlocked_progress is None
        assert result.outcome.skill_unlocked_title is None

    def test_replaying_only_some_lessons_of_an_already_completed_skill_does_not_raise_crown(
        self,
    ) -> None:
        already_completed = _progress(
            crown_level=1, completed_at=_NOW, completed_lesson_ids_this_cycle=frozenset()
        )

        result = _complete(
            lesson_id="lesson-a1",
            skill_lesson_ids=frozenset({"lesson-a1", "lesson-a2"}),
            progress=already_completed,
        )

        assert result.progress.crown_level == 1  # unchanged
        assert result.outcome.crown_leveled_up is False

    def test_replaying_every_lesson_again_raises_the_crown_level(self) -> None:
        already_completed = _progress(
            crown_level=1,
            completed_at=_NOW,
            completed_lesson_ids_this_cycle=frozenset({"lesson-a1"}),
        )

        result = _complete(
            lesson_id="lesson-a2",
            skill_lesson_ids=frozenset({"lesson-a1", "lesson-a2"}),
            progress=already_completed,
        )

        assert result.progress.crown_level == 2
        assert result.outcome.crown_leveled_up is True
        assert result.unlocked_progress is None  # already unlocked, no new unlock
        assert result.progress.completed_lesson_ids_this_cycle == frozenset()

    def test_crown_level_is_capped_at_five(self) -> None:
        already_completed = _progress(
            crown_level=5,
            completed_at=_NOW,
            completed_lesson_ids_this_cycle=frozenset({"lesson-a1"}),
        )

        result = _complete(
            lesson_id="lesson-a2",
            skill_lesson_ids=frozenset({"lesson-a1", "lesson-a2"}),
            progress=already_completed,
        )

        assert result.progress.crown_level == 5

    def test_reaching_crown_level_five_grants_exactly_one_streak_freeze(self) -> None:
        at_crown_four = _progress(
            crown_level=FREEZE_GRANTED_AT_CROWN_LEVEL - 1,
            completed_at=_NOW,
            completed_lesson_ids_this_cycle=frozenset({"lesson-a1"}),
        )

        result = _complete(
            lesson_id="lesson-a2",
            skill_lesson_ids=frozenset({"lesson-a1", "lesson-a2"}),
            progress=at_crown_four,
            streak=_streak(freezes=0),
        )

        assert result.progress.crown_level == FREEZE_GRANTED_AT_CROWN_LEVEL
        assert result.streak.active_freeze_count == 1
        assert result.outcome.streak_freeze_unlocked is True

    def test_crown_level_five_replay_after_cap_does_not_grant_another_freeze(self) -> None:
        # Already at the cap -- replaying again keeps crown at 5 and must
        # not re-grant a freeze every time (only on the transition *into* 5).
        already_at_cap = _progress(
            crown_level=FREEZE_GRANTED_AT_CROWN_LEVEL,
            completed_at=_NOW,
            completed_lesson_ids_this_cycle=frozenset({"lesson-a1"}),
        )

        result = _complete(
            lesson_id="lesson-a2",
            skill_lesson_ids=frozenset({"lesson-a1", "lesson-a2"}),
            progress=already_at_cap,
            streak=_streak(freezes=0),
        )

        assert result.streak.active_freeze_count == 0
        assert result.outcome.streak_freeze_unlocked is False


class TestStreakIntegration:
    def test_streak_evaluation_result_is_reflected_in_the_outcome(self) -> None:
        result = _complete(streak=_streak())

        assert result.outcome.streak_count == 1
        assert result.outcome.streak_increased_today is True
        assert result.streak.last_completed_date == _TODAY
