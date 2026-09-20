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
    GapFillContent,
    ListeningContent,
    MatchPairsContent,
    MultipleChoiceContent,
    PairAnswerKey,
    SentenceConstructionContent,
    SequenceAnswerKey,
    SpellTilesContent,
)
from app.infrastructure.api.lesson_schemas import (
    ChoiceResponse,
    ExerciseResponse,
    GapFillExerciseResponse,
    ListeningExerciseResponse,
    MatchPairsExerciseResponse,
    MultipleChoiceExerciseResponse,
    SentenceConstructionExerciseResponse,
    SpellTilesExerciseResponse,
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
    if exercise.type is ExerciseType.MATCH_PAIRS:
        assert isinstance(exercise.content, MatchPairsContent)
        assert isinstance(exercise.answer_key, PairAnswerKey)
        return MatchPairsExerciseResponse(
            id=exercise.id,
            order_index=exercise.order_index,
            prompt=exercise.prompt,
            left_tiles=[ChoiceResponse(id=c.id, text=c.text) for c in exercise.content.left_tiles],
            right_tiles=[
                ChoiceResponse(id=c.id, text=c.text) for c in exercise.content.right_tiles
            ],
            correct_pairs=list(exercise.answer_key.correct_pairs),
        )
    # Match-pairs used to be the unguarded final branch here; bolt 030 made
    # it explicit but left `gap_fill` holding the same position, so the trap
    # had moved rather than closed -- a `spell_tiles` exercise would have
    # fallen in and failed on an `isinstance` assertion naming `GapFillContent`.
    # Bolt 032 names every type and ends in a `raise`, matching
    # `_content_from_json`. Keep it that way: the next type should fail
    # here loudly, not be absorbed quietly.
    if exercise.type is ExerciseType.GAP_FILL:
        assert isinstance(exercise.content, GapFillContent)
        assert isinstance(exercise.answer_key, ChoiceAnswerKey)
        return GapFillExerciseResponse(
            id=exercise.id,
            order_index=exercise.order_index,
            prompt=exercise.prompt,
            sentence_before=exercise.content.sentence_before,
            sentence_after=exercise.content.sentence_after,
            choices=[ChoiceResponse(id=c.id, text=c.text) for c in exercise.content.choices],
            correct_choice_id=exercise.answer_key.correct_choice_id,
        )
    if exercise.type is ExerciseType.SPELL_TILES:
        assert isinstance(exercise.content, SpellTilesContent)
        assert isinstance(exercise.answer_key, SequenceAnswerKey)
        return SpellTilesExerciseResponse(
            id=exercise.id,
            order_index=exercise.order_index,
            prompt=exercise.prompt,
            tiles=[ChoiceResponse(id=c.id, text=c.text) for c in exercise.content.tiles],
            correct_sequence=list(exercise.answer_key.correct_sequence),
        )
    raise ValueError(f"No response mapping for exercise type {exercise.type}")
