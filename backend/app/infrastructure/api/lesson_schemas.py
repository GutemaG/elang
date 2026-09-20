"""Pydantic request/response schemas for the lesson-content API.

Shapes match `ddd-02-technical-design.md`'s API Design section (bolts `004`
and `005`) exactly. Exercise response schemas now include each exercise's
correct-answer field (`correct_choice_id`/`correct_sequence`/
`correct_pairs`) per ADR-5, which supersedes ADR-4's "never expose correct
answers" -- see ADR-5 (`memory-bank/bolts/005-lesson-engagement-service/`)
for why. `match_pairs` (bolt `011-match-pairs-service`) follows the same
rule: grading is client-side, so `correct_pairs` ships in the response.
"""

from __future__ import annotations

from datetime import datetime
from typing import Annotated, Literal

from pydantic import BaseModel, Field

from app.infrastructure.api.course_schemas import CourseInfoResponse


class ChoiceResponse(BaseModel):
    id: str
    text: str


class CategoryResponse(BaseModel):
    id: str
    title: str
    subtitle: str
    order_index: int


class SkillTreeEntryResponse(BaseModel):
    id: str
    title: str
    order_index: int
    # bolt 021 (ADR-11): the category this skill belongs to; `order_index`
    # above is its position within that category.
    category_id: str
    state: Literal["locked", "active", "completed"]
    crown_level: int
    # bolt 007: the lesson to start when this node is tapped -- the first
    # lesson (by order_index) not yet completed this cycle, or the skill's
    # first lesson if the cycle is already complete. `None` only if the
    # skill somehow has zero lessons (shouldn't happen with real content).
    lesson_id: str | None
    # bolt 008: offline-caching staleness signal (FR-1 of
    # 003-offline-caching-and-sync) -- the client compares this against its
    # cached copy's version to decide whether a re-download is needed.
    content_version: datetime


class SkillTreeResponse(BaseModel):
    # Deprecated (ADR-11): the first category's title/subtitle, kept so a
    # client that still reads them keeps working. Use `categories`.
    unit_title: str
    unit_subtitle: str
    categories: list[CategoryResponse]
    # Bolt 024 (ADR-12): the course this tree belongs to (the caller's active
    # course); the client keys its offline cache by `course.id`.
    course: CourseInfoResponse | None = None
    skills: list[SkillTreeEntryResponse]
    streak_count: int
    beans: int
    beans_max: int
    total_xp: int


class MultipleChoiceExerciseResponse(BaseModel):
    id: str
    order_index: int
    type: Literal["multiple_choice"] = "multiple_choice"
    prompt: str
    choices: list[ChoiceResponse]
    correct_choice_id: str


class ListeningExerciseResponse(BaseModel):
    id: str
    order_index: int
    type: Literal["listening"] = "listening"
    prompt: str
    audio_url: str
    choices: list[ChoiceResponse]
    correct_choice_id: str


class SentenceConstructionExerciseResponse(BaseModel):
    id: str
    order_index: int
    type: Literal["sentence_construction"] = "sentence_construction"
    prompt: str
    word_bank: list[ChoiceResponse]
    correct_sequence: list[str]


class MatchPairsExerciseResponse(BaseModel):
    id: str
    order_index: int
    type: Literal["match_pairs"] = "match_pairs"
    prompt: str
    left_tiles: list[ChoiceResponse]
    right_tiles: list[ChoiceResponse]
    correct_pairs: list[tuple[str, str]]


class GapFillExerciseResponse(BaseModel):
    """`gap_fill` (bolt 030): the sentence either side of the gap, the
    words to choose between, and which one is right. `correct_choice_id`
    is the same field `multiple_choice`/`listening` carry -- this type
    shares their answer key rather than introducing another.
    """

    id: str
    order_index: int
    type: Literal["gap_fill"] = "gap_fill"
    prompt: str
    sentence_before: str
    sentence_after: str
    choices: list[ChoiceResponse]
    correct_choice_id: str


ExerciseResponse = Annotated[
    MultipleChoiceExerciseResponse
    | ListeningExerciseResponse
    | SentenceConstructionExerciseResponse
    | MatchPairsExerciseResponse
    | GapFillExerciseResponse,
    Field(discriminator="type"),
]


class LessonSummaryResponse(BaseModel):
    id: str
    skill_id: str
    title: str
    order_index: int


class LessonContentResponse(BaseModel):
    lesson: LessonSummaryResponse
    exercises: list[ExerciseResponse]
    # bolt 008: same staleness signal as `SkillTreeEntryResponse.content_version`,
    # scoped to this one lesson.
    content_version: datetime


class BeansStatusResponse(BaseModel):
    beans: int
    beans_max: int
    next_bean_at: str | None
    regen_minutes_per_bean: int
    amole_balance: int
    refill_cost_amole: int


class RefillResponse(BaseModel):
    beans: int
    amole_balance: int


class CompleteLessonRequest(BaseModel):
    attempt_id: str
    correct_count: int
    total_count: int
    time_spent_seconds: float
    # bolt 008: when the user actually completed the lesson -- identical to
    # "now" for an online completion; earlier for one queued while offline
    # and synced later (see `CompletionTimestampValidator`).
    client_completed_at: datetime
    # bolt 019 (ADR-10): exercise ids answered wrong at least once before
    # eventually being answered correctly (the client's retry-until-correct
    # design guarantees every exercise in a completed lesson was eventually
    # gotten right, so this -- not a final pass/fail -- is the only
    # per-exercise signal available). Defaults to empty for older clients;
    # drives vocab-progress box-up/box-reset, nothing else.
    missed_exercise_ids: list[str] = Field(default_factory=list)


class CompleteLessonResponse(BaseModel):
    xp_earned: int
    daily_xp_total: int
    daily_xp_target: int
    streak_count: int
    streak_increased_today: bool
    accuracy_percent: int
    correct_count: int
    total_count: int
    time_spent_seconds: float
    skill_unlocked_title: str | None
    crown_level: int | None
    crown_leveled_up: bool
    streak_freeze_unlocked: bool


class DueItemResponse(BaseModel):
    """Bolt 019/020, story 004: one due vocab item, resolved to its full
    exercise content -- not just an id -- so Practice (bolt 020) can render
    it via the existing exercise-engine components with zero further
    round trips. Widened from a bare `exercise_id` at bolt 020's Plan
    stage: `GET /lessons/{lesson_id}` (the only other way to fetch this)
    enforces `LessonAccessPolicy`, which would 403 a locked skill's lesson
    -- something Practice must not be blocked by.
    """

    vocab_item_id: str
    word: str
    translation: str
    exercise: ExerciseResponse
    box_level: int
    next_review_at: datetime


class DueItemsResponse(BaseModel):
    items: list[DueItemResponse]


class DueCountResponse(BaseModel):
    due_count: int


class PracticeResultItem(BaseModel):
    """One graded vocab item from a completed Practice session (bolt
    `020-practice-ui`)."""

    vocab_item_id: str
    correct: bool


class CompletePracticeSessionRequest(BaseModel):
    # Client-generated idempotency key, same convention as
    # `CompleteLessonRequest.attempt_id`.
    session_id: str
    results: list[PracticeResultItem]
    time_spent_seconds: float


class CompletePracticeSessionResponse(BaseModel):
    xp_earned: int
    amole_earned: int
    correct_count: int
    total_count: int
    accuracy_percent: int
