"""A course's curriculum, kept as a draft on the admin site until each
lesson is ready (intent `025-curriculum-workspace`).

The plan is a tree of entries: sections, the skills in them, and the
lessons in those, each with the ID the curriculum workbook gives it
(`S1`, `S1-U06`, `S1-U06-L1`). Each lesson has rows: the words it teaches
(`W001`) and its sentence (`S001`), in the course's language with their
romanization, reviewed by a native speaker and recorded.

Nothing here reaches learners: a finished lesson is published into the
course's live lessons and exercises.
"""

from __future__ import annotations

import re
from dataclasses import dataclass

ENTRY_KINDS = ("section", "skill", "lesson")
# Each entry's parent kind: a section has none.
PARENT_KIND = {"section": None, "skill": "section", "lesson": "skill"}

ROW_KINDS = ("word", "sentence")
# A row's review state, in the order work moves through it.
ROW_STATUSES = ("to_do", "draft", "needs_change", "reviewed")
# How sure the first draft was; null when no draft was made.
CONFIDENCES = ("high", "medium", "low")

# The workbook's IDs (`S1-U06-L1`, `W001`), or any short code like them.
REF_PATTERN = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_-]{0,31}$")

MAX_TITLE = 255
MAX_GOAL = 500
MAX_GRAMMAR = 1000
MAX_TEXT = 500
MAX_NOTES = 1000
MAX_COMMENT = 1000
MAX_ACCEPTED = 10
# A lesson's draft exercises.
MAX_EXERCISES = 50


def blank_in(text: str | None, blank: str | None) -> bool:
    """Whether a sentence's word to blank appears in it as written, so the
    gap-fill exercise can hide it. No blank is fine."""
    if not blank:
        return True
    return bool(text) and blank in (text or "")


@dataclass(frozen=True)
class RowFacts:
    """What the counts need to know about a row."""

    text: str | None
    status: str
    has_audio: bool


@dataclass(frozen=True)
class Counts:
    rows: int = 0
    filled: int = 0
    reviewed: int = 0
    recorded: int = 0
    needs_change: int = 0


def counts_of(rows: list[RowFacts]) -> Counts:
    return Counts(
        rows=len(rows),
        filled=sum(1 for r in rows if r.text),
        reviewed=sum(1 for r in rows if r.status == "reviewed"),
        recorded=sum(1 for r in rows if r.has_audio),
        needs_change=sum(1 for r in rows if r.status == "needs_change"),
    )


def ready_to_publish(rows: list[RowFacts]) -> bool:
    """Every row is reviewed and recorded, and there is at least one."""
    return bool(rows) and all(r.status == "reviewed" and r.has_audio for r in rows)
