"""Every exercise type is handled at every seam that dispatches on type
(015-gap-fill-exercise-type, bolt 030).

Adding a type means touching several places that look independent, and
until bolt 030 two of them ended in an *unguarded* match-pairs branch: a
`gap_fill` row was read as match-pairs and died on a missing `left_tiles`
key, a long way from the cause. These tests are parametrized over
`ExerciseType` itself, so a sixth type fails here the moment it is added
to the enum -- which is the point.
"""

from __future__ import annotations

from typing import Any

import pytest
from sqlalchemy import CheckConstraint

from app.domain.lesson.entities import Exercise
from app.domain.lesson.value_objects import (
    ChoiceAnswerKey,
    ExerciseType,
    GapFillContent,
    ListeningContent,
    MatchPairsContent,
    MultipleChoiceContent,
    PairAnswerKey,
    SentenceConstructionContent,
    SequenceAnswerKey,
)
from app.infrastructure.api.exercise_mapping import to_exercise_response
from app.infrastructure.api.lesson_schemas import (
    GapFillExerciseResponse,
    ListeningExerciseResponse,
    MatchPairsExerciseResponse,
    MultipleChoiceExerciseResponse,
    SentenceConstructionExerciseResponse,
)
from app.infrastructure.db.lesson_models import ExerciseModel
from app.infrastructure.db.lesson_repositories import (
    _answer_key_from_json,
    _content_from_json,
)

_CHOICES = [{"id": "a", "text": "ቡና"}, {"id": "b", "text": "ሻይ"}]

# One stored row per type: the JSON a repository would read back, and the
# domain/response classes it must produce.
_SAMPLES: dict[ExerciseType, dict[str, Any]] = {
    ExerciseType.MULTIPLE_CHOICE: {
        "content": {"choices": _CHOICES},
        "answer_key": {"correct_choice_id": "a"},
        "content_class": MultipleChoiceContent,
        "answer_class": ChoiceAnswerKey,
        "response_class": MultipleChoiceExerciseResponse,
    },
    ExerciseType.LISTENING: {
        "content": {"audio_url": "https://example.test/a.mp3", "choices": _CHOICES},
        "answer_key": {"correct_choice_id": "a"},
        "content_class": ListeningContent,
        "answer_class": ChoiceAnswerKey,
        "response_class": ListeningExerciseResponse,
    },
    ExerciseType.SENTENCE_CONSTRUCTION: {
        "content": {"word_bank": _CHOICES},
        "answer_key": {"correct_sequence": ["a", "b"]},
        "content_class": SentenceConstructionContent,
        "answer_class": SequenceAnswerKey,
        "response_class": SentenceConstructionExerciseResponse,
    },
    ExerciseType.MATCH_PAIRS: {
        "content": {"left_tiles": _CHOICES, "right_tiles": _CHOICES},
        "answer_key": {"correct_pairs": [["a", "a"], ["b", "b"]]},
        "content_class": MatchPairsContent,
        "answer_class": PairAnswerKey,
        "response_class": MatchPairsExerciseResponse,
    },
    ExerciseType.GAP_FILL: {
        "content": {"sentence_before": "ቡና", "sentence_after": "", "choices": _CHOICES},
        "answer_key": {"correct_choice_id": "a"},
        "content_class": GapFillContent,
        "answer_class": ChoiceAnswerKey,
        "response_class": GapFillExerciseResponse,
    },
}


def _exercise(exercise_type: ExerciseType) -> Exercise:
    sample = _SAMPLES[exercise_type]
    return Exercise(
        id="e1",
        lesson_id="l1",
        order_index=1,
        type=exercise_type,
        prompt="prompt",
        content=_content_from_json(exercise_type, sample["content"]),
        answer_key=_answer_key_from_json(exercise_type, sample["answer_key"]),
    )


class TestEverySeamCoversEveryType:
    def test_the_samples_cover_every_exercise_type(self) -> None:
        # Guards the tests below: a new type must be given a sample here,
        # rather than silently skipping the parametrized cases.
        assert set(_SAMPLES) == set(ExerciseType)

    @pytest.mark.parametrize("exercise_type", list(ExerciseType))
    def test_content_is_reconstructed_as_its_own_class(self, exercise_type: ExerciseType) -> None:
        sample = _SAMPLES[exercise_type]

        content = _content_from_json(exercise_type, sample["content"])

        assert isinstance(content, sample["content_class"])

    @pytest.mark.parametrize("exercise_type", list(ExerciseType))
    def test_answer_key_is_reconstructed_as_its_own_class(
        self, exercise_type: ExerciseType
    ) -> None:
        sample = _SAMPLES[exercise_type]

        answer_key = _answer_key_from_json(exercise_type, sample["answer_key"])

        assert isinstance(answer_key, sample["answer_class"])

    @pytest.mark.parametrize("exercise_type", list(ExerciseType))
    def test_the_response_is_the_right_member_of_the_union(
        self, exercise_type: ExerciseType
    ) -> None:
        response = to_exercise_response(_exercise(exercise_type))

        assert isinstance(response, _SAMPLES[exercise_type]["response_class"])
        assert response.type == exercise_type.value

    @pytest.mark.parametrize("exercise_type", list(ExerciseType))
    def test_the_check_constraint_permits_the_type(self, exercise_type: ExerciseType) -> None:
        # `ck_exercises_type` is declared twice -- here on the model, and
        # again in a migration. This catches the half that the ORM owns:
        # a type added to the enum but not to the constraint.
        constraint = next(
            arg
            for arg in ExerciseModel.__table_args__
            if isinstance(arg, CheckConstraint) and arg.name == "ck_exercises_type"
        )

        assert f"'{exercise_type.value}'" in str(constraint.sqltext)


class TestGapFillIsNotReadAsMatchPairs:
    """The specific regression bolt 030 fixed."""

    def test_gap_fill_content_is_gap_fill_content(self) -> None:
        content = _content_from_json(
            ExerciseType.GAP_FILL,
            {"sentence_before": "", "sentence_after": "እፈልጋለሁ", "choices": _CHOICES},
        )

        assert isinstance(content, GapFillContent)
        assert not isinstance(content, MatchPairsContent)

    def test_gap_fill_shares_the_choice_answer_key(self) -> None:
        # Not an accident: `multiple_choice`, `listening` and `gap_fill` all
        # ask which one of these is right, so the `AnswerKey` union stays at
        # three members for five types.
        answer_key = _answer_key_from_json(ExerciseType.GAP_FILL, {"correct_choice_id": "b"})

        assert isinstance(answer_key, ChoiceAnswerKey)
        assert answer_key.correct_choice_id == "b"
