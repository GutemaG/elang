"""Unit tests: the Sounds chart templates and the rule for showing a chart
(`app/domain/sounds.py`)."""

from __future__ import annotations

import unicodedata

import pytest

from app.domain.sounds import (
    FIDEL_ORDERS,
    TEMPLATES,
    LetterFacts,
    chart_template,
    missing_for_learners,
)


class TestFidel:
    def test_has_every_family_in_seven_orders_then_the_labialised_letters(self) -> None:
        chart = chart_template("fidel")
        fidel = [x for x in chart.letters if x.group == "fidel"]
        labialised = [x for x in chart.letters if x.group == "labialised"]

        assert len(fidel) == 34 * 7
        assert len(labialised) == 22
        assert [g.key for g in chart.groups] == ["fidel", "labialised"]
        assert chart.groups[0].columns == 7
        assert chart.groups[0].column_labels == FIDEL_ORDERS

    def test_rows_run_through_the_orders(self) -> None:
        fidel = [x for x in chart_template("fidel").letters if x.group == "fidel"]

        assert [x.glyph for x in fidel[:7]] == list("ሀሁሂሃሄህሆ")
        assert [x.romanization for x in fidel[:7]] == ["he", "hu", "hi", "ha", "hé", "hə", "ho"]
        assert fidel[-1].glyph == "ፖ"
        # Every glyph is a real Ethiopic syllable, and none repeats.
        assert all(unicodedata.name(x.glyph).startswith("ETHIOPIC SYLLABLE") for x in fidel)
        assert len({x.glyph for x in fidel}) == len(fidel)

    def test_labialised_letters_are_the_wa_forms(self) -> None:
        labialised = [x for x in chart_template("fidel").letters if x.group == "labialised"]

        for letter in labialised:
            assert unicodedata.name(letter.glyph).endswith(("WA", "WAA"))
            assert letter.romanization.endswith("wa")

    def test_letters_that_sound_alike_point_at_the_one_recorded(self) -> None:
        letters = chart_template("fidel").letters
        same = {x.glyph: x.same_as for x in letters if x.same_as}

        # ሐ, ኀ (both as ሀ), ሠ (as ሰ), ዐ (as አ) and ፀ (as ጸ), in all seven orders.
        assert len(same) == 5 * 7
        assert same["ሐ"] == "ሀ" and same["ኆ"] == "ሆ"
        assert same["ሡ"] == "ሱ"
        assert same["ዐ"] == "አ"
        assert same["ፆ"] == "ጾ"
        # Each points at a letter with a sound of its own.
        own = {x.glyph for x in letters if not x.same_as}
        assert set(same.values()) <= own


class TestQubee:
    def test_is_a_to_z_then_letter_pairs_and_long_vowels(self) -> None:
        chart = chart_template("qubee")
        sizes = {g.key: sum(1 for x in chart.letters if x.group == g.key) for g in chart.groups}

        assert sizes == {"alphabet": 27, "pairs": 5, "long_vowels": 5}
        assert chart.groups[0].names["en"] == "A–Z"
        assert all(g.columns is None for g in chart.groups)
        alphabet = [x.glyph for x in chart.letters if x.group == "alphabet"]
        assert alphabet[:3] == ["A a", "B b", "C c"]
        assert alphabet[-2:] == ["Z z", "'"]

    def test_marks_every_letter_a_vowel_or_a_consonant(self) -> None:
        letters = chart_template("qubee").letters
        vowels = [x.glyph for x in letters if x.kind == "vowel"]

        assert vowels == ["A a", "E e", "I i", "O o", "U u", "aa", "ee", "ii", "oo", "uu"]
        assert all(x.kind == "consonant" for x in letters if x.glyph not in vowels)
        assert all(x.kind is None for x in chart_template("fidel").letters)

    def test_marks_the_sounds_english_has_not_got(self) -> None:
        by_glyph = {x.glyph: x for x in chart_template("qubee").letters}

        assert by_glyph["C c"].romanization == "ch'"
        assert by_glyph["Q q"].romanization == "k'"
        assert by_glyph["X x"].romanization == "t'"
        assert "throat" in by_glyph["X x"].hint["en"]
        assert by_glyph["'"].hint["en"].startswith("Hudhaa")


def test_every_template_is_known_and_an_unknown_one_is_not() -> None:
    for name in TEMPLATES:
        assert chart_template(name).title["en"]
    with pytest.raises(KeyError):
        chart_template("cyrillic")


class TestMissingForLearners:
    def test_nothing_is_missing_once_every_sound_can_play(self) -> None:
        gaps = missing_for_learners(
            [
                LetterFacts(id="a", romanization="he", has_audio=True, same_as_id=None),
                LetterFacts(id="b", romanization="he", has_audio=False, same_as_id="a"),
            ]
        )
        assert not gaps.any

    def test_counts_letters_without_romanization_or_a_sound(self) -> None:
        gaps = missing_for_learners(
            [
                LetterFacts(id="a", romanization="he", has_audio=False, same_as_id=None),
                LetterFacts(id="b", romanization=" ", has_audio=False, same_as_id="a"),
                LetterFacts(id="c", romanization="lu", has_audio=True, same_as_id=None),
            ]
        )
        # `b` borrows `a`'s sound, which has none yet.
        assert (gaps.no_romanization, gaps.no_audio, gaps.no_letters) == (1, 2, False)
        assert gaps.any

    def test_an_empty_chart_is_never_ready(self) -> None:
        assert missing_for_learners([]).no_letters
