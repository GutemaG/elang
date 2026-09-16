"""Value objects for the lesson-content domain (immutable, equality by value).

Pure Python only -- zero dependencies on FastAPI, SQLAlchemy, or storage
concerns, per `ddd-02-technical-design.md`'s layering rule.
"""

from __future__ import annotations

from dataclasses import dataclass
from enum import StrEnum

MIN_CROWN_LEVEL = 0
MAX_CROWN_LEVEL = 5

# --- Bolt 005 constants (ddd-02-technical-design.md, Decision 3) ---
BEANS_MAX = 5
BEAN_REGEN_MINUTES = 30
XP_PER_CORRECT_ANSWER = 5
REFILL_COST_AMOLE = 350
STARTING_AMOLE_BALANCE = 500
FREEZE_GRANTED_AT_CROWN_LEVEL = 5


class ExerciseType(StrEnum):
    """The exercise types this lesson engine supports. Originally the 3
    types fixed by `002-core-lesson-loop`'s `requirements.md` FR-2;
    `MATCH_PAIRS` was added by `004-match-pairs-exercise-type` (bolt
    011-match-pairs-service) as the 4th of the 5 originally-planned types.
    """

    MULTIPLE_CHOICE = "multiple_choice"
    LISTENING = "listening"
    SENTENCE_CONSTRUCTION = "sentence_construction"
    MATCH_PAIRS = "match_pairs"


class SkillState(StrEnum):
    """Computed per-user skill-tree node state. Never stored directly --
    derived by `SkillTreeProgressionPolicy` from `UserSkillProgress` (or its
    deliberate absence).
    """

    LOCKED = "locked"
    ACTIVE = "active"
    COMPLETED = "completed"


@dataclass(frozen=True)
class Choice:
    """A labeled, selectable/orderable tile.

    Used both for multiple-choice/listening answer options and for
    sentence-construction word-bank tiles -- the same shape recurs across 2
    of the 3 exercise types, per the design system's "Choice & Match Tiles"
    component.
    """

    id: str
    text: str

    def __post_init__(self) -> None:
        if not self.id:
            raise ValueError("Choice.id must be a non-empty string")
        if not self.text:
            raise ValueError("Choice.text must be a non-empty string")


@dataclass(frozen=True)
class MultipleChoiceContent:
    """Renderable content for a `multiple_choice` exercise."""

    choices: tuple[Choice, ...]

    def __post_init__(self) -> None:
        if len(self.choices) < 2:
            raise ValueError("MultipleChoiceContent requires at least 2 choices")


@dataclass(frozen=True)
class ListeningContent:
    """Renderable content for a `listening` exercise."""

    audio_url: str
    choices: tuple[Choice, ...]

    def __post_init__(self) -> None:
        if not self.audio_url:
            raise ValueError("ListeningContent.audio_url must be a non-empty string")
        if len(self.choices) < 2:
            raise ValueError("ListeningContent requires at least 2 choices")


@dataclass(frozen=True)
class SentenceConstructionContent:
    """Renderable content for a `sentence_construction` exercise.

    `word_bank` may include distractor tiles not used in the correct
    sequence -- this tests picking the right words, not just their order.
    """

    word_bank: tuple[Choice, ...]

    def __post_init__(self) -> None:
        if len(self.word_bank) < 1:
            raise ValueError("SentenceConstructionContent requires at least 1 tile")


@dataclass(frozen=True)
class MatchPairsContent:
    """Renderable content for a `match_pairs` exercise.

    `left_tiles`/`right_tiles` are two independently-shuffled columns (left
    = Amharic terms, right = English translations); unlike
    `MultipleChoiceContent`, the correct association is never embedded
    here -- it lives entirely in the sibling `PairAnswerKey`, keeping this
    exercise type consistent with the existing content/answer-key split
    rather than making `content` self-revealing.
    """

    left_tiles: tuple[Choice, ...]
    right_tiles: tuple[Choice, ...]

    def __post_init__(self) -> None:
        if len(self.left_tiles) < 2:
            raise ValueError("MatchPairsContent requires at least 2 left tiles")
        if len(self.right_tiles) != len(self.left_tiles):
            raise ValueError(
                "MatchPairsContent requires left_tiles and right_tiles to be the same length"
            )


ExerciseContent = (
    MultipleChoiceContent | ListeningContent | SentenceConstructionContent | MatchPairsContent
)


@dataclass(frozen=True)
class ChoiceAnswerKey:
    """Correct-answer data for `multiple_choice`/`listening` exercises.

    `correct_choice_id` must reference a `Choice.id` from the sibling
    `content.choices` -- validated by the infrastructure layer when
    reconstructing an `Exercise` from storage, not by this value object
    itself (it has no visibility into its sibling `content`).
    """

    correct_choice_id: str

    def __post_init__(self) -> None:
        if not self.correct_choice_id:
            raise ValueError("ChoiceAnswerKey.correct_choice_id must be non-empty")


@dataclass(frozen=True)
class SequenceAnswerKey:
    """Correct-answer data for `sentence_construction` exercises.

    `correct_sequence` may be a strict subset of `content.word_bank` --
    distractor tiles are never part of the correct sequence.
    """

    correct_sequence: tuple[str, ...]

    def __post_init__(self) -> None:
        if len(self.correct_sequence) < 1:
            raise ValueError("SequenceAnswerKey.correct_sequence must be non-empty")


@dataclass(frozen=True)
class PairAnswerKey:
    """Correct-answer data for `match_pairs` exercises.

    Each tuple is `(left_choice_id, right_choice_id)`, referencing ids from
    the sibling `content.left_tiles`/`content.right_tiles` -- validated by
    the infrastructure layer when reconstructing an `Exercise` from
    storage, same as `ChoiceAnswerKey`/`SequenceAnswerKey`.
    """

    correct_pairs: tuple[tuple[str, str], ...]

    def __post_init__(self) -> None:
        if len(self.correct_pairs) < 2:
            raise ValueError("PairAnswerKey requires at least 2 pairs")


AnswerKey = ChoiceAnswerKey | SequenceAnswerKey | PairAnswerKey


@dataclass(frozen=True)
class LessonCompletionOutcome:
    """The full result of one `CompleteLesson` call (Stage 1's domain model).

    Never persisted as its own record -- its constituent parts are
    (`LessonAttempt`, `UserSkillProgress`, `UserStreak`). Returned to the
    application/presentation layers for response mapping and for replaying
    an idempotent retry's original result verbatim.
    """

    xp_awarded: int
    daily_xp_total: int
    daily_xp_target: int
    streak_count: int
    streak_increased_today: bool
    accuracy_percent: int
    correct_count: int
    total_count: int
    time_spent_seconds: float
    skill_unlocked_title: str | None = None
    crown_level: int | None = None
    crown_leveled_up: bool = False
    streak_freeze_unlocked: bool = False


@dataclass(frozen=True)
class CrownLevel:
    """The 1-5 mastery badge on a completed skill; 0 is the internal
    "not completed" sentinel (never displayed as a crown on the client).
    """

    value: int

    def __post_init__(self) -> None:
        if not (MIN_CROWN_LEVEL <= self.value <= MAX_CROWN_LEVEL):
            raise ValueError(
                f"CrownLevel must be between {MIN_CROWN_LEVEL} and {MAX_CROWN_LEVEL}, "
                f"got {self.value}"
            )
