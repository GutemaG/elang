"""Pydantic request/response schemas for the content admin API
(`admin_routers.py`). Admin-only: the learner schemas are untouched."""

from __future__ import annotations

from typing import Any, Literal

from pydantic import BaseModel, Field


class AdminMeResponse(BaseModel):
    email: str


# --- courses and the tree ---------------------------------------------------


class AdminCourse(BaseModel):
    id: str
    title: str
    learning_language: str
    from_language: str
    # Each language's name and its own name, from the `languages` table (the
    # code itself for a code with no row).
    learning_language_name: str
    learning_language_native_name: str
    from_language_name: str
    from_language_native_name: str
    status: str
    section_count: int


class AdminCourseList(BaseModel):
    courses: list[AdminCourse]


AudioStatus = Literal["placeholder", "hosted", "local"]


class AdminTreeExercise(BaseModel):
    id: str
    order_index: int
    type: str
    prompt: str
    # Listening and audio image choice exercises only: the piano
    # placeholder, a hosted https clip, or a local-backend `/media` clip.
    audio: AudioStatus | None = None


class AdminTreeLesson(BaseModel):
    id: str
    title: str
    order_index: int
    exercise_count: int
    exercises: list[AdminTreeExercise]


class AdminTreeSkill(BaseModel):
    id: str
    title: str
    order_index: int
    lesson_count: int
    lessons: list[AdminTreeLesson]


class AdminTreeSection(BaseModel):
    id: str
    title: str
    subtitle: str
    order_index: int
    skill_count: int
    skills: list[AdminTreeSkill]


class AdminCourseTree(BaseModel):
    course: AdminCourse
    sections: list[AdminTreeSection]


# --- writes -------------------------------------------------------------------


class TitleRequest(BaseModel):
    title: str


class CreateCourseRequest(BaseModel):
    learning_language: str
    from_language: str
    # Empty means "<from> to <learning>".
    title: str = ""


class UpdateCourseRequest(BaseModel):
    title: str | None = None
    status: str | None = Field(default=None, description="available or coming_soon")


class AdminLanguage(BaseModel):
    code: str
    name: str
    native_name: str
    # Courses teaching it or teaching from it; one in use cannot be deleted.
    course_count: int


class AdminLanguageList(BaseModel):
    languages: list[AdminLanguage]


class CreateLanguageRequest(BaseModel):
    code: str
    name: str
    native_name: str


class UpdateLanguageRequest(BaseModel):
    name: str | None = None
    native_name: str | None = None


class CreateSectionRequest(BaseModel):
    title: str
    subtitle: str = ""


class UpdateSectionRequest(BaseModel):
    title: str | None = None
    subtitle: str | None = None


class UpdateTitleRequest(BaseModel):
    title: str | None = None


class ReorderRequest(BaseModel):
    ids: list[str] = Field(description="Every child of the parent, in the new order")


class AdminNode(BaseModel):
    """A section, skill or lesson after a write."""

    id: str
    title: str
    subtitle: str | None = None
    order_index: int


class AdminNodeList(BaseModel):
    items: list[AdminNode]


class ExerciseRequest(BaseModel):
    type: str
    prompt: str
    content: Any
    answer_key: Any


class AdminExercise(BaseModel):
    id: str
    lesson_id: str
    order_index: int
    type: str
    prompt: str
    content: dict[str, Any]
    answer_key: dict[str, Any]
    vocab_item_id: str | None


class AdminExerciseList(BaseModel):
    exercises: list[AdminExercise]


class ExerciseImportRequest(BaseModel):
    """Bolt 056: a lesson's exercises from a file, added after its last one
    (`append`) or in place of them all (`replace`). `dry_run` only checks."""

    exercises: list[ExerciseRequest]
    mode: Literal["append", "replace"] = "append"
    dry_run: bool = False


class ExerciseImportCheck(BaseModel):
    """A dry run's answer: every exercise can be saved."""

    count: int


# --- vocabulary (bolt 040) ----------------------------------------------------


class AdminVocabUse(BaseModel):
    """One exercise that practises a word, and where it sits."""

    exercise_id: str
    type: str
    prompt: str
    lesson_id: str
    # Its lesson's place in the course, as the tree numbers it: "5.1.1".
    number: str
    section_title: str
    skill_title: str
    lesson_title: str


class AdminVocabItem(BaseModel):
    id: str
    word: str
    translation: str
    # Learners with spaced-repetition progress on this word.
    learners: int
    used_by: list[AdminVocabUse]


class AdminVocabList(BaseModel):
    course: AdminCourse
    # Items in curriculum order (by their first exercise); unused last.
    items: list[AdminVocabItem]
    # Distinct learners practising any word of the course.
    learners: int


class UpdateVocabRequest(BaseModel):
    word: str | None = None
    translation: str | None = None


# --- audio (bolt 036) ---------------------------------------------------------


class AudioUploadRequest(BaseModel):
    lesson_id: str
    content_type: str
    size: int = Field(description="Exact size in bytes of the file to be uploaded")


class AudioUploadResponse(BaseModel):
    upload_url: str
    method: Literal["PUT"] = "PUT"
    # Send exactly these headers with the PUT; the size is bound to the
    # signature, so the body must be the file that was described.
    headers: dict[str, str]
    key: str
    public_url: str
    expires_in: int


class AudioLinkRequest(BaseModel):
    url: str


class AudioLinkResponse(BaseModel):
    url: str
    content_type: str


# --- pictures (bolt 050) ------------------------------------------------------


class ImageUploadRequest(AudioUploadRequest):
    """The same request as audio's, so the admin site uploads both one way."""


class ImageUploadResponse(AudioUploadResponse):
    """The same response as audio's."""
