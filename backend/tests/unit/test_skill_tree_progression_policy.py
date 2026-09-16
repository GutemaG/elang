"""Unit tests for `SkillTreeProgressionPolicy` and `LessonAccessPolicy` --
the core "what does a skill look like to this user right now" logic, and
the "a locked skill's lesson is unreachable" enforcement.
"""

from __future__ import annotations

from datetime import UTC, datetime

import pytest

from app.domain.lesson.entities import Skill, UserSkillProgress
from app.domain.lesson.exceptions import SkillLockedError
from app.domain.lesson.services import LessonAccessPolicy, SkillTreeProgressionPolicy
from app.domain.lesson.value_objects import SkillState


def _skill(id_: str, order_index: int) -> Skill:
    return Skill(id=id_, title=f"Skill {order_index}", order_index=order_index)


class TestSkillTreeProgressionPolicyNewUserBootstrap:
    """Story 001's core edge case: a user with zero progress rows must still
    get a fully correct skill tree, computed on the fly.
    """

    def test_first_skill_by_order_index_is_active_with_zero_progress_rows(self) -> None:
        skills = [_skill("s1", 1), _skill("s2", 2), _skill("s3", 3)]

        entries = SkillTreeProgressionPolicy().compute_states(skills, progress_rows=[])

        assert entries[0].skill.id == "s1"
        assert entries[0].state == SkillState.ACTIVE
        assert entries[0].crown_level == 0

    def test_every_other_skill_is_locked_with_zero_progress_rows(self) -> None:
        skills = [_skill("s1", 1), _skill("s2", 2), _skill("s3", 3)]

        entries = SkillTreeProgressionPolicy().compute_states(skills, progress_rows=[])

        assert [e.state for e in entries[1:]] == [SkillState.LOCKED, SkillState.LOCKED]
        assert all(e.crown_level == 0 for e in entries[1:])

    def test_first_skill_is_determined_by_order_index_not_input_list_order(self) -> None:
        # Skills passed out of order -- the "first" skill must still be the
        # one with the lowest order_index, not the first list element.
        skills = [_skill("s3", 3), _skill("s1", 1), _skill("s2", 2)]

        entries = SkillTreeProgressionPolicy().compute_states(skills, progress_rows=[])

        active_entries = [e for e in entries if e.state == SkillState.ACTIVE]
        assert len(active_entries) == 1
        assert active_entries[0].skill.id == "s1"


class TestSkillTreeProgressionPolicyWithProgress:
    def test_progress_row_with_no_completed_at_is_active(self) -> None:
        skills = [_skill("s1", 1), _skill("s2", 2)]
        progress = [
            UserSkillProgress(
                user_id="u1", skill_id="s2", unlocked=True, crown_level=0, completed_at=None
            )
        ]

        entries = SkillTreeProgressionPolicy().compute_states(skills, progress)

        s2_entry = next(e for e in entries if e.skill.id == "s2")
        assert s2_entry.state == SkillState.ACTIVE
        assert s2_entry.crown_level == 0

    def test_progress_row_with_completed_at_is_completed_with_its_crown_level(self) -> None:
        skills = [_skill("s1", 1), _skill("s2", 2)]
        progress = [
            UserSkillProgress(
                user_id="u1",
                skill_id="s1",
                unlocked=True,
                crown_level=3,
                completed_at=datetime(2026, 1, 1, tzinfo=UTC),
            )
        ]

        entries = SkillTreeProgressionPolicy().compute_states(skills, progress)

        s1_entry = next(e for e in entries if e.skill.id == "s1")
        assert s1_entry.state == SkillState.COMPLETED
        assert s1_entry.crown_level == 3

    def test_a_completed_first_skill_still_leaves_second_skill_locked_without_its_own_row(
        self,
    ) -> None:
        # Completing skill 1 doesn't itself unlock skill 2 in this bolt's
        # read-only logic -- unlocking is bolt 005's write-side concern.
        # This bolt only reflects whatever progress rows already exist.
        skills = [_skill("s1", 1), _skill("s2", 2)]
        progress = [
            UserSkillProgress(
                user_id="u1",
                skill_id="s1",
                unlocked=True,
                crown_level=1,
                completed_at=datetime(2026, 1, 1, tzinfo=UTC),
            )
        ]

        entries = SkillTreeProgressionPolicy().compute_states(skills, progress)

        s2_entry = next(e for e in entries if e.skill.id == "s2")
        assert s2_entry.state == SkillState.LOCKED


class TestStateForSkill:
    def test_returns_the_matching_entrys_state(self) -> None:
        skills = [_skill("s1", 1), _skill("s2", 2)]

        state = SkillTreeProgressionPolicy().state_for_skill("s2", skills, progress_rows=[])

        assert state == SkillState.LOCKED

    def test_raises_value_error_for_unknown_skill_id(self) -> None:
        skills = [_skill("s1", 1)]

        with pytest.raises(ValueError, match="not found"):
            SkillTreeProgressionPolicy().state_for_skill("unknown", skills, progress_rows=[])


class TestLessonAccessPolicy:
    def test_locked_state_raises_skill_locked_error(self) -> None:
        with pytest.raises(SkillLockedError):
            LessonAccessPolicy().ensure_accessible(SkillState.LOCKED)

    @pytest.mark.parametrize("state", [SkillState.ACTIVE, SkillState.COMPLETED])
    def test_active_or_completed_state_is_a_no_op(self, state: SkillState) -> None:
        LessonAccessPolicy().ensure_accessible(state)  # must not raise
