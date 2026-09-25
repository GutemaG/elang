"""Unit tests: `validate_exercise` (story 004-exercise-write-validation, bolt
035-admin-content-api). Every seeded exercise passes; each way of breaking
one is refused with the offending field named.
"""

from __future__ import annotations

import copy
from typing import Any

import pytest

from app.domain.lesson.exceptions import InvalidExerciseError
from app.domain.lesson.exercise_parts import validate_exercise
from app.domain.lesson.value_objects import ExerciseType
from app.infrastructure.db.seed_lesson_content import CURRICULUM
from app.infrastructure.db.seed_local_audio import CURRICULUM as LOCAL_CURRICULUM


def _exercises(curriculum: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [e for s in curriculum for lesson in s["lessons"] for e in lesson["exercises"]]


SEEDED = _exercises(CURRICULUM)
LOCAL = _exercises(LOCAL_CURRICULUM)

_TILES = [{"id": "a", "text": "A"}, {"id": "b", "text": "B"}, {"id": "c", "text": "C"}]
_PICTURES = [
    {"id": "a", "image_url": "https://cdn.example/a.webp", "alt_text": "A"},
    {"id": "b", "image_url": "https://cdn.example/b.webp", "alt_text": "B"},
    {"id": "c", "image_url": "https://cdn.example/c.jpg", "alt_text": "C"},
]
# Seeded only locally, by bolt 051's picture lab: production content waits
# until its pictures are on R2, which needs the owner's go-ahead.
_LOCAL_ONLY_TYPES = {"image_choice", "audio_image_choice"}

VALID: dict[str, tuple[dict[str, Any], dict[str, Any]]] = {
    "multiple_choice": ({"choices": _TILES}, {"correct_choice_id": "b"}),
    "listening": (
        {"audio_url": "https://cdn.example/a.m4a", "choices": _TILES},
        {"correct_choice_id": "a"},
    ),
    "sentence_construction": ({"word_bank": _TILES}, {"correct_sequence": ["b", "a"]}),
    "match_pairs": (
        {
            "left_tiles": [{"id": "l1", "text": "x"}, {"id": "l2", "text": "y"}],
            "right_tiles": [{"id": "r1", "text": "X"}, {"id": "r2", "text": "Y"}],
        },
        {"correct_pairs": [["l1", "r1"], ["l2", "r2"]]},
    ),
    "gap_fill": (
        {"sentence_before": "I eat", "sentence_after": "", "choices": _TILES},
        {"correct_choice_id": "c"},
    ),
    "spell_tiles": ({"tiles": _TILES}, {"correct_sequence": ["c", "a"]}),
    "image_choice": ({"choices": _PICTURES}, {"correct_choice_id": "b"}),
    "audio_image_choice": (
        {"audio_url": "https://cdn.example/a.m4a", "choices": _PICTURES},
        {"correct_choice_id": "c"},
    ),
}


def _refused(exercise_type: str, content: Any, answer_key: Any, prompt: str = "P") -> str:
    with pytest.raises(InvalidExerciseError) as caught:
        validate_exercise(exercise_type, prompt, content, answer_key)
    return caught.value.field


def test_every_type_has_a_valid_sample() -> None:
    assert set(VALID) == {t.value for t in ExerciseType}


@pytest.mark.parametrize("exercise_type", sorted(VALID))
def test_valid_sample_is_accepted(exercise_type: str) -> None:
    content, answer_key = VALID[exercise_type]
    assert validate_exercise(exercise_type, "P", content, answer_key).value == exercise_type


@pytest.mark.parametrize("exercise", SEEDED, ids=lambda e: e["slug"])
def test_every_seeded_exercise_passes(exercise: dict[str, Any]) -> None:
    validate_exercise(
        exercise["type"], exercise["prompt"], exercise["content"], exercise["answer_key"]
    )


def test_seeded_content_covers_every_type() -> None:
    assert {e["type"] for e in SEEDED} == {t.value for t in ExerciseType} - _LOCAL_ONLY_TYPES


@pytest.mark.parametrize("exercise", LOCAL, ids=lambda e: e["slug"])
def test_local_audio_lab_passes_only_where_local_media_is_allowed(
    exercise: dict[str, Any],
) -> None:
    args = (exercise["type"], exercise["prompt"], exercise["content"], exercise["answer_key"])
    validate_exercise(*args, allow_local_media=True)
    with pytest.raises(InvalidExerciseError) as caught:
        validate_exercise(*args)
    assert caught.value.field == "content.audio_url"


class TestRefusals:
    def test_unknown_type(self) -> None:
        assert _refused("typing", {}, {}) == "type"

    @pytest.mark.parametrize("prompt", ["", "   "])
    def test_empty_prompt(self, prompt: str) -> None:
        content, key = VALID["multiple_choice"]
        assert _refused("multiple_choice", content, key, prompt=prompt) == "prompt"

    def test_answer_key_naming_a_missing_choice(self) -> None:
        content, _ = VALID["multiple_choice"]
        field = _refused("multiple_choice", content, {"correct_choice_id": "z"})
        assert field == "answer_key.correct_choice_id"

    def test_fewer_than_two_choices(self) -> None:
        field = _refused("multiple_choice", {"choices": [_TILES[0]]}, {"correct_choice_id": "a"})
        assert field == "content"

    def test_missing_content_key(self) -> None:
        assert _refused("listening", {"choices": _TILES}, {"correct_choice_id": "a"}) == (
            "content.audio_url"
        )

    def test_unknown_content_key(self) -> None:
        content, key = VALID["multiple_choice"]
        field = _refused("multiple_choice", {**content, "hint": "x"}, key)
        assert field == "content.hint"

    def test_unknown_answer_key_key(self) -> None:
        content, key = VALID["multiple_choice"]
        field = _refused("multiple_choice", content, {**key, "also": "b"})
        assert field == "answer_key.also"

    def test_content_that_is_not_an_object(self) -> None:
        assert _refused("multiple_choice", ["a"], {"correct_choice_id": "a"}) == "content"

    def test_tile_with_an_extra_field(self) -> None:
        tiles = [{"id": "a", "text": "A", "x": 1}, _TILES[1]]
        field = _refused("multiple_choice", {"choices": tiles}, {"correct_choice_id": "a"})
        assert field == "content.choices[0]"

    def test_tile_with_empty_text(self) -> None:
        tiles = [{"id": "a", "text": ""}, _TILES[1]]
        field = _refused("multiple_choice", {"choices": tiles}, {"correct_choice_id": "a"})
        assert field == "content.choices[0].text"

    def test_repeated_tile_id(self) -> None:
        tiles = [{"id": "a", "text": "A"}, {"id": "a", "text": "B"}]
        field = _refused("multiple_choice", {"choices": tiles}, {"correct_choice_id": "a"})
        assert field == "content.choices[1].id"

    def test_sequence_with_an_unknown_tile(self) -> None:
        content, _ = VALID["spell_tiles"]
        field = _refused("spell_tiles", content, {"correct_sequence": ["a", "q"]})
        assert field == "answer_key.correct_sequence[1]"

    def test_sequence_reusing_a_tile(self) -> None:
        content, _ = VALID["sentence_construction"]
        field = _refused("sentence_construction", content, {"correct_sequence": ["a", "a"]})
        assert field == "answer_key.correct_sequence"

    def test_sequence_that_is_not_a_list_of_ids(self) -> None:
        content, _ = VALID["spell_tiles"]
        field = _refused("spell_tiles", content, {"correct_sequence": "ab"})
        assert field == "answer_key.correct_sequence"

    def test_pair_using_a_right_tile_on_the_left(self) -> None:
        content, _ = VALID["match_pairs"]
        field = _refused("match_pairs", content, {"correct_pairs": [["r1", "l1"], ["l2", "r2"]]})
        assert field == "answer_key.correct_pairs[0]"

    def test_pairs_leaving_a_left_tile_unmatched(self) -> None:
        content, _ = VALID["match_pairs"]
        field = _refused("match_pairs", content, {"correct_pairs": [["l1", "r1"], ["l1", "r2"]]})
        assert field == "answer_key.correct_pairs"

    def test_malformed_pairs(self) -> None:
        content, _ = VALID["match_pairs"]
        field = _refused("match_pairs", content, {"correct_pairs": [["l1"], ["l2", "r2"]]})
        assert field == "answer_key.correct_pairs"

    def test_uneven_match_columns(self) -> None:
        content = copy.deepcopy(VALID["match_pairs"][0])
        content["right_tiles"].append({"id": "r3", "text": "Z"})
        field = _refused("match_pairs", content, VALID["match_pairs"][1])
        assert field == "content"

    def test_gap_fill_with_no_sentence(self) -> None:
        content = {"sentence_before": "", "sentence_after": "", "choices": _TILES}
        assert _refused("gap_fill", content, {"correct_choice_id": "a"}) == "content"

    @pytest.mark.parametrize(
        "url",
        ["http://cdn.example/a.m4a", "https://", "cdn.example/a.m4a", "/media/audio/a.m4a", ""],
    )
    def test_audio_url_must_be_https(self, url: str) -> None:
        field = _refused(
            "listening", {"audio_url": url, "choices": _TILES}, {"correct_choice_id": "a"}
        )
        assert field == "content.audio_url"

    def test_audio_url_that_is_not_text(self) -> None:
        field = _refused(
            "listening", {"audio_url": 5, "choices": _TILES}, {"correct_choice_id": "a"}
        )
        assert field == "content.audio_url"
