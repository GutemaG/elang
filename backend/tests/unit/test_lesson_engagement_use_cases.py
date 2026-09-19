"""Unit tests for bolt 005's application-layer use cases (`complete_lesson`,
`get_beans_status`, `refill_beans`), exercised against fake repositories
(network/DB boundary) -- never mocking the domain services underneath.
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

import pytest

from app.application.lesson_use_cases import complete_lesson, get_beans_status, refill_beans
from app.domain.lesson.entities import (
    AmoleTransaction,
    Exercise,
    Lesson,
    Skill,
    UserBeans,
    UserStreak,
    UserVocabProgress,
)
from app.domain.lesson.exceptions import (
    BeansExhaustedError,
    InsufficientAmoleError,
    InvalidCompletionError,
    InvalidCompletionTimestampError,
    LessonNotFoundError,
    SkillLockedError,
)
from app.domain.lesson.value_objects import (
    AMOLE_LESSON_COMPLETION_AWARD,
    AMOLE_PERFECT_LESSON_BONUS,
    AMOLE_STREAK_MILESTONE_7_BONUS,
    AMOLE_STREAK_MILESTONE_30_BONUS,
    BEANS_MAX,
    REFILL_COST_AMOLE,
    STARTING_AMOLE_BALANCE,
    XP_PER_CORRECT_ANSWER,
    AmoleSource,
    ChoiceAnswerKey,
    ExerciseType,
    MultipleChoiceContent,
)
from app.domain.lesson.value_objects import Choice as ChoiceVO
from tests.fakes import (
    FakeAmoleTransactionRepository,
    FakeLessonAttemptRepository,
    FakeLessonRepositoryWithSkillIndex,
    FakeSkillRepository,
    FakeUserBeansRepository,
    FakeUserSkillProgressRepository,
    FakeUserStreakRepository,
    FakeUserVocabProgressRepository,
)

_NOW = datetime(2026, 9, 16, 12, 0, tzinfo=UTC)
_ACCOUNT_CREATED_AT = datetime(2026, 1, 1, tzinfo=UTC)


def _exercise(
    id_: str, lesson_id: str, order_index: int, vocab_item_id: str | None = None
) -> Exercise:
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
        vocab_item_id=vocab_item_id,
    )


def _lesson(
    id_: str,
    skill_id: str,
    order_index: int,
    n_exercises: int = 4,
    vocab_item_ids: dict[int, str] | None = None,
) -> Lesson:
    vocab_item_ids = vocab_item_ids or {}
    return Lesson(
        id=id_,
        skill_id=skill_id,
        title="Hello & Goodbye",
        order_index=order_index,
        exercises=[
            _exercise(f"{id_}-e{i}", id_, i, vocab_item_ids.get(i)) for i in range(n_exercises)
        ],
    )


def _repos(lessons: list[Lesson], skills: list[Skill]):
    return {
        "lesson_repo": FakeLessonRepositoryWithSkillIndex(lessons),
        "skill_repo": FakeSkillRepository(skills),
        "progress_repo": FakeUserSkillProgressRepository([]),
        "beans_repo": FakeUserBeansRepository(),
        "streak_repo": FakeUserStreakRepository(),
        "attempt_repo": FakeLessonAttemptRepository(),
        "amole_repo": FakeAmoleTransactionRepository(),
        "vocab_progress_repo": FakeUserVocabProgressRepository(),
    }


_SKILLS = [
    Skill(category_id="cat-1", id="skill-a", title="Greetings & Basics", order_index=1),
    Skill(category_id="cat-1", id="skill-b", title="Food & Drink", order_index=2),
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
            client_completed_at=_NOW,
            account_created_at=_ACCOUNT_CREATED_AT,
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
            client_completed_at=_NOW,
            account_created_at=_ACCOUNT_CREATED_AT,
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
                client_completed_at=_NOW,
                account_created_at=_ACCOUNT_CREATED_AT,
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
                client_completed_at=_NOW,
                account_created_at=_ACCOUNT_CREATED_AT,
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
                client_completed_at=_NOW,
                account_created_at=_ACCOUNT_CREATED_AT,
                **repos,
            )

    async def test_raises_beans_exhausted_when_wrong_count_exceeds_beans_balance(self) -> None:
        repos = _repos(_LESSONS, _SKILLS)
        await repos["beans_repo"].upsert(
            UserBeans(user_id="u1", current_count=1, last_regen_at=_NOW)
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
                client_completed_at=_NOW,
                account_created_at=_ACCOUNT_CREATED_AT,
                **repos,
            )


class TestCompleteLessonOfflineTimestamp:
    """Bolt 008 (003-offline-caching-and-sync): `client_completed_at`
    drives streak/XP-day attribution and completion-timestamp validation,
    independent of `now` (real server time, used for Beans regen only).
    """

    async def test_streak_day_attribution_uses_client_completed_at_not_now(self) -> None:
        repos = _repos(_LESSONS, _SKILLS)
        offline_completion_day = _NOW - timedelta(days=3)

        await complete_lesson(
            user_id="u1",
            lesson_id="lesson-a1",
            attempt_id="attempt-1",
            correct_count=4,
            total_count=4,
            time_spent_seconds=30.0,
            daily_xp_target=40,
            client_completed_at=offline_completion_day,
            account_created_at=_ACCOUNT_CREATED_AT,
            now=_NOW,  # sync happens "now", well after the offline completion
            **repos,
        )

        stored_streak = await repos["streak_repo"].get("u1")
        assert stored_streak.last_completed_date == offline_completion_day.date()

    async def test_two_completions_attributed_to_the_same_day_increment_streak_once(self) -> None:
        repos = _repos(_LESSONS, _SKILLS)
        same_day = _NOW - timedelta(days=1)

        await complete_lesson(
            user_id="u1",
            lesson_id="lesson-a1",
            attempt_id="attempt-1",
            correct_count=4,
            total_count=4,
            time_spent_seconds=30.0,
            daily_xp_target=40,
            client_completed_at=same_day,
            account_created_at=_ACCOUNT_CREATED_AT,
            now=_NOW,
            **repos,
        )
        await complete_lesson(
            user_id="u1",
            lesson_id="lesson-a1",
            attempt_id="attempt-2",  # different attempt, same lesson replayed
            correct_count=4,
            total_count=4,
            time_spent_seconds=20.0,
            daily_xp_target=40,
            client_completed_at=same_day,  # same calendar day as attempt-1
            account_created_at=_ACCOUNT_CREATED_AT,
            now=_NOW,
            **repos,
        )

        stored_streak = await repos["streak_repo"].get("u1")
        # StreakPolicy: a second completion attributed to the *same* day is
        # "already counted today" (gap <= 0), not a fresh increment -- this
        # is what FR-4's "per distinct day, not per lesson" means in
        # practice.
        assert stored_streak.current_streak == 1

    async def test_raises_invalid_completion_timestamp_for_a_far_future_timestamp(self) -> None:
        repos = _repos(_LESSONS, _SKILLS)

        with pytest.raises(InvalidCompletionTimestampError):
            await complete_lesson(
                user_id="u1",
                lesson_id="lesson-a1",
                attempt_id="attempt-1",
                correct_count=4,
                total_count=4,
                time_spent_seconds=30.0,
                daily_xp_target=40,
                client_completed_at=_NOW + timedelta(hours=1),
                account_created_at=_ACCOUNT_CREATED_AT,
                now=_NOW,
                **repos,
            )
        assert repos["attempt_repo"].add_calls == 0

    async def test_raises_invalid_completion_timestamp_when_it_predates_account_creation(
        self,
    ) -> None:
        repos = _repos(_LESSONS, _SKILLS)

        with pytest.raises(InvalidCompletionTimestampError):
            await complete_lesson(
                user_id="u1",
                lesson_id="lesson-a1",
                attempt_id="attempt-1",
                correct_count=4,
                total_count=4,
                time_spent_seconds=30.0,
                daily_xp_target=40,
                client_completed_at=_ACCOUNT_CREATED_AT - timedelta(days=1),
                account_created_at=_ACCOUNT_CREATED_AT,
                now=_NOW,
                **repos,
            )
        assert repos["attempt_repo"].add_calls == 0

    async def test_accepts_a_completion_from_long_before_now_for_a_long_offline_gap(self) -> None:
        # No upper bound on staleness -- a lesson finished 45 days ago,
        # finally syncing "now", must still be accepted (requirements.md
        # FR-3: long offline gaps are supported, not penalized).
        repos = _repos(_LESSONS, _SKILLS)

        outcome = await complete_lesson(
            user_id="u1",
            lesson_id="lesson-a1",
            attempt_id="attempt-1",
            correct_count=4,
            total_count=4,
            time_spent_seconds=30.0,
            daily_xp_target=40,
            client_completed_at=_NOW - timedelta(days=45),
            account_created_at=_ACCOUNT_CREATED_AT,
            now=_NOW,
            **repos,
        )

        assert outcome.xp_awarded == 4 * XP_PER_CORRECT_ANSWER
        assert repos["attempt_repo"].add_calls == 1

    async def test_idempotent_replay_after_a_multi_day_delay(self) -> None:
        # The idempotency check (attempt_repo.get first) must short-circuit
        # a replay regardless of how much real time (`now`) has passed
        # between the original call and the retry -- story 003's "delayed,
        # not just near-immediate replay" requirement.
        repos = _repos(_LESSONS, _SKILLS)
        kwargs = dict(
            user_id="u1",
            lesson_id="lesson-a1",
            attempt_id="attempt-1",
            correct_count=4,
            total_count=4,
            time_spent_seconds=30.0,
            daily_xp_target=40,
            client_completed_at=_NOW,
            account_created_at=_ACCOUNT_CREATED_AT,
            **repos,
        )

        first = await complete_lesson(now=_NOW, **kwargs)
        second = await complete_lesson(now=_NOW + timedelta(days=2), **kwargs)

        assert first == second
        assert repos["attempt_repo"].add_calls == 1


class TestGetBeansStatus:
    async def test_new_user_gets_full_beans_and_starting_amole(self) -> None:
        beans_repo = FakeUserBeansRepository()
        amole_repo = FakeAmoleTransactionRepository()

        result = await get_beans_status("u1", beans_repo, amole_repo, _NOW)

        assert result.beans == BEANS_MAX
        assert result.amole_balance == STARTING_AMOLE_BALANCE
        assert result.next_bean_at is None  # already full

    async def test_never_writes_a_beans_row_on_a_pure_read(self) -> None:
        beans_repo = FakeUserBeansRepository()
        amole_repo = FakeAmoleTransactionRepository()

        await get_beans_status("u1", beans_repo, amole_repo, _NOW)

        assert await beans_repo.get("u1") is None

    async def test_repeated_reads_grant_the_starting_balance_exactly_once(self) -> None:
        # `_ensure_amole_wallet` is idempotent -- calling the balance read
        # twice must not double-grant `STARTING_AMOLE_BALANCE` (bolt 017's
        # lazy-wallet-creation design, ddd-02-technical-design.md).
        beans_repo = FakeUserBeansRepository()
        amole_repo = FakeAmoleTransactionRepository()

        first = await get_beans_status("u1", beans_repo, amole_repo, _NOW)
        second = await get_beans_status("u1", beans_repo, amole_repo, _NOW)

        assert first.amole_balance == STARTING_AMOLE_BALANCE
        assert second.amole_balance == STARTING_AMOLE_BALANCE


class TestRefillBeans:
    async def test_success_deducts_amole_and_maxes_out_beans(self) -> None:
        beans_repo = FakeUserBeansRepository(
            [UserBeans(user_id="u1", current_count=0, last_regen_at=_NOW)]
        )
        amole_repo = FakeAmoleTransactionRepository(
            [
                AmoleTransaction(
                    id="t1",
                    user_id="u1",
                    amount=500,
                    source=AmoleSource.WALLET_CREATED,
                    reference_id="u1",
                    created_at=_NOW,
                )
            ]
        )

        result = await refill_beans("u1", beans_repo, amole_repo, _NOW)

        assert result.beans == BEANS_MAX
        assert result.amole_balance == 500 - REFILL_COST_AMOLE

    async def test_raises_insufficient_amole_when_balance_too_low(self) -> None:
        beans_repo = FakeUserBeansRepository(
            [UserBeans(user_id="u1", current_count=0, last_regen_at=_NOW)]
        )
        amole_repo = FakeAmoleTransactionRepository(
            [
                AmoleTransaction(
                    id="t1",
                    user_id="u1",
                    amount=10,
                    source=AmoleSource.WALLET_CREATED,
                    reference_id="u1",
                    created_at=_NOW,
                )
            ]
        )

        with pytest.raises(InsufficientAmoleError):
            await refill_beans("u1", beans_repo, amole_repo, _NOW)

    async def test_posts_a_bean_refill_ledger_row(self) -> None:
        beans_repo = FakeUserBeansRepository(
            [UserBeans(user_id="u1", current_count=0, last_regen_at=_NOW)]
        )
        amole_repo = FakeAmoleTransactionRepository(
            [
                AmoleTransaction(
                    id="t1",
                    user_id="u1",
                    amount=500,
                    source=AmoleSource.WALLET_CREATED,
                    reference_id="u1",
                    created_at=_NOW,
                )
            ]
        )

        await refill_beans("u1", beans_repo, amole_repo, _NOW)

        assert amole_repo.add_calls == 1


class TestCompleteLessonAmoleAwards:
    """Bolt 017 (intent 007-amole-currency): `complete_lesson` gains
    Amole-award side effects alongside its existing Beans/XP/streak
    orchestration.
    """

    async def test_awards_flat_amount_and_perfect_bonus_for_a_perfect_lesson(self) -> None:
        repos = _repos(_LESSONS, _SKILLS)

        await complete_lesson(
            user_id="u1",
            lesson_id="lesson-a1",
            attempt_id="attempt-1",
            correct_count=4,
            total_count=4,
            time_spent_seconds=30.0,
            daily_xp_target=40,
            now=_NOW,
            client_completed_at=_NOW,
            account_created_at=_ACCOUNT_CREATED_AT,
            **repos,
        )

        balance = await repos["amole_repo"].sum_by_user("u1")
        assert balance == AMOLE_LESSON_COMPLETION_AWARD + AMOLE_PERFECT_LESSON_BONUS

    async def test_no_perfect_bonus_for_an_imperfect_lesson(self) -> None:
        repos = _repos(_LESSONS, _SKILLS)

        await complete_lesson(
            user_id="u1",
            lesson_id="lesson-a1",
            attempt_id="attempt-1",
            correct_count=3,
            total_count=4,
            time_spent_seconds=30.0,
            daily_xp_target=40,
            now=_NOW,
            client_completed_at=_NOW,
            account_created_at=_ACCOUNT_CREATED_AT,
            **repos,
        )

        balance = await repos["amole_repo"].sum_by_user("u1")
        assert balance == AMOLE_LESSON_COMPLETION_AWARD

    async def test_awards_streak_milestone_bonus_exactly_on_the_crossing_completion(self) -> None:
        repos = _repos(_LESSONS, _SKILLS)
        # Streak already at 6 -- this completion pushes it to 7, crossing
        # the milestone.
        await repos["streak_repo"].upsert(
            UserStreak(
                user_id="u1",
                current_streak=6,
                last_completed_date=(_NOW - timedelta(days=1)).date(),
                active_freeze_count=0,
            )
        )

        await complete_lesson(
            user_id="u1",
            lesson_id="lesson-a1",
            attempt_id="attempt-1",
            correct_count=4,
            total_count=4,
            time_spent_seconds=30.0,
            daily_xp_target=40,
            now=_NOW,
            client_completed_at=_NOW,
            account_created_at=_ACCOUNT_CREATED_AT,
            **repos,
        )

        balance = await repos["amole_repo"].sum_by_user("u1")
        expected = (
            AMOLE_LESSON_COMPLETION_AWARD
            + AMOLE_PERFECT_LESSON_BONUS
            + AMOLE_STREAK_MILESTONE_7_BONUS
        )
        assert balance == expected

    async def test_awards_both_milestone_bonuses_when_crossing_30_from_29(self) -> None:
        repos = _repos(_LESSONS, _SKILLS)
        await repos["streak_repo"].upsert(
            UserStreak(
                user_id="u1",
                current_streak=29,
                last_completed_date=(_NOW - timedelta(days=1)).date(),
                active_freeze_count=0,
            )
        )

        await complete_lesson(
            user_id="u1",
            lesson_id="lesson-a1",
            attempt_id="attempt-1",
            correct_count=4,
            total_count=4,
            time_spent_seconds=30.0,
            daily_xp_target=40,
            now=_NOW,
            client_completed_at=_NOW,
            account_created_at=_ACCOUNT_CREATED_AT,
            **repos,
        )

        balance = await repos["amole_repo"].sum_by_user("u1")
        expected = (
            AMOLE_LESSON_COMPLETION_AWARD
            + AMOLE_PERFECT_LESSON_BONUS
            + AMOLE_STREAK_MILESTONE_30_BONUS
        )
        assert balance == expected

    async def test_no_repeat_milestone_bonus_once_past_the_threshold(self) -> None:
        repos = _repos(_LESSONS, _SKILLS)
        # Streak already at 10 -- past the 7-day milestone, not crossing it
        # on this completion.
        await repos["streak_repo"].upsert(
            UserStreak(
                user_id="u1",
                current_streak=10,
                last_completed_date=(_NOW - timedelta(days=1)).date(),
                active_freeze_count=0,
            )
        )

        await complete_lesson(
            user_id="u1",
            lesson_id="lesson-a1",
            attempt_id="attempt-1",
            correct_count=4,
            total_count=4,
            time_spent_seconds=30.0,
            daily_xp_target=40,
            now=_NOW,
            client_completed_at=_NOW,
            account_created_at=_ACCOUNT_CREATED_AT,
            **repos,
        )

        balance = await repos["amole_repo"].sum_by_user("u1")
        assert balance == AMOLE_LESSON_COMPLETION_AWARD + AMOLE_PERFECT_LESSON_BONUS

    async def test_retried_completion_does_not_double_award(self) -> None:
        repos = _repos(_LESSONS, _SKILLS)
        kwargs = dict(
            user_id="u1",
            lesson_id="lesson-a1",
            attempt_id="attempt-1",
            correct_count=4,
            total_count=4,
            time_spent_seconds=30.0,
            daily_xp_target=40,
            client_completed_at=_NOW,
            account_created_at=_ACCOUNT_CREATED_AT,
            **repos,
        )

        await complete_lesson(now=_NOW, **kwargs)
        await complete_lesson(now=_NOW, **kwargs)

        balance = await repos["amole_repo"].sum_by_user("u1")
        assert balance == AMOLE_LESSON_COMPLETION_AWARD + AMOLE_PERFECT_LESSON_BONUS


_VOCAB_LESSON = _lesson("lesson-vocab", "skill-a", 1, vocab_item_ids={0: "vocab-hello"})


class TestCompleteLessonVocabProgress:
    """Bolt 019 (008-srs-and-practice, ADR-10): `complete_lesson` gains a
    vocab-progress side effect for every vocab-linked exercise in the
    lesson.
    """

    async def test_first_appearance_creates_a_row_at_box_1(self) -> None:
        repos = _repos([_VOCAB_LESSON], _SKILLS)

        await complete_lesson(
            user_id="u1",
            lesson_id="lesson-vocab",
            attempt_id="attempt-1",
            correct_count=4,
            total_count=4,
            time_spent_seconds=30.0,
            daily_xp_target=40,
            now=_NOW,
            client_completed_at=_NOW,
            account_created_at=_ACCOUNT_CREATED_AT,
            **repos,
        )

        progress = await repos["vocab_progress_repo"].get("u1", "vocab-hello")
        assert progress is not None
        assert progress.box_level == 1
        assert progress.next_review_at == _NOW + timedelta(days=1)

    async def test_seen_before_and_answered_correctly_moves_up_one_box(self) -> None:
        repos = _repos([_VOCAB_LESSON], _SKILLS)
        await repos["vocab_progress_repo"].upsert(
            UserVocabProgress(
                user_id="u1",
                vocab_item_id="vocab-hello",
                box_level=2,
                next_review_at=_NOW - timedelta(days=1),
                last_seen_at=_NOW - timedelta(days=4),
            )
        )

        await complete_lesson(
            user_id="u1",
            lesson_id="lesson-vocab",
            attempt_id="attempt-1",
            correct_count=4,
            total_count=4,
            time_spent_seconds=30.0,
            daily_xp_target=40,
            now=_NOW,
            client_completed_at=_NOW,
            account_created_at=_ACCOUNT_CREATED_AT,
            missed_exercise_ids=frozenset(),
            **repos,
        )

        progress = await repos["vocab_progress_repo"].get("u1", "vocab-hello")
        assert progress.box_level == 3
        assert progress.next_review_at == _NOW + timedelta(days=7)

    async def test_seen_before_and_missed_resets_to_box_1(self) -> None:
        repos = _repos([_VOCAB_LESSON], _SKILLS)
        await repos["vocab_progress_repo"].upsert(
            UserVocabProgress(
                user_id="u1",
                vocab_item_id="vocab-hello",
                box_level=4,
                next_review_at=_NOW - timedelta(days=1),
                last_seen_at=_NOW - timedelta(days=15),
            )
        )

        await complete_lesson(
            user_id="u1",
            lesson_id="lesson-vocab",
            attempt_id="attempt-1",
            correct_count=3,
            total_count=4,
            time_spent_seconds=30.0,
            daily_xp_target=40,
            now=_NOW,
            client_completed_at=_NOW,
            account_created_at=_ACCOUNT_CREATED_AT,
            missed_exercise_ids=frozenset({"lesson-vocab-e0"}),
            **repos,
        )

        progress = await repos["vocab_progress_repo"].get("u1", "vocab-hello")
        assert progress.box_level == 1
        assert progress.next_review_at == _NOW + timedelta(days=1)

    async def test_no_vocab_linked_exercises_writes_nothing_and_raises_nothing(self) -> None:
        repos = _repos(_LESSONS, _SKILLS)

        await complete_lesson(
            user_id="u1",
            lesson_id="lesson-a1",
            attempt_id="attempt-1",
            correct_count=4,
            total_count=4,
            time_spent_seconds=30.0,
            daily_xp_target=40,
            now=_NOW,
            client_completed_at=_NOW,
            account_created_at=_ACCOUNT_CREATED_AT,
            **repos,
        )

        assert await repos["vocab_progress_repo"].count_due("u1", _NOW + timedelta(days=365)) == 0

    async def test_retried_completion_does_not_double_update_vocab_progress(self) -> None:
        repos = _repos([_VOCAB_LESSON], _SKILLS)
        kwargs = dict(
            user_id="u1",
            lesson_id="lesson-vocab",
            attempt_id="attempt-1",
            correct_count=4,
            total_count=4,
            time_spent_seconds=30.0,
            daily_xp_target=40,
            client_completed_at=_NOW,
            account_created_at=_ACCOUNT_CREATED_AT,
            **repos,
        )

        await complete_lesson(now=_NOW, **kwargs)
        await complete_lesson(now=_NOW, **kwargs)

        progress = await repos["vocab_progress_repo"].get("u1", "vocab-hello")
        assert progress.box_level == 1  # still first-appearance box, not advanced twice
