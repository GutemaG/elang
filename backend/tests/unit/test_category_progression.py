"""Unit tests for bolt `021-categories-service` (ADR-11): `SkillPath` and the
category-aware behaviour of `SkillTreeProgressionPolicy` /
`LessonCompletionService`. Every category is open; progression is linear
only within one category.
"""

from __future__ import annotations

from datetime import UTC, date, datetime

import pytest

from app.domain.lesson.entities import Skill, UserSkillProgress, UserStreak
from app.domain.lesson.exceptions import SkillLockedError
from app.domain.lesson.services import (
    LessonAccessPolicy,
    LessonCompletionService,
    SkillPath,
    SkillTreeProgressionPolicy,
)
from app.domain.lesson.value_objects import SkillState

_NOW = datetime(2026, 9, 19, 12, 0, tzinfo=UTC)


def _skill(id_: str, category_id: str, order_index: int) -> Skill:
    return Skill(id=id_, title=id_, order_index=order_index, category_id=category_id)


# Two categories, deliberately with the SAME order_index values (per-category
# ordering, ADR-11) and listed interleaved to prove grouping, not list order.
_SKILLS = [
    _skill("food-2", "food", 2),
    _skill("family-1", "family", 1),
    _skill("food-1", "food", 1),
    _skill("family-2", "family", 2),
    _skill("family-3", "family", 3),
]


class TestSkillPath:
    def test_group_builds_one_ordered_path_per_category(self) -> None:
        paths = SkillPath.group(_SKILLS)

        assert set(paths) == {"food", "family"}
        assert [s.id for s in paths["food"].skills] == ["food-1", "food-2"]
        assert [s.id for s in paths["family"].skills] == ["family-1", "family-2", "family-3"]

    def test_first_is_the_lowest_order_index_in_the_category(self) -> None:
        paths = SkillPath.group(_SKILLS)

        assert paths["food"].first is not None
        assert paths["food"].first.id == "food-1"
        assert paths["family"].first is not None
        assert paths["family"].first.id == "family-1"

    def test_next_after_stays_inside_the_category(self) -> None:
        paths = SkillPath.group(_SKILLS)

        food_next = paths["food"].next_after("food-1")
        assert food_next is not None
        assert food_next.id == "food-2"

    def test_next_after_the_last_skill_is_none(self) -> None:
        paths = SkillPath.group(_SKILLS)

        assert paths["food"].next_after("food-2") is None
        assert paths["family"].next_after("family-3") is None

    def test_next_after_an_unknown_skill_is_none(self) -> None:
        assert SkillPath.group(_SKILLS)["food"].next_after("family-1") is None

    def test_an_empty_path_has_no_first_skill(self) -> None:
        assert SkillPath(()).first is None

    def test_a_single_skill_category_has_a_first_and_no_next(self) -> None:
        path = SkillPath.group([_skill("solo", "c", 1)])["c"]

        assert path.first is not None
        assert path.first.id == "solo"
        assert path.next_after("solo") is None


class TestPolicyAcrossCategories:
    def test_a_new_user_gets_exactly_one_active_skill_per_category(self) -> None:
        entries = SkillTreeProgressionPolicy().compute_states(_SKILLS, progress_rows=[])

        active = {e.skill.id for e in entries if e.state == SkillState.ACTIVE}
        locked = {e.skill.id for e in entries if e.state == SkillState.LOCKED}
        assert active == {"food-1", "family-1"}
        assert locked == {"food-2", "family-2", "family-3"}

    def test_entries_are_grouped_by_category_in_first_seen_order(self) -> None:
        entries = SkillTreeProgressionPolicy().compute_states(_SKILLS, progress_rows=[])

        assert [e.skill.id for e in entries] == [
            "food-1",
            "food-2",
            "family-1",
            "family-2",
            "family-3",
        ]

    def test_progress_in_one_category_does_not_change_another(self) -> None:
        progress = [
            UserSkillProgress(
                user_id="u1",
                skill_id="food-1",
                unlocked=True,
                crown_level=1,
                completed_at=_NOW,
            ),
            UserSkillProgress(
                user_id="u1", skill_id="food-2", unlocked=True, crown_level=0, completed_at=None
            ),
        ]

        entries = SkillTreeProgressionPolicy().compute_states(_SKILLS, progress)
        state = {e.skill.id: e.state for e in entries}

        assert state["food-1"] == SkillState.COMPLETED
        assert state["food-2"] == SkillState.ACTIVE
        assert state["family-1"] == SkillState.ACTIVE
        assert state["family-2"] == SkillState.LOCKED

    def test_state_for_skill_agrees_with_the_tree_for_a_non_first_skill(self) -> None:
        policy = SkillTreeProgressionPolicy()

        assert policy.state_for_skill("family-2", _SKILLS, []) == SkillState.LOCKED
        assert policy.state_for_skill("family-1", _SKILLS, []) == SkillState.ACTIVE

    def test_a_locked_skill_in_another_category_is_rejected_by_the_access_policy(self) -> None:
        state = SkillTreeProgressionPolicy().state_for_skill("food-2", _SKILLS, [])

        with pytest.raises(SkillLockedError):
            LessonAccessPolicy().ensure_accessible(state)


def _complete(skill_id: str, all_skills: list[Skill] = _SKILLS):
    return LessonCompletionService().complete(
        lesson_id=f"{skill_id}-lesson",
        skill_lesson_ids=frozenset({f"{skill_id}-lesson"}),
        all_skills=all_skills,
        progress=UserSkillProgress(
            user_id="u1", skill_id=skill_id, unlocked=True, crown_level=0, completed_at=None
        ),
        streak=UserStreak(
            user_id="u1", current_streak=0, last_completed_date=None, active_freeze_count=0
        ),
        correct_count=4,
        total_count=4,
        time_spent_seconds=30.0,
        daily_xp_total_before=0,
        daily_xp_target=40,
        now=_NOW,
        completion_date=date(2026, 9, 19),
    )


class TestCompletionUnlocksWithinTheCategory:
    def test_completing_a_skill_unlocks_the_next_skill_in_the_same_category(self) -> None:
        result = _complete("food-1")

        assert result.unlocked_progress is not None
        assert result.unlocked_progress.skill_id == "food-2"
        assert result.outcome.skill_unlocked_title == "food-2"

    def test_completion_never_unlocks_a_skill_in_another_category(self) -> None:
        result = _complete("family-1")

        assert result.unlocked_progress is not None
        assert result.unlocked_progress.skill_id == "family-2"

    def test_completing_the_last_skill_of_a_category_unlocks_nothing(self) -> None:
        result = _complete("food-2")

        assert result.unlocked_progress is None
        assert result.outcome.skill_unlocked_title is None

    def test_completing_a_single_skill_category_unlocks_nothing_and_does_not_error(self) -> None:
        skills = [_skill("solo", "only", 1), _skill("other", "elsewhere", 1)]

        result = _complete("solo", skills)

        assert result.unlocked_progress is None
        assert result.progress.completed_at is not None
