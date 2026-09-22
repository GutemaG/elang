"""An exercise's stored JSON (`content`, `answer_key`) and the domain value
objects it maps to -- one copy, shared by the learner read path
(`lesson_repositories.py`) and the admin write path (bolt
`035-admin-content-api`).

`content_from_json` / `answer_key_from_json` were lifted unchanged from
`lesson_repositories.py`. `validate_exercise` is new: the admin API calls it
before any exercise is stored. It adds the cross-checks the value objects
cannot make on their own -- an answer key referring to ids that exist in the
sibling content -- which nothing enforced before.

Pure Python, no framework imports.
"""

from __future__ import annotations

from typing import Any

from app.domain.lesson.exceptions import InvalidExerciseError
from app.domain.lesson.value_objects import (
    AnswerKey,
    Choice,
    ChoiceAnswerKey,
    ExerciseContent,
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


def choices_from_json(raw: list[dict[str, Any]]) -> tuple[Choice, ...]:
    return tuple(Choice(id=item["id"], text=item["text"]) for item in raw)


def content_from_json(exercise_type: ExerciseType, content: dict[str, Any]) -> ExerciseContent:
    if exercise_type is ExerciseType.MULTIPLE_CHOICE:
        return MultipleChoiceContent(choices=choices_from_json(content["choices"]))
    if exercise_type is ExerciseType.LISTENING:
        return ListeningContent(
            audio_url=content["audio_url"], choices=choices_from_json(content["choices"])
        )
    if exercise_type is ExerciseType.SENTENCE_CONSTRUCTION:
        return SentenceConstructionContent(word_bank=choices_from_json(content["word_bank"]))
    if exercise_type is ExerciseType.MATCH_PAIRS:
        return MatchPairsContent(
            left_tiles=choices_from_json(content["left_tiles"]),
            right_tiles=choices_from_json(content["right_tiles"]),
        )
    # Every type is now tested explicitly. Until bolt 030 the match-pairs
    # branch was the unguarded fall-through, which meant any type added
    # later was silently read as match-pairs and died on a missing
    # `left_tiles` key -- a confusing failure a long way from its cause.
    if exercise_type is ExerciseType.GAP_FILL:
        return GapFillContent(
            sentence_before=content["sentence_before"],
            sentence_after=content["sentence_after"],
            choices=choices_from_json(content["choices"]),
        )
    if exercise_type is ExerciseType.SPELL_TILES:
        return SpellTilesContent(tiles=choices_from_json(content["tiles"]))
    raise ValueError(f"No content mapping for exercise type {exercise_type}")


def answer_key_from_json(exercise_type: ExerciseType, answer_key: dict[str, Any]) -> AnswerKey:
    if exercise_type in (ExerciseType.SENTENCE_CONSTRUCTION, ExerciseType.SPELL_TILES):
        return SequenceAnswerKey(correct_sequence=tuple(answer_key["correct_sequence"]))
    if exercise_type is ExerciseType.MATCH_PAIRS:
        return PairAnswerKey(
            correct_pairs=tuple(tuple(pair) for pair in answer_key["correct_pairs"])
        )
    # `multiple_choice`, `listening` and `gap_fill` all answer the same
    # question -- which one of these is right -- so they share
    # `ChoiceAnswerKey`.
    #
    # Note this is a fall-through, not an explicit list, which makes it the
    # one place in this module where a new type is absorbed rather than
    # rejected. Bolt 030 needed no edit here because `gap_fill` genuinely
    # does answer with a choice id. Bolt 032 did: `spell_tiles` answers
    # with a sequence, and without being named above it would have fallen
    # through to here and died on a missing `correct_choice_id` -- the
    # exact trap the previous wording warned about. Any future type must
    # be checked against this, not assumed into it.
    return ChoiceAnswerKey(correct_choice_id=answer_key["correct_choice_id"])


# The keys each type's JSON may hold, and which of them are tile lists.
# Anything else is refused, so a typo cannot be stored and silently ignored.
_CONTENT_KEYS: dict[ExerciseType, frozenset[str]] = {
    ExerciseType.MULTIPLE_CHOICE: frozenset({"choices"}),
    ExerciseType.LISTENING: frozenset({"audio_url", "choices"}),
    ExerciseType.SENTENCE_CONSTRUCTION: frozenset({"word_bank"}),
    ExerciseType.MATCH_PAIRS: frozenset({"left_tiles", "right_tiles"}),
    ExerciseType.GAP_FILL: frozenset({"sentence_before", "sentence_after", "choices"}),
    ExerciseType.SPELL_TILES: frozenset({"tiles"}),
}
_TILE_LIST_KEYS = frozenset({"choices", "word_bank", "left_tiles", "right_tiles", "tiles"})
_TEXT_KEYS = frozenset({"audio_url", "sentence_before", "sentence_after"})


def _answer_keys_for(exercise_type: ExerciseType) -> frozenset[str]:
    if exercise_type in (ExerciseType.SENTENCE_CONSTRUCTION, ExerciseType.SPELL_TILES):
        return frozenset({"correct_sequence"})
    if exercise_type is ExerciseType.MATCH_PAIRS:
        return frozenset({"correct_pairs"})
    return frozenset({"correct_choice_id"})


def _check_keys(where: str, data: Any, allowed: frozenset[str]) -> None:
    if not isinstance(data, dict):
        raise InvalidExerciseError(where, f"{where} must be an object")
    for key in sorted(allowed - data.keys()):
        raise InvalidExerciseError(f"{where}.{key}", f"{where}.{key} is required")
    for key in sorted(data.keys() - allowed):
        raise InvalidExerciseError(f"{where}.{key}", f"{where}.{key} is not allowed here")


def _check_tiles(field: str, tiles: Any) -> None:
    if not isinstance(tiles, list):
        raise InvalidExerciseError(field, f"{field} must be a list")
    seen: set[str] = set()
    for i, tile in enumerate(tiles):
        where = f"{field}[{i}]"
        if not isinstance(tile, dict) or set(tile) != {"id", "text"}:
            raise InvalidExerciseError(where, f"{where} must have exactly an id and a text")
        if not isinstance(tile["id"], str) or not tile["id"]:
            raise InvalidExerciseError(f"{where}.id", f"{where}.id must be a non-empty string")
        if not isinstance(tile["text"], str) or not tile["text"]:
            raise InvalidExerciseError(f"{where}.text", f"{where}.text must be a non-empty string")
        if tile["id"] in seen:
            raise InvalidExerciseError(f"{where}.id", f"{where}.id repeats {tile['id']!r}")
        seen.add(tile["id"])


def _is_allowed_audio_url(url: str, *, allow_local_media: bool) -> bool:
    if url.startswith("https://") and len(url) > len("https://"):
        return True
    # The local-only Audio Lab plays clips the local backend serves at
    # `/media` (see `seed_local_audio.py`); nowhere else can play them.
    return allow_local_media and url.startswith("/media/")


def _cross_check(content: ExerciseContent, answer_key: AnswerKey) -> None:
    """The answer key may only name ids that exist in the content."""
    if isinstance(answer_key, ChoiceAnswerKey):
        assert isinstance(content, MultipleChoiceContent | ListeningContent | GapFillContent)
        ids = {c.id for c in content.choices}
        if answer_key.correct_choice_id not in ids:
            raise InvalidExerciseError(
                "answer_key.correct_choice_id",
                f"answer_key.correct_choice_id {answer_key.correct_choice_id!r} "
                "is not one of the choices",
            )
    elif isinstance(answer_key, SequenceAnswerKey):
        assert isinstance(content, SentenceConstructionContent | SpellTilesContent)
        tiles = (
            content.word_bank if isinstance(content, SentenceConstructionContent) else content.tiles
        )
        ids = {t.id for t in tiles}
        for i, tile_id in enumerate(answer_key.correct_sequence):
            if tile_id not in ids:
                raise InvalidExerciseError(
                    f"answer_key.correct_sequence[{i}]",
                    f"answer_key.correct_sequence[{i}] {tile_id!r} is not one of the tiles",
                )
        if len(set(answer_key.correct_sequence)) != len(answer_key.correct_sequence):
            raise InvalidExerciseError(
                "answer_key.correct_sequence",
                "answer_key.correct_sequence uses a tile more than once",
            )
    else:
        assert isinstance(content, MatchPairsContent)
        left = {t.id for t in content.left_tiles}
        right = {t.id for t in content.right_tiles}
        pairs = answer_key.correct_pairs
        for i, (left_id, right_id) in enumerate(pairs):
            if left_id not in left or right_id not in right:
                raise InvalidExerciseError(
                    f"answer_key.correct_pairs[{i}]",
                    f"answer_key.correct_pairs[{i}] must pair a left tile with a right tile",
                )
        if {p[0] for p in pairs} != left or len({p[1] for p in pairs}) != len(pairs):
            raise InvalidExerciseError(
                "answer_key.correct_pairs",
                "answer_key.correct_pairs must match every left tile to one right tile, once",
            )


def validate_exercise(
    exercise_type: str,
    prompt: str,
    content: Any,
    answer_key: Any,
    *,
    allow_local_media: bool = False,
) -> ExerciseType:
    """Raises `InvalidExerciseError` naming the first offending field, or
    returns the parsed type. Accepts exactly what `lesson_repositories.py`
    can read back and what the app can play.
    """
    try:
        parsed_type = ExerciseType(exercise_type)
    except ValueError:
        raise InvalidExerciseError(
            "type", f"type {exercise_type!r} is not an exercise type"
        ) from None
    if not isinstance(prompt, str) or not prompt.strip():
        raise InvalidExerciseError("prompt", "prompt must not be empty")

    _check_keys("content", content, _CONTENT_KEYS[parsed_type])
    for key, value in content.items():
        if key in _TILE_LIST_KEYS:
            _check_tiles(f"content.{key}", value)
        elif key in _TEXT_KEYS and not isinstance(value, str):
            raise InvalidExerciseError(f"content.{key}", f"content.{key} must be text")
    _check_keys("answer_key", answer_key, _answer_keys_for(parsed_type))

    if parsed_type is ExerciseType.LISTENING and not _is_allowed_audio_url(
        content["audio_url"], allow_local_media=allow_local_media
    ):
        raise InvalidExerciseError(
            "content.audio_url", "content.audio_url must be a full https:// address"
        )
    if parsed_type is ExerciseType.MATCH_PAIRS:
        pairs = answer_key["correct_pairs"]
        if not isinstance(pairs, list) or not all(
            isinstance(p, list) and len(p) == 2 and all(isinstance(x, str) for x in p)
            for p in pairs
        ):
            raise InvalidExerciseError(
                "answer_key.correct_pairs", "answer_key.correct_pairs must be [left, right] pairs"
            )
    elif parsed_type in (ExerciseType.SENTENCE_CONSTRUCTION, ExerciseType.SPELL_TILES):
        sequence = answer_key["correct_sequence"]
        if not isinstance(sequence, list) or not all(isinstance(x, str) for x in sequence):
            raise InvalidExerciseError(
                "answer_key.correct_sequence", "answer_key.correct_sequence must be a list of ids"
            )
    elif not isinstance(answer_key["correct_choice_id"], str):
        raise InvalidExerciseError(
            "answer_key.correct_choice_id", "answer_key.correct_choice_id must be text"
        )

    # The value objects' own invariants (at least 2 choices, equal columns,
    # ...). Their messages already name the rule; the field is the part.
    try:
        parsed_content = content_from_json(parsed_type, content)
    except ValueError as exc:
        raise InvalidExerciseError("content", str(exc)) from None
    try:
        parsed_key = answer_key_from_json(parsed_type, answer_key)
    except ValueError as exc:
        raise InvalidExerciseError("answer_key", str(exc)) from None

    _cross_check(parsed_content, parsed_key)
    return parsed_type
