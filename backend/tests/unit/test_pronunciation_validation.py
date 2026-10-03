"""Unit tests: romanization on exercises. A text tile may carry a
`pronunciation` (`ቡና` -> `bunna`), and so may the question itself, as
`content.pronunciation`; both are optional, and both are refused when empty
or misplaced, naming the field.
"""

from __future__ import annotations

from typing import Any

import pytest

from app.domain.lesson.exceptions import InvalidExerciseError
from app.domain.lesson.exercise_parts import (
    MAX_PRONUNCIATION_LENGTH,
    choices_from_json,
    validate_exercise,
)

_CHOICES = [
    {"id": "a", "text": "ቡና", "pronunciation": "bunna"},
    {"id": "b", "text": "ሻይ"},
]


def _mc(**content: Any) -> dict[str, Any]:
    return {"choices": _CHOICES, **content}


def _refused(exercise_type: str, content: dict[str, Any], answer_key: dict[str, Any]) -> str:
    with pytest.raises(InvalidExerciseError) as caught:
        validate_exercise(exercise_type, "How do you say 'coffee'?", content, answer_key)
    return caught.value.field


def test_a_tile_and_the_question_may_each_have_a_pronunciation() -> None:
    validate_exercise(
        "multiple_choice",
        "What does 'ቡና' mean?",
        _mc(pronunciation="bunna"),
        {"correct_choice_id": "a"},
    )


def test_every_text_tile_list_accepts_pronunciations() -> None:
    tiles = [
        {"id": "t1", "text": "ቡ", "pronunciation": "bu"},
        {"id": "t2", "text": "ና", "pronunciation": "na"},
    ]
    validate_exercise(
        "spell_tiles", "Spell 'coffee'", {"tiles": tiles}, {"correct_sequence": ["t1", "t2"]}
    )
    validate_exercise(
        "sentence_construction",
        "Translate: 'coffee'",
        {"word_bank": tiles},
        {"correct_sequence": ["t1"]},
    )
    validate_exercise(
        "match_pairs",
        "Match",
        {
            "left_tiles": [
                {"id": "l1", "text": "ቡና", "pronunciation": "bunna"},
                {"id": "l2", "text": "ሻይ", "pronunciation": "shay"},
            ],
            "right_tiles": [{"id": "r1", "text": "coffee"}, {"id": "r2", "text": "tea"}],
        },
        {"correct_pairs": [["l1", "r1"], ["l2", "r2"]]},
    )
    validate_exercise(
        "gap_fill",
        "Complete the sentence: 'I want bread'",
        {
            "sentence_before": "",
            "sentence_after": "እፈልጋለሁ",
            "choices": tiles,
            "pronunciation": "___ ifeligalehu",
        },
        {"correct_choice_id": "t1"},
    )


@pytest.mark.parametrize("value", ["", "   ", 3, None])
def test_an_empty_or_non_text_tile_pronunciation_is_refused(value: Any) -> None:
    choices = [{"id": "a", "text": "ቡና", "pronunciation": value}, {"id": "b", "text": "ሻይ"}]
    field = _refused("multiple_choice", {"choices": choices}, {"correct_choice_id": "a"})
    assert field == "content.choices[0].pronunciation"


@pytest.mark.parametrize("value", ["", "  ", ["bunna"]])
def test_an_empty_or_non_text_question_pronunciation_is_refused(value: Any) -> None:
    field = _refused("multiple_choice", _mc(pronunciation=value), {"correct_choice_id": "a"})
    assert field == "content.pronunciation"


def test_a_pronunciation_too_long_is_refused() -> None:
    long = "a" * (MAX_PRONUNCIATION_LENGTH + 1)
    field = _refused("multiple_choice", _mc(pronunciation=long), {"correct_choice_id": "a"})
    assert field == "content.pronunciation"


def test_a_misspelt_tile_key_is_still_refused() -> None:
    choices = [{"id": "a", "text": "ቡና", "pronounciation": "bunna"}, {"id": "b", "text": "ሻይ"}]
    field = _refused("multiple_choice", {"choices": choices}, {"correct_choice_id": "a"})
    assert field == "content.choices[0]"


@pytest.mark.parametrize("exercise_type", ["listening", "audio_image_choice"])
def test_a_question_that_is_only_heard_takes_no_question_pronunciation(
    exercise_type: str,
) -> None:
    choices = (
        _CHOICES
        if exercise_type == "listening"
        else [
            {"id": "a", "image_url": "https://cdn.example/a.webp", "alt_text": "A"},
            {"id": "b", "image_url": "https://cdn.example/b.webp", "alt_text": "B"},
        ]
    )
    content = {
        "audio_url": "https://cdn.example/a.m4a",
        "choices": choices,
        "pronunciation": "bunna",
    }
    field = _refused(exercise_type, content, {"correct_choice_id": "a"})
    assert field == "content.pronunciation"


def test_a_listening_question_s_tiles_may_still_have_pronunciations() -> None:
    validate_exercise(
        "listening",
        "What did you hear?",
        {"audio_url": "https://cdn.example/a.m4a", "choices": _CHOICES},
        {"correct_choice_id": "a"},
    )


def test_tiles_read_back_with_their_pronunciation_or_none() -> None:
    first, second = choices_from_json(_CHOICES)
    assert first.pronunciation == "bunna"
    assert second.pronunciation is None
