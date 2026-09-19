"""Unit tests for bolt 019's `get_due_items`/`get_due_count` use cases
(story `004-due-items-and-count-endpoints`), exercised against fake
repositories.
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

from app.application.lesson_use_cases import get_due_count, get_due_items
from app.domain.lesson.entities import Exercise, Lesson, UserVocabProgress, VocabItem
from app.domain.lesson.value_objects import Choice as ChoiceVO
from app.domain.lesson.value_objects import ChoiceAnswerKey, ExerciseType, MultipleChoiceContent
from tests.fakes import (
    EN_AM_COURSE_ID,
    FakeLessonRepositoryWithSkillIndex,
    FakeUserVocabProgressRepository,
    FakeVocabItemRepository,
)

_NOW = datetime(2026, 9, 17, 12, 0, tzinfo=UTC)


def _vocab_exercise(exercise_id: str, vocab_item_id: str) -> Exercise:
    return Exercise(
        id=exercise_id,
        lesson_id="lesson-1",
        order_index=0,
        type=ExerciseType.MULTIPLE_CHOICE,
        prompt="How do you say 'Hello'?",
        content=MultipleChoiceContent(
            choices=(ChoiceVO(id="a", text="ሰላም"), ChoiceVO(id="b", text="ደህና"))
        ),
        answer_key=ChoiceAnswerKey(correct_choice_id="a"),
        vocab_item_id=vocab_item_id,
    )


class TestGetDueItems:
    async def test_returns_due_items_resolved_to_word_translation_and_exercise(self) -> None:
        lesson_repo = FakeLessonRepositoryWithSkillIndex(
            [
                Lesson(
                    id="lesson-1",
                    skill_id="skill-1",
                    title="Hello & Goodbye",
                    order_index=1,
                    exercises=[_vocab_exercise("ex-1", "vocab-hello")],
                )
            ]
        )
        vocab_item_repo = FakeVocabItemRepository(
            [
                VocabItem(
                    id="vocab-hello",
                    word="ሰላም",
                    translation="Hello",
                    created_at=_NOW,
                    course_id=EN_AM_COURSE_ID,
                )
            ]
        )
        vocab_progress_repo = FakeUserVocabProgressRepository(
            [
                UserVocabProgress(
                    user_id="u1",
                    vocab_item_id="vocab-hello",
                    box_level=2,
                    next_review_at=_NOW - timedelta(hours=1),
                    last_seen_at=_NOW - timedelta(days=3),
                )
            ]
        )

        items = await get_due_items("u1", vocab_progress_repo, vocab_item_repo, lesson_repo, _NOW)

        assert len(items) == 1
        assert items[0].vocab_item_id == "vocab-hello"
        assert items[0].word == "ሰላም"
        assert items[0].translation == "Hello"
        assert items[0].exercise.id == "ex-1"
        assert items[0].box_level == 2

    async def test_not_yet_due_items_are_excluded(self) -> None:
        lesson_repo = FakeLessonRepositoryWithSkillIndex([])
        vocab_item_repo = FakeVocabItemRepository([])
        vocab_progress_repo = FakeUserVocabProgressRepository(
            [
                UserVocabProgress(
                    user_id="u1",
                    vocab_item_id="vocab-hello",
                    box_level=2,
                    next_review_at=_NOW + timedelta(days=2),
                    last_seen_at=_NOW - timedelta(days=1),
                )
            ]
        )

        items = await get_due_items("u1", vocab_progress_repo, vocab_item_repo, lesson_repo, _NOW)

        assert items == []

    async def test_a_due_row_with_no_resolvable_exercise_is_silently_omitted(self) -> None:
        # Shouldn't happen with real content, but a due row whose vocab item
        # has no linked exercise (e.g. content was edited/removed) must not
        # crash the endpoint -- just excluded, per its own docstring.
        lesson_repo = FakeLessonRepositoryWithSkillIndex([])  # no exercises at all
        vocab_item_repo = FakeVocabItemRepository(
            [
                VocabItem(
                    id="vocab-hello",
                    word="ሰላም",
                    translation="Hello",
                    created_at=_NOW,
                    course_id=EN_AM_COURSE_ID,
                )
            ]
        )
        vocab_progress_repo = FakeUserVocabProgressRepository(
            [
                UserVocabProgress(
                    user_id="u1",
                    vocab_item_id="vocab-hello",
                    box_level=1,
                    next_review_at=_NOW - timedelta(hours=1),
                    last_seen_at=_NOW - timedelta(days=1),
                )
            ]
        )

        items = await get_due_items("u1", vocab_progress_repo, vocab_item_repo, lesson_repo, _NOW)

        assert items == []

    async def test_no_due_items_returns_empty_list(self) -> None:
        lesson_repo = FakeLessonRepositoryWithSkillIndex([])
        vocab_item_repo = FakeVocabItemRepository([])
        vocab_progress_repo = FakeUserVocabProgressRepository([])

        items = await get_due_items("u1", vocab_progress_repo, vocab_item_repo, lesson_repo, _NOW)

        assert items == []


class TestGetDueCount:
    async def test_matches_the_number_of_items_get_due_items_would_return(self) -> None:
        lesson_repo = FakeLessonRepositoryWithSkillIndex(
            [
                Lesson(
                    id="lesson-1",
                    skill_id="skill-1",
                    title="Hello & Goodbye",
                    order_index=1,
                    exercises=[
                        _vocab_exercise("ex-1", "vocab-hello"),
                        _vocab_exercise("ex-2", "vocab-goodbye"),
                    ],
                )
            ]
        )
        vocab_item_repo = FakeVocabItemRepository(
            [
                VocabItem(
                    id="vocab-hello",
                    word="ሰላም",
                    translation="Hello",
                    created_at=_NOW,
                    course_id=EN_AM_COURSE_ID,
                ),
                VocabItem(
                    id="vocab-goodbye",
                    word="ደህና ሁን",
                    translation="Goodbye",
                    created_at=_NOW,
                    course_id=EN_AM_COURSE_ID,
                ),
            ]
        )
        vocab_progress_repo = FakeUserVocabProgressRepository(
            [
                UserVocabProgress(
                    user_id="u1",
                    vocab_item_id="vocab-hello",
                    box_level=1,
                    next_review_at=_NOW - timedelta(hours=1),
                    last_seen_at=_NOW - timedelta(days=1),
                ),
                UserVocabProgress(
                    user_id="u1",
                    vocab_item_id="vocab-goodbye",
                    box_level=1,
                    next_review_at=_NOW + timedelta(days=5),
                    last_seen_at=_NOW - timedelta(days=1),
                ),
            ]
        )

        count = await get_due_count("u1", vocab_progress_repo, _NOW)
        items = await get_due_items("u1", vocab_progress_repo, vocab_item_repo, lesson_repo, _NOW)

        assert count == 1
        assert len(items) == 1

    async def test_zero_when_nothing_due(self) -> None:
        vocab_progress_repo = FakeUserVocabProgressRepository([])

        assert await get_due_count("u1", vocab_progress_repo, _NOW) == 0
