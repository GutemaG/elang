"""Value objects for the lesson-content domain (immutable, equality by value).

Pure Python only -- zero dependencies on FastAPI, SQLAlchemy, or storage
concerns, per `ddd-02-technical-design.md`'s layering rule.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import timedelta
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

# --- Bolt 017 constants (ddd-02-technical-design.md) ---
AMOLE_LESSON_COMPLETION_AWARD = 20
AMOLE_PERFECT_LESSON_BONUS = 10
AMOLE_STREAK_MILESTONE_7_BONUS = 150
AMOLE_STREAK_MILESTONE_30_BONUS = 500
STREAK_MILESTONE_7_DAYS = 7
STREAK_MILESTONE_30_DAYS = 30

# --- Bolt 019 constants (ddd-01-domain-model.md / ddd-02-technical-design.md) ---
MIN_BOX_LEVEL = 1
MAX_BOX_LEVEL = 5

# Fixed Leitner spacing per box level -- named constants, not a
# runtime-configurable table (same tuning-constant convention as
# `REFILL_COST_AMOLE`/the `AMOLE_*` awards above).
LEITNER_BOX_INTERVALS: dict[int, timedelta] = {
    1: timedelta(days=1),
    2: timedelta(days=3),
    3: timedelta(days=7),
    4: timedelta(days=14),
    5: timedelta(days=30),
}

# A wrong answer's next-review offset is its own named constant, not a reuse
# of `LEITNER_BOX_INTERVALS[1]` -- so a future change to box 1's interval
# can't silently change how soon a missed item resurfaces (story
# `003-leitner-box-algorithm`'s explicit requirement). Both currently
# resolve to 1 day, which is a coincidence, not a coupling.
INCORRECT_RESET_INTERVAL = timedelta(days=1)

# --- Bolt 020 constant (implementation-plan.md) ---
# Smaller than AMOLE_LESSON_COMPLETION_AWARD -- a practice session is
# typically shorter than a full lesson.
AMOLE_PRACTICE_SESSION_AWARD = 10


class AmoleSource(StrEnum):
    """Closed vocabulary for `AmoleTransaction.source` (ADR-8) -- adding a
    new source is a deliberate code change, never runtime-configurable,
    same closed-enum-as-CHECK-constraint pattern as `ExerciseType`.
    """

    WALLET_CREATED = "wallet_created"
    MIGRATION_BACKFILL = "migration_backfill"
    LESSON_COMPLETION = "lesson_completion"
    PERFECT_LESSON = "perfect_lesson"
    STREAK_MILESTONE_7 = "streak_milestone_7"
    STREAK_MILESTONE_30 = "streak_milestone_30"
    BEAN_REFILL = "bean_refill"
    # Bolt 020 (008-srs-and-practice): a completed Practice session's flat
    # bonus -- Practice deliberately does not touch streak/skill-progress,
    # so this is its only account-ledger effect.
    PRACTICE_SESSION = "practice_session"


@dataclass(frozen=True)
class AmoleAward:
    """One proposed positive ledger entry -- `AmoleAwardPolicy`'s output,
    not yet posted. The caller (`complete_lesson`) turns each of these into
    an `AmoleTransaction` sharing the completion's own `attempt_id` as
    `reference_id` (ADR-8) -- this value object doesn't carry a
    `reference_id` itself since it has no notion of which completion it
    came from.
    """

    amount: int
    source: AmoleSource


class ExerciseType(StrEnum):
    """The exercise types this lesson engine supports. Originally the 3
    types fixed by `002-core-lesson-loop`'s `requirements.md` FR-2;
    `MATCH_PAIRS` was added by `004-match-pairs-exercise-type` (bolt
    011-match-pairs-service) as the 4th of the 5 originally-planned types.
    `GAP_FILL` was added by `015-gap-fill-exercise-type` (bolt
    030-gap-fill-service) and is the first type beyond that original
    scope -- chosen because it needs no audio, no keyboard and no new
    answer key, reusing `ChoiceAnswerKey` as-is. `SPELL_TILES` was added
    by `016-spell-from-tiles-exercise-type` (bolt 032-spell-tiles-service)
    on the same principle, reusing `SequenceAnswerKey`.

    Adding a value here is only ever half the change: `exercises.type`
    carries a `CHECK` constraint declared both in a migration and in
    `ExerciseModel.__table_args__`, and neither widens on its own.
    """

    MULTIPLE_CHOICE = "multiple_choice"
    LISTENING = "listening"
    SENTENCE_CONSTRUCTION = "sentence_construction"
    MATCH_PAIRS = "match_pairs"
    GAP_FILL = "gap_fill"
    SPELL_TILES = "spell_tiles"


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


@dataclass(frozen=True)
class GapFillContent:
    """Renderable content for a `gap_fill` exercise: a sentence in the
    learning language with one word taken out, plus the words to choose
    between.

    The sentence is stored as the text on either side of the gap. Two
    alternatives were rejected (bolt `030-gap-fill-service`'s
    `implementation-plan.md`): a marker such as `___` inside the string,
    which the client would have to parse and which could collide with real
    text; and a token list plus a `blank_index`, which is an off-by-one
    waiting to happen and would leave the missing word sitting in
    `content` as well as in the answer key. Here the missing word appears
    only in the sibling `ChoiceAnswerKey`, and a gap at the very start or
    end of the sentence is just an empty string on that side.

    Both sides are stored already trimmed: the space around the gap
    belongs to the client's layout, not to the data.
    """

    sentence_before: str
    sentence_after: str
    choices: tuple[Choice, ...]

    def __post_init__(self) -> None:
        if not self.sentence_before and not self.sentence_after:
            raise ValueError("GapFillContent requires text on at least one side of the gap")
        if len(self.choices) < 2:
            raise ValueError("GapFillContent requires at least 2 choices")


@dataclass(frozen=True)
class SpellTilesContent:
    """Renderable content for a `spell_tiles` exercise: the character tiles
    a word is spelled from, shuffled, including distractors.

    Unlike every other tile-bearing type in this module, **duplicate
    `text` across tiles is normal and must be preserved** -- `Maaloo` needs
    two `a` tiles and two `o` tiles. Tiles are therefore only ever
    identified by `Choice.id`. Any code that keys a tile by its text (the
    seed's `id_by_token` idiom, for instance) silently collapses a word
    like that and is wrong for this type.

    The word itself never appears here, only its scattered characters, so
    `content` does not reveal its own answer -- the ordering lives in the
    sibling `SequenceAnswerKey`.
    """

    tiles: tuple[Choice, ...]

    def __post_init__(self) -> None:
        if len(self.tiles) < 2:
            raise ValueError("SpellTilesContent requires at least 2 tiles")


ExerciseContent = (
    MultipleChoiceContent
    | ListeningContent
    | SentenceConstructionContent
    | MatchPairsContent
    | GapFillContent
    | SpellTilesContent
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
    """Correct-answer data for `sentence_construction` and `spell_tiles`
    exercises.

    `correct_sequence` may be a strict subset of the sibling content's
    tiles -- distractor tiles are never part of the correct sequence.

    For `spell_tiles` it names **a** correct ordering, not the only one.
    A word with a repeated character has two interchangeable tiles for it,
    so several id sequences spell the same word; the client therefore
    grades by comparing the spelled *text*, not the id list. See bolt
    `032-spell-tiles-service`'s `implementation-plan.md`, decision D3.
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


# Deliberately three members for six exercise types. `gap_fill` reuses
# `ChoiceAnswerKey` exactly as `multiple_choice`/`listening` do, since
# "which one of these is right" is the same question however it is asked;
# `spell_tiles` reuses `SequenceAnswerKey` exactly as
# `sentence_construction` does, since "put these tiles in order" is the
# same question whether the tiles are words or characters. Keeping it
# that way was a stated goal of both `015-gap-fill-exercise-type` and
# `016-spell-from-tiles-exercise-type`, not an accident -- see those
# intents' `requirements.md`.
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
    # True when the lesson's skill was already completed before this
    # attempt: a review, which awards nothing (see `complete_lesson`).
    is_review: bool = False


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
