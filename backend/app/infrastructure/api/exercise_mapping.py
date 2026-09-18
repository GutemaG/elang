"""Maps a domain `Exercise` to its discriminated-union API response shape.

Extracted from `lesson_routers.py` (bolt `020-practice-ui`) so
`practice_routers.py`'s due-items endpoint can serialize exercise content
identically, without duplicating the per-type mapping logic.
"""

from __future__ import annotations

from app.domain.lesson.entities import Exercise
from app.domain.lesson.value_objects import (
    ChoiceAnswerKey,
    ExerciseType,
    ListeningContent,
    MatchPairsContent,
    MultipleChoiceContent,
    PairAnswerKey,
    SentenceConstructionContent,
    SequenceAnswerKey,
)
from app.infrastructure.api.lesson_schemas import (
    ChoiceResponse,
    ExerciseResponse,
    ListeningExerciseResponse,
    MatchPairsExerciseResponse,
    MultipleChoiceExerciseResponse,
    SentenceConstructionExerciseResponse,
)


def to_exercise_response(exercise: Exercise) -> ExerciseResponse:
    # Built from `exercise.content` (renderable) and `exercise.answer_key`
    # (correct-answer) -- the latter is included per ADR-5, which
    # supersedes ADR-4's "never expose correct answers".
    if exercise.type is ExerciseType.MULTIPLE_CHOICE:
        assert isinstance(exercise.content, MultipleChoiceContent)
        assert isinstance(exercise.answer_key, ChoiceAnswerKey)
        return MultipleChoiceExerciseResponse(
            id=exercise.id,
            order_index=exercise.order_index,
            prompt=exercise.prompt,
            choices=[ChoiceResponse(id=c.id, text=c.text) for c in exercise.content.choices],
            correct_choice_id=exercise.answer_key.correct_choice_id,
        )
    if exercise.type is ExerciseType.LISTENING:
        assert isinstance(exercise.content, ListeningContent)
        assert isinstance(exercise.answer_key, ChoiceAnswerKey)
        return ListeningExerciseResponse(
            id=exercise.id,
            order_index=exercise.order_index,
            prompt=exercise.prompt,
            audio_url=exercise.content.audio_url,
            choices=[ChoiceResponse(id=c.id, text=c.text) for c in exercise.content.choices],
            correct_choice_id=exercise.answer_key.correct_choice_id,
        )
    if exercise.type is ExerciseType.SENTENCE_CONSTRUCTION:
        assert isinstance(exercise.content, SentenceConstructionContent)
        assert isinstance(exercise.answer_key, SequenceAnswerKey)
        return SentenceConstructionExerciseResponse(
            id=exercise.id,
            order_index=exercise.order_index,
            prompt=exercise.prompt,
            word_bank=[ChoiceResponse(id=c.id, text=c.text) for c in exercise.content.word_bank],
            correct_sequence=list(exercise.answer_key.correct_sequence),
        )
    assert isinstance(exercise.content, MatchPairsContent)
    assert isinstance(exercise.answer_key, PairAnswerKey)
    return MatchPairsExerciseResponse(
        id=exercise.id,
        order_index=exercise.order_index,
        prompt=exercise.prompt,
        left_tiles=[ChoiceResponse(id=c.id, text=c.text) for c in exercise.content.left_tiles],
        right_tiles=[ChoiceResponse(id=c.id, text=c.text) for c in exercise.content.right_tiles],
        correct_pairs=list(exercise.answer_key.correct_pairs),
    )
