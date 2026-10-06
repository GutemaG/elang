"""Unit tests for the lesson-content application layer (`get_skill_tree`,
`get_lesson_content`), exercised against fake repositories (network/DB
boundary), never mocking the domain services underneath.
"""

from __future__ import annotations

from datetime import UTC, date, datetime, timedelta, timezone

import pytest

from app.application.lesson_use_cases import PathLesson, get_lesson_content, get_skill_tree
from app.domain.lesson.entities import (
    Category,
    Exercise,
    Lesson,
    Skill,
    UserSkillProgress,
    UserStreak,
)
from app.domain.lesson.exceptions import LessonNotFoundError, SkillLockedError
from app.domain.lesson.value_objects import Choice as ChoiceVO
from app.domain.lesson.value_objects import (
    ChoiceAnswerKey,
    ExerciseType,
    MultipleChoiceContent,
)
from tests.fakes import (
    EN_AM_COURSE_ID,
    FakeCategoryRepository,
    FakeLessonAttemptRepository,
    FakeLessonRepository,
    FakeLessonRepositoryWithSkillIndex,
    FakeSkillRepository,
    FakeUserBeansRepository,
    FakeUserSkillProgressRepository,
    FakeUserStreakRepository,
)

_NOW = datetime(2026, 9, 16, 12, 0, tzinfo=UTC)


async def _get_skill_tree(
    user_id: str,
    skill_repo: FakeSkillRepository,
    progress_repo: FakeUserSkillProgressRepository,
):
    return await get_skill_tree(
        user_id,
        skill_repo,
        progress_repo,
        FakeUserBeansRepository(),
        FakeUserStreakRepository(),
        FakeLessonAttemptRepository(),
        FakeLessonRepositoryWithSkillIndex(),
        FakeCategoryRepository(),
        _NOW,
    )


def _mc_exercise(id_: str, lesson_id: str, order_index: int) -> Exercise:
    return Exercise(
        id=id_,
        lesson_id=lesson_id,
        order_index=order_index,
        type=ExerciseType.MULTIPLE_CHOICE,
        prompt="How do you say 'Hello'?",
        content=MultipleChoiceContent(
            choices=(ChoiceVO(id="a", text="ሰላም"), ChoiceVO(id="b", text="ደህና ሁን"))
        ),
        answer_key=ChoiceAnswerKey(correct_choice_id="a"),
    )


class TestGetSkillTree:
    async def test_returns_computed_states_for_the_given_user(self) -> None:
        skills = [
            Skill(category_id="cat-1", id="s1", title="Greetings", order_index=1),
            Skill(category_id="cat-1", id="s2", title="Food", order_index=2),
        ]
        skill_repo = FakeSkillRepository(skills)
        progress_repo = FakeUserSkillProgressRepository([])

        summary = await _get_skill_tree("user-1", skill_repo, progress_repo)
        entries = summary.entries

        assert [e.skill.id for e in entries] == ["s1", "s2"]
        assert entries[0].state.value == "active"
        assert entries[1].state.value == "locked"

    async def test_only_considers_progress_rows_for_the_requesting_user(self) -> None:
        skills = [Skill(category_id="cat-1", id="s1", title="Greetings", order_index=1)]
        skill_repo = FakeSkillRepository(skills)
        progress_repo = FakeUserSkillProgressRepository([])

        # FakeUserSkillProgressRepository.list_by_user already filters by
        # user_id -- verifying the use case doesn't leak another user's rows
        # by calling with a user that has none.
        summary = await _get_skill_tree("some-other-user", skill_repo, progress_repo)

        assert summary.entries[0].state.value == "active"

    async def test_summary_includes_beans_streak_and_lifetime_xp_hud_stats(self) -> None:
        skills = [Skill(category_id="cat-1", id="s1", title="Greetings", order_index=1)]
        skill_repo = FakeSkillRepository(skills)
        progress_repo = FakeUserSkillProgressRepository([])

        summary = await get_skill_tree(
            "user-1",
            skill_repo,
            progress_repo,
            FakeUserBeansRepository(),
            FakeUserStreakRepository(),
            FakeLessonAttemptRepository(),
            FakeLessonRepositoryWithSkillIndex(),
            FakeCategoryRepository(
                [
                    Category(
                        id="cat-1",
                        title="Foundations",
                        subtitle="ሰላምታ",
                        order_index=1,
                        course_id=EN_AM_COURSE_ID,
                    )
                ]
            ),
            _NOW,
        )

        # No rows yet for this user -- defaults apply (bolt 005's "absence
        # is meaningful" convention, same as UserSkillProgress).
        assert summary.beans == summary.beans_max
        assert summary.streak_count == 0
        assert summary.total_xp == 0
        # Deprecated fields derive from the first category (ADR-11).
        assert summary.unit_title == "Foundations"
        assert summary.unit_subtitle == "ሰላምታ"
        assert [c.id for c in summary.categories] == ["cat-1"]

    async def test_next_lesson_id_skips_lessons_already_completed_this_cycle(self) -> None:
        skills = [Skill(category_id="cat-1", id="s1", title="Greetings", order_index=1)]
        skill_repo = FakeSkillRepository(skills)
        progress_repo = FakeUserSkillProgressRepository(
            [
                UserSkillProgress(
                    user_id="user-1",
                    skill_id="s1",
                    unlocked=True,
                    crown_level=0,
                    completed_at=None,
                    completed_lesson_ids_this_cycle=frozenset({"lesson-a1"}),
                )
            ]
        )
        lesson_repo = FakeLessonRepositoryWithSkillIndex(
            [
                Lesson(id="lesson-a1", skill_id="s1", title="Hello", order_index=1),
                Lesson(id="lesson-a2", skill_id="s1", title="Goodbye", order_index=2),
            ]
        )

        summary = await get_skill_tree(
            "user-1",
            skill_repo,
            progress_repo,
            FakeUserBeansRepository(),
            FakeUserStreakRepository(),
            FakeLessonAttemptRepository(),
            lesson_repo,
            FakeCategoryRepository(),
            _NOW,
        )

        assert summary.lesson_id_by_skill["s1"] == "lesson-a2"
        # One of two lessons done: the skill is still unfinished, and the
        # summary says how far through it the learner is.
        assert summary.lesson_progress_by_skill["s1"] == (1, 2)
        # Each lesson, in order, for a stop per lesson on the path.
        assert summary.lessons_by_skill["s1"] == [
            PathLesson(id="lesson-a1", title="Hello", done=True),
            PathLesson(id="lesson-a2", title="Goodbye", done=False),
        ]


