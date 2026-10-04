"""Request and response bodies for the Sounds tab's endpoints
(`sound_routers.py`)."""

from __future__ import annotations

from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field

# --- what the app reads ----------------------------------------------------------


class SoundChartSummary(BaseModel):
    language: str
    title: dict[str, str]
    # Goes up on every change; the app downloads the chart again only when
    # it differs from the copy it holds.
    version: int
    letter_count: int
    # What the app's Sounds tab shows for the chart: its first letter, such
    # as ሀ, or "Aa" for a Latin script.
    icon: str


class SoundChartIndex(BaseModel):
    charts: list[SoundChartSummary]


class SoundExample(BaseModel):
    word: str
    romanization: str | None
    meaning: dict[str, str]
    audio_url: str | None


class SoundLetter(BaseModel):
    id: str
    glyph: str
    romanization: str
    hint: dict[str, str]
    # What plays: the letter's own recording, or that of the letter it
    # sounds the same as.
    audio_url: str | None
    # The glyph of the letter it sounds the same as, if any.
    same_as: str | None
    example: SoundExample | None


class SoundGroup(BaseModel):
    key: str
    names: dict[str, str]
    # Set for a grid: that many letters to a row, under `column_labels`.
    columns: int | None
    column_labels: list[str]
    letters: list[SoundLetter]


class SoundChart(BaseModel):
    language: str
    title: dict[str, str]
    version: int
    updated_at: datetime
    groups: list[SoundGroup]
    # The speakers who recorded it, for the app to credit.
    credits: list[str]


# --- the admin site ------------------------------------------------------------------


class AdminSoundCounts(BaseModel):
    letters: int
    ready: int
    needs_review: int
    draft: int
    needs_recording: int
    same_sound: int


class AdminSoundGaps(BaseModel):
    """What stops the chart being turned on; all zero/false when nothing."""

    no_letters: bool
    no_romanization: int
    no_audio: int


class AdminSoundGroup(BaseModel):
    key: str
    names: dict[str, str]
    columns: int | None
    column_labels: list[str]


class AdminSoundLetter(BaseModel):
    id: str
    group: str
    position: int
    glyph: str
    romanization: str
    hint: dict[str, str]
    audio_url: str | None
    same_as_id: str | None
    example_word: str | None
    example_romanization: str | None
    example_meaning: dict[str, str]
    example_audio_url: str | None
    status: str
    recorded_by: str | None
    updated_at: datetime


class AdminSoundChartSummary(BaseModel):
    language: str
    language_name: str
    title: dict[str, str]
    enabled: bool
    version: int
    updated_at: datetime
    counts: AdminSoundCounts
    gaps: AdminSoundGaps


class AdminSoundChartList(BaseModel):
    charts: list[AdminSoundChartSummary]


class AdminSoundChart(AdminSoundChartSummary):
    groups: list[AdminSoundGroup]
    letters: list[AdminSoundLetter]


class CreateSoundChartRequest(BaseModel):
    language: str
    template: str = Field(description="fidel, qubee or empty")


class UpdateSoundChartRequest(BaseModel):
    enabled: bool | None = None
    title: dict[str, str] | None = None
    # Group key -> its names by app language.
    group_names: dict[str, dict[str, str]] | None = None


class CreateSoundLetterRequest(BaseModel):
    group: str
    glyph: str
    romanization: str | None = None
    hint: dict[str, str] | None = None
    audio_url: str | None = None
    same_as_id: str | None = None
    example_word: str | None = None
    example_romanization: str | None = None
    example_meaning: dict[str, str] | None = None
    example_audio_url: str | None = None
    status: str | None = None
    recorded_by: str | None = None


class UpdateSoundLettersRequest(BaseModel):
    # Each item is `{"id": ..., <field>: <value>, ...}`; only the fields
    # given change, and `null` clears one.
    letters: list[dict[str, Any]]


class SoundUploadRequest(BaseModel):
    content_type: str
    size: int = Field(description="Exact size in bytes of the file to be uploaded")
