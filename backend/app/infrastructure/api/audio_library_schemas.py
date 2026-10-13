"""Bodies of the Audio library API (intent 029)."""

from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel


class AudioUseResponse(BaseModel):
    place: str
    language: str
    admin_path: str
    course_id: str | None
    course_title: str | None
    section: str | None
    skill: str | None
    lesson: str | None
    exercise_id: str | None
    exercise_number: int | None
    exercise_type: str | None
    prompt: str | None
    text: str | None
    english: str | None
    letter: str | None


class AudioFileResponse(BaseModel):
    key: str
    url: str
    size: int
    uploaded_at: datetime
    language: str
    source: str
    status: str
    can_trash: bool
    uses: list[AudioUseResponse]


class MissingAudioResponse(BaseModel):
    key: str
    url: str
    uses: list[AudioUseResponse]


class TrashedAudioResponse(BaseModel):
    key: str
    original_key: str
    size: int
    moved_at: datetime


class LibraryCourse(BaseModel):
    id: str
    title: str
    learning_language: str


class AudioTotals(BaseModel):
    files: int
    bytes: int
    in_use: int
    unused: int
    missing: int
    trash: int
    trash_bytes: int


class AudioLibraryResponse(BaseModel):
    storage: str
    totals: AudioTotals
    files: list[AudioFileResponse]
    missing: list[MissingAudioResponse]
    trash: list[TrashedAudioResponse]
    external_links: int
    courses: list[LibraryCourse]


class AudioKeysRequest(BaseModel):
    keys: list[str]


class AudioKeysResponse(BaseModel):
    count: int


class ExportFileResponse(BaseModel):
    zip_path: str
    key: str
    size: int
    download_url: str


class ExportRowResponse(BaseModel):
    zip_path: str
    status: str
    key: str
    url: str
    size: int | None
    uploaded_at: datetime | None
    use: AudioUseResponse | None


class AudioExportResponse(BaseModel):
    name: str
    files: list[ExportFileResponse]
    rows: list[ExportRowResponse]