class TestPractisedToday:
    """021-daily-reminder (bolt 062): whether today's UTC streak day is
    already practised, from the streak row the tree already reads."""

    @staticmethod
    async def _practised(last: date | None, now: datetime = _NOW) -> bool:
        streaks = (
            []
            if last is None
            else [
                UserStreak(
                    user_id="user-1",
                    current_streak=3,
                    last_completed_date=last,
                    active_freeze_count=0,
                )
            ]
        )
        summary = await get_skill_tree(
            "user-1",
            FakeSkillRepository([]),
            FakeUserSkillProgressRepository([]),
            FakeUserBeansRepository(),
            FakeUserStreakRepository(streaks),
            FakeLessonAttemptRepository(),
            FakeLessonRepositoryWithSkillIndex(),
            FakeCategoryRepository(),
            now,
        )
        return summary.practised_today

    async def test_a_new_learner_has_not_practised(self) -> None:
        assert await self._practised(None) is False

    async def test_a_lesson_today_counts(self) -> None:
        assert await self._practised(date(2026, 9, 16)) is True

    async def test_a_lesson_yesterday_does_not(self) -> None:
        assert await self._practised(date(2026, 9, 15)) is False

    async def test_the_day_rolls_over_at_midnight_utc(self) -> None:
        just_after = datetime(2026, 9, 17, 0, 0, 1, tzinfo=UTC)
        assert await self._practised(date(2026, 9, 16), just_after) is False

    async def test_today_is_the_utc_date_whatever_the_clock_zone(self) -> None:
        # 01:30 in Addis Ababa on the 17th is still the 16th in UTC.
        addis = datetime(2026, 9, 17, 1, 30, tzinfo=timezone(timedelta(hours=3)))
        assert await self._practised(date(2026, 9, 16), addis) is True


class TestGetLessonContent:
    async def test_returns_the_lesson_when_its_skill_is_active(self) -> None:
        skills = [Skill(category_id="cat-1", id="s1", title="Greetings", order_index=1)]
        lesson = Lesson(
            id="l1",
            skill_id="s1",
            title="Hello & Goodbye",
            order_index=1,
            exercises=[_mc_exercise("e1", "l1", 1)],
        )
        lesson_repo = FakeLessonRepository([lesson])
        skill_repo = FakeSkillRepository(skills)
        progress_repo = FakeUserSkillProgressRepository([])

        result = await get_lesson_content("user-1", "l1", lesson_repo, skill_repo, progress_repo)

        assert result.lesson.id == "l1"
        assert len(result.lesson.exercises) == 1
        assert result.content_version is not None

    async def test_raises_lesson_not_found_for_unknown_lesson_id(self) -> None:
        lesson_repo = FakeLessonRepository([])
        skill_repo = FakeSkillRepository([])
        progress_repo = FakeUserSkillProgressRepository([])

        with pytest.raises(LessonNotFoundError):
            await get_lesson_content(
                "user-1", "does-not-exist", lesson_repo, skill_repo, progress_repo
            )

    async def test_raises_skill_locked_for_a_lesson_whose_skill_is_locked(self) -> None:
        # skill s2 is not the first skill and has no progress row -> locked.
        # Requesting its lesson directly by ID must still be denied (story
        # 001's edge case).
        skills = [
            Skill(category_id="cat-1", id="s1", title="Greetings", order_index=1),
            Skill(category_id="cat-1", id="s2", title="Food", order_index=2),
        ]
        lesson = Lesson(id="l2", skill_id="s2", title="Coffee & Tea", order_index=1, exercises=[])
        lesson_repo = FakeLessonRepository([lesson])
        skill_repo = FakeSkillRepository(skills)
        progress_repo = FakeUserSkillProgressRepository([])

        with pytest.raises(SkillLockedError):
            await get_lesson_content("user-1", "l2", lesson_repo, skill_repo, progress_repo)
