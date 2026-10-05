"""Request and response bodies for a course's draft curriculum
(`curriculum_routers.py`). Field values are checked by the use cases, so a
whole file's problems come back at once."""

from __future__ import annotations

from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field


class CurriculumCounts(BaseModel):
    rows: int
    # Rows with their text in the course's language.
    filled: int
    reviewed: int
    # Rows with a recording.
    recorded: int
    needs_change: int


class CurriculumEntry(BaseModel):
    ref: str
    kind: str
    parent_ref: str | None
    position: int
    title: str
    goal: str | None
    grammar: str | None
    # A lesson's rows counted; null for a section or skill (the admin site
    # adds up its lessons).
    counts: CurriculumCounts | None
    # Bolt 085: the live category, skill or lesson published from it.
    published_id: str | None = None
    # A lesson's: when it was published, `not_published`, `published` or
    # `changed` (since), and how many draft exercises it has.
    published_at: datetime | None = None
    publish_state: str | None = None
    exercise_count: int | None = None


class CurriculumRow(BaseModel):
    ref: str
    kind: str
    lesson_ref: str
    position: int
    english: str
    text: str | None
    romanization: str | None
    blank: str | None
    accepted: list[str]
    notes: str | None
    confidence: str | None
    status: str
    comment: str | None
    audio_url: str | None
    # Send it back with an edit; an older one is `409 content_changed`.
    version: int
    updated_by: str | None
    updated_at: datetime


class Curriculum(BaseModel):
    course_id: str
    course_title: str
    language: str
    entries: list[CurriculumEntry]
    rows: list[CurriculumRow]
    counts: CurriculumCounts


class ImportEntry(BaseModel):
    ref: Any = None
    kind: Any = None
    parent_ref: Any = None
    position: Any = 0
    title: Any = None
    goal: Any = None
    grammar: Any = None


class ImportRow(BaseModel):
    ref: Any = None
    kind: Any = None
    lesson_ref: Any = None
    position: Any = 0
    english: Any = None
    text: Any = None
    romanization: Any = None
    blank: Any = None
    accepted: Any = None
    notes: Any = None
    confidence: Any = None
    status: Any = "to_do"
    comment: Any = None


class ImportCurriculumRequest(BaseModel):
    entries: list[ImportEntry] = Field(default_factory=list, max_length=2000)
    rows: list[ImportRow] = Field(default_factory=list, max_length=10000)
    # Change rows that are reviewed or recorded too.
    overwrite_reviewed: bool = False


class ImportTally(BaseModel):
    added: int
    changed: int
    kept: int
    unchanged: int


class ImportCurriculumResponse(BaseModel):
    dry_run: bool
    entries: ImportTally
    rows: ImportTally
    # Rows the file would change but that are reviewed or recorded, so were
    # left as they are.
    kept: list[str]
    # Saved, but not in the file; left as they are.
    missing_entries: list[str]
    missing_rows: list[str]


class UpdateCurriculumRowRequest(BaseModel):
    version: int
    english: str | None = None
    text: str | None = None
    romanization: str | None = None
    blank: str | None = None
    accepted: list[str] | None = None
    notes: str | None = None
    status: str | None = None
    comment: str | None = None
    audio_url: str | None = None


class UpdateCurriculumRowResponse(BaseModel):
    row: CurriculumRow
    # The text changed on a recorded row, so it went back to Draft.
    reset_to_draft: bool


class CurriculumUploadRequest(BaseModel):
    row_ref: str
    content_type: str
    size: int = Field(description="Exact size in bytes of the file to be uploaded")


class DraftExercise(BaseModel):
    """One of a lesson's draft exercises, in the live exercise format."""

    type: str
    prompt: str
    content: Any
    answer_key: Any
    # The word row it practises, linked to the word's vocabulary item on
    # publish.
    vocab_ref: str | None = None
    # The body it was generated as, and whether it was edited since.
    generated: dict[str, Any] | None = None
    edited: bool = False


class DraftExerciseList(BaseModel):
    exercises: list[DraftExercise]


class SaveDraftExercisesRequest(BaseModel):
    exercises: list[DraftExercise] = Field(max_length=200)


class PublishLessonResponse(BaseModel):
    category_id: str
    skill_id: str
    lesson_id: str
    exercise_ids: list[str]
    # What this publish made: "section", "skill", "lesson".
    created: list[str]
