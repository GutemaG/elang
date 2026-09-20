"""Unit tests for lesson-content value object invariants."""

from __future__ import annotations

import pytest

from app.domain.lesson.value_objects import Choice as ChoiceVO
from app.domain.lesson.value_objects import (
    ChoiceAnswerKey,
    CrownLevel,
    GapFillContent,
    ListeningContent,
    MatchPairsContent,
    MultipleChoiceContent,
    PairAnswerKey,
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


class TestMatchPairsContent:
    def test_requires_at_least_two_left_tiles(self) -> None:
        with pytest.raises(ValueError, match="at least 2 left tiles"):
            MatchPairsContent(
                left_tiles=(ChoiceVO(id="l1", text="ቡና"),),
                right_tiles=(ChoiceVO(id="r1", text="Coffee"),),
            )

    def test_rejects_mismatched_left_and_right_tile_counts(self) -> None:
        with pytest.raises(ValueError, match="same length"):
            MatchPairsContent(
                left_tiles=(ChoiceVO(id="l1", text="ቡና"), ChoiceVO(id="l2", text="ሻይ")),
                right_tiles=(ChoiceVO(id="r1", text="Coffee"),),
            )

    def test_accepts_equal_length_tile_columns(self) -> None:
        content = MatchPairsContent(
            left_tiles=(ChoiceVO(id="l1", text="ቡና"), ChoiceVO(id="l2", text="ሻይ")),
            right_tiles=(ChoiceVO(id="r1", text="Coffee"), ChoiceVO(id="r2", text="Tea")),
        )
        assert len(content.left_tiles) == len(content.right_tiles) == 2


class TestGapFillContent:
    """015-gap-fill-exercise-type (bolt 030). The sentence is stored as the
    text either side of the gap, so a gap at the very start or end is an
    empty string rather than a special case -- three of the four
    hand-written English to Amharic gap-fills are exactly that.
    """

    def test_rejects_a_sentence_that_is_empty_on_both_sides(self) -> None:
        with pytest.raises(ValueError, match="at least one side"):
            GapFillContent(
                sentence_before="",
                sentence_after="",
                choices=(ChoiceVO(id="a", text="ቡና"), ChoiceVO(id="b", text="ሻይ")),
            )

    def test_requires_at_least_two_choices(self) -> None:
        with pytest.raises(ValueError, match="at least 2 choices"):
            GapFillContent(
                sentence_before="ቡና",
                sentence_after="",
                choices=(ChoiceVO(id="a", text="እፈልጋለሁ"),),
            )

    def test_accepts_a_gap_at_the_start_of_the_sentence(self) -> None:
        content = GapFillContent(
            sentence_before="",
            sentence_after="እፈልጋለሁ",
            choices=(ChoiceVO(id="a", text="ቡና"), ChoiceVO(id="b", text="ሻይ")),
        )

        assert content.sentence_before == ""
        assert content.sentence_after == "እፈልጋለሁ"

    def test_accepts_a_gap_at_the_end_of_the_sentence(self) -> None:
        content = GapFillContent(
            sentence_before="አዎ",
            sentence_after="",
            choices=(ChoiceVO(id="a", text="እባክዎ"), ChoiceVO(id="b", text="አይ")),
        )

        assert content.sentence_before == "አዎ"
        assert content.sentence_after == ""

    def test_accepts_a_gap_in_the_middle_of_the_sentence(self) -> None:
        content = GapFillContent(
            sentence_before="Daabboo",
            sentence_after="barbaada",
            choices=(ChoiceVO(id="a", text="nan"), ChoiceVO(id="b", text="Nyaata")),
        )

        assert (content.sentence_before, content.sentence_after) == ("Daabboo", "barbaada")

    def test_the_missing_word_is_not_stored_in_the_content(self) -> None:
        # It lives only in the sibling `ChoiceAnswerKey`. A token-list-plus-
        # index shape would have leaked it into `content` as well.
        content = GapFillContent(
            sentence_before="",
            sentence_after="እፈልጋለሁ",
            choices=(ChoiceVO(id="a", text="ቡና"), ChoiceVO(id="b", text="ሻይ")),
        )

        assert "ቡና" not in content.sentence_before + content.sentence_after


class TestAnswerKeys:
    def test_choice_answer_key_rejects_empty_id(self) -> None:
        with pytest.raises(ValueError, match="correct_choice_id"):
            ChoiceAnswerKey(correct_choice_id="")

    def test_sequence_answer_key_requires_at_least_one_id(self) -> None:
        with pytest.raises(ValueError, match="correct_sequence"):
            SequenceAnswerKey(correct_sequence=())

    def test_pair_answer_key_requires_at_least_two_pairs(self) -> None:
        with pytest.raises(ValueError, match="at least 2 pairs"):
            PairAnswerKey(correct_pairs=(("l1", "r1"),))

    def test_pair_answer_key_accepts_two_or_more_pairs(self) -> None:
        key = PairAnswerKey(correct_pairs=(("l1", "r1"), ("l2", "r2")))
        assert key.correct_pairs == (("l1", "r1"), ("l2", "r2"))

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
