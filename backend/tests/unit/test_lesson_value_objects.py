"""Unit tests for lesson-content value object invariants."""

from __future__ import annotations

import pytest

from app.domain.lesson.value_objects import Choice as ChoiceVO
from app.domain.lesson.value_objects import (
    ChoiceAnswerKey,
    CrownLevel,
    ListeningContent,
    MultipleChoiceContent,
    SentenceConstructionContent,
    SequenceAnswerKey,
)


class TestChoice:
    def test_rejects_empty_id(self) -> None:
        with pytest.raises(ValueError, match="id"):
            ChoiceVO(id="", text="ሰላም")

    def test_rejects_empty_text(self) -> None:
        with pytest.raises(ValueError, match="text"):
            ChoiceVO(id="a", text="")

    def test_equality_by_value(self) -> None:
        assert ChoiceVO(id="a", text="ሰላም") == ChoiceVO(id="a", text="ሰላም")


class TestMultipleChoiceContent:
    def test_requires_at_least_two_choices(self) -> None:
        with pytest.raises(ValueError, match="at least 2"):
            MultipleChoiceContent(choices=(ChoiceVO(id="a", text="ሰላም"),))

    def test_accepts_two_or_more_choices(self) -> None:
        content = MultipleChoiceContent(
            choices=(ChoiceVO(id="a", text="ሰላም"), ChoiceVO(id="b", text="ደህና ሁን"))
        )
        assert len(content.choices) == 2


class TestListeningContent:
    def test_rejects_empty_audio_url(self) -> None:
        with pytest.raises(ValueError, match="audio_url"):
            ListeningContent(
                audio_url="",
                choices=(ChoiceVO(id="a", text="Hello"), ChoiceVO(id="b", text="Goodbye")),
            )

    def test_requires_at_least_two_choices(self) -> None:
        with pytest.raises(ValueError, match="at least 2"):
            ListeningContent(audio_url="https://example.com/a.mp3", choices=(ChoiceVO("a", "Hi"),))


class TestSentenceConstructionContent:
    def test_requires_at_least_one_tile(self) -> None:
        with pytest.raises(ValueError, match="at least 1"):
            SentenceConstructionContent(word_bank=())

    def test_allows_distractor_tiles_beyond_the_correct_sequence(self) -> None:
        content = SentenceConstructionContent(
            word_bank=(
                ChoiceVO(id="w1", text="ደህና"),
                ChoiceVO(id="w2", text="ነኝ"),
                ChoiceVO(id="w3", text="ጥሩ"),
            )
        )
        assert len(content.word_bank) == 3


class TestAnswerKeys:
    def test_choice_answer_key_rejects_empty_id(self) -> None:
        with pytest.raises(ValueError, match="correct_choice_id"):
            ChoiceAnswerKey(correct_choice_id="")

    def test_sequence_answer_key_requires_at_least_one_id(self) -> None:
        with pytest.raises(ValueError, match="correct_sequence"):
            SequenceAnswerKey(correct_sequence=())

    def test_sequence_answer_key_may_be_a_strict_subset_of_word_bank(self) -> None:
        # Distractor tiles (w3, w4) exist in the word bank but never appear
        # in the correct sequence -- the value object itself doesn't
        # enforce cross-referencing content, so this is just a shape check.
        key = SequenceAnswerKey(correct_sequence=("w1", "w2"))
        assert key.correct_sequence == ("w1", "w2")


class TestCrownLevel:
    @pytest.mark.parametrize("value", [0, 1, 3, 5])
    def test_accepts_values_in_range(self, value: int) -> None:
        assert CrownLevel(value=value).value == value

    @pytest.mark.parametrize("value", [-1, 6, 100])
    def test_rejects_values_out_of_range(self, value: int) -> None:
        with pytest.raises(ValueError, match="between 0 and 5"):
            CrownLevel(value=value)
