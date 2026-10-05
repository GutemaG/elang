"""Unit tests: the curriculum's rules (`app/domain/curriculum.py`)."""

from __future__ import annotations

import pytest

from app.domain.curriculum import (
    REF_PATTERN,
    Counts,
    RowFacts,
    blank_in,
    counts_of,
    ready_to_publish,
)


@pytest.mark.parametrize(
    ("text", "blank", "expected"),
    [
        ("ደህና ነኝ፣ አመሰግናለሁ", "አመሰግናለሁ", True),
        ("Nagaa dha, ati hoo?", "Nagaa", True),
        ("Nagaa dha, ati hoo?", "nagaa", False),
        ("Nagaa dha", "Akkam", False),
        (None, "Akkam", False),
        ("Nagaa dha", None, True),
        ("Nagaa dha", "", True),
    ],
)
def test_the_word_to_blank_must_be_in_the_sentence_as_written(
    text: str | None, blank: str | None, expected: bool
) -> None:
    assert blank_in(text, blank) is expected


@pytest.mark.parametrize("ref", ["S1", "S1-U06-L1", "W001", "s_2"])
def test_workbook_ids_are_refs(ref: str) -> None:
    assert REF_PATTERN.match(ref)


@pytest.mark.parametrize("ref", ["", "-S1", "S 1", "x" * 33, "S1/U1"])
def test_other_text_is_not_a_ref(ref: str) -> None:
    assert not REF_PATTERN.match(ref)


def test_counts_filled_reviewed_recorded_and_needing_change() -> None:
    rows = [
        RowFacts(text="ቡና", status="reviewed", has_audio=True),
        RowFacts(text="ሻይ", status="needs_change", has_audio=False),
        RowFacts(text=None, status="to_do", has_audio=False),
    ]
    assert counts_of(rows) == Counts(rows=3, filled=2, reviewed=1, recorded=1, needs_change=1)
    assert counts_of([]) == Counts()


def test_a_lesson_is_ready_when_every_row_is_reviewed_and_recorded() -> None:
    done = RowFacts(text="ቡና", status="reviewed", has_audio=True)
    assert ready_to_publish([done, done])
    assert not ready_to_publish([])
    assert not ready_to_publish([done, RowFacts(text="ሻይ", status="reviewed", has_audio=False)])
    assert not ready_to_publish([done, RowFacts(text="ሻይ", status="draft", has_audio=True)])
