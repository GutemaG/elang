"""Unit tests for bolt 005's application-layer use cases (`complete_lesson`,
`get_beans_status`, `refill_beans`), exercised against fake repositories
(network/DB boundary) -- never mocking the domain services underneath.
"""

from __future__ import annotations

from datetime import UTC, datetime

import pytest

from app.application.lesson_use_cases import complete_lesson, get_beans_status, refill_beans
from app.domain.lesson.entities import Exercise, Lesson, Skill, UserBeans
from app.domain.lesson.exceptions import (
    BeansExhaustedError,
    InsufficientAmoleError,
    InvalidCompletionError,
    LessonNotFoundError,
    SkillLockedError,
)
from app.domain.lesson.value_objects import (
    BEANS_MAX,
    REFILL_COST_AMOLE,
    STARTING_AMOLE_BALANCE,
    XP_PER_CORRECT_ANSWER,
    ChoiceAnswerKey,
    ExerciseType,
    MultipleChoiceContent,
)
from app.domain.lesson.value_objects import Choice as ChoiceVO
from tests.fakes import (
    FakeLessonAttemptRepository,
    FakeLessonRepositoryWithSkillIndex,
    FakeSkillRepository,
    FakeUserBeansRepository,
    FakeUserSkillProgressRepository,
    FakeUserStreakRepository,
)

_NOW = datetime(2026, 9, 16, 12, 0, tzinfo=UTC)


def _exercise(id_: str, lesson_id: str, order_index: int) -> Exercise:
    return Exercise(
        id=id_,
        lesson_id=lesson_id,
        order_index=order_index,
        type=ExerciseType.MULTIPLE_CHOICE,
        prompt="How do you say 'Hello'?",
        content=MultipleChoiceContent(
            choices=(ChoiceVO(id="a", text="ሰላም"), ChoiceVO(id="b", text="ደህና"))
        ),
        answer_key=ChoiceAnswerKey(correct_choice_id="a"),
    )


def _lesson(id_: str, skill_id: str, order_index: int, n_exercises: int = 4) -> Lesson:
    return Lesson(
        id=id_,
        skill_id=skill_id,
        title="Hello & Goodbye",
        order_index=order_index,
        exercises=[_exercise(f"{id_}-e{i}", id_, i) for i in range(n_exercises)],
    )


def _repos(lessons: list[Lesson], skills: list[Skill]):
    return {
        "lesson_repo": FakeLessonRepositoryWithSkillIndex(lessons),
        "skill_repo": FakeSkillRepository(skills),
        "progress_repo": FakeUserSkillProgressRepository([]),
        "beans_repo": FakeUserBeansRepository(),
        "streak_repo": FakeUserStreakRepository(),
        "attempt_repo": FakeLessonAttemptRepository(),
    }


_SKILLS = [
    Skill(id="skill-a", title="Greetings & Basics", order_index=1),
    Skill(id="skill-b", title="Food & Drink", order_index=2),
]
_LESSONS = [_lesson("lesson-a1", "skill-a", 1)]


class TestCompleteLesson:
    async def test_awards_xp_and_persists_progress_beans_and_streak(self) -> None:
        repos = _repos(_LESSONS, _SKILLS)

        outcome = await complete_lesson(
            user_id="u1",
            lesson_id="lesson-a1",
            attempt_id="attempt-1",
            correct_count=4,
            total_count=4,
            time_spent_seconds=30.0,
            daily_xp_target=40,
            now=_NOW,
            **repos,
        )

        assert outcome.xp_awarded == 4 * XP_PER_CORRECT_ANSWER
        assert repos["attempt_repo"].add_calls == 1
        stored_progress = await repos["progress_repo"].get("u1", "skill-a")
        assert stored_progress is not None
        assert stored_progress.crown_level == 1
        stored_streak = await repos["streak_repo"].get("u1")
        assert stored_streak.current_streak == 1

    async def test_is_idempotent_on_attempt_id(self) -> None:
        repos = _repos(_LESSONS, _SKILLS)
        kwargs = dict(
            user_id="u1",
            lesson_id="lesson-a1",
            attempt_id="attempt-1",
            correct_count=4,
            total_count=4,
            time_spent_seconds=30.0,
            daily_xp_target=40,
            now=_NOW,
            **repos,
        )

        first = await complete_lesson(**kwargs)
        second = await complete_lesson(**kwargs)

        assert first == second
        assert repos["attempt_repo"].add_calls == 1  # never re-graded/re-awarded

    async def test_raises_lesson_not_found_for_unknown_lesson(self) -> None:
        repos = _repos(_LESSONS, _SKILLS)

        with pytest.raises(LessonNotFoundError):
            await complete_lesson(
                user_id="u1",
                lesson_id="does-not-exist",
                attempt_id="attempt-1",
                correct_count=4,
                total_count=4,
                time_spent_seconds=30.0,
                daily_xp_target=40,
                now=_NOW,
                **repos,
            )

    async def test_raises_invalid_completion_when_total_count_mismatches_lesson(self) -> None:
        repos = _repos(_LESSONS, _SKILLS)

        with pytest.raises(InvalidCompletionError):
            await complete_lesson(
                user_id="u1",
                lesson_id="lesson-a1",
                attempt_id="attempt-1",
                correct_count=2,
                total_count=2,  # lesson actually has 4 exercises
                time_spent_seconds=30.0,
                daily_xp_target=40,
                now=_NOW,
                **repos,
            )

    async def test_raises_skill_locked_for_a_lesson_whose_skill_is_locked(self) -> None:
        locked_lesson = _lesson("lesson-b1", "skill-b", 1)
        repos = _repos([*_LESSONS, locked_lesson], _SKILLS)

        with pytest.raises(SkillLockedError):
            await complete_lesson(
                user_id="u1",
                lesson_id="lesson-b1",
                attempt_id="attempt-1",
                correct_count=4,
                total_count=4,
                time_spent_seconds=30.0,
                daily_xp_target=40,
                now=_NOW,
                **repos,
            )

    async def test_raises_beans_exhausted_when_wrong_count_exceeds_beans_balance(self) -> None:
        repos = _repos(_LESSONS, _SKILLS)
        await repos["beans_repo"].upsert(
            UserBeans(user_id="u1", current_count=1, last_regen_at=_NOW, amole_balance=500)
        )

        with pytest.raises(BeansExhaustedError):
            await complete_lesson(
                user_id="u1",
                lesson_id="lesson-a1",
                attempt_id="attempt-1",
                correct_count=0,  # implies 4 wrong answers, only 1 bean available
                total_count=4,
                time_spent_seconds=30.0,
                daily_xp_target=40,
                now=_NOW,
                **repos,
            )


class TestGetBeansStatus:
    async def test_new_user_gets_full_beans_and_starting_amole(self) -> None:
        beans_repo = FakeUserBeansRepository()

        result = await get_beans_status("u1", beans_repo, _NOW)

        assert result.beans == BEANS_MAX
        assert result.amole_balance == STARTING_AMOLE_BALANCE
        assert result.next_bean_at is None  # already full

    async def test_never_writes_a_row_on_a_pure_read(self) -> None:
        beans_repo = FakeUserBeansRepository()

        await get_beans_status("u1", beans_repo, _NOW)

        assert await beans_repo.get("u1") is None


class TestRefillBeans:
    async def test_success_deducts_amole_and_maxes_out_beans(self) -> None:
        beans_repo = FakeUserBeansRepository(
            [UserBeans(user_id="u1", current_count=0, last_regen_at=_NOW, amole_balance=500)]
        )

        result = await refill_beans("u1", beans_repo, _NOW)

        assert result.beans == BEANS_MAX
        assert result.amole_balance == 500 - REFILL_COST_AMOLE

    async def test_raises_insufficient_amole_when_balance_too_low(self) -> None:
        beans_repo = FakeUserBeansRepository(
            [UserBeans(user_id="u1", current_count=0, last_regen_at=_NOW, amole_balance=10)]
        )

        with pytest.raises(InsufficientAmoleError):
            await refill_beans("u1", beans_repo, _NOW)
