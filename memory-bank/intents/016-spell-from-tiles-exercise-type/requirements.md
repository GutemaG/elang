---
intent: 016-spell-from-tiles-exercise-type
phase: inception
status: complete
created: '2026-09-20T17:30:00Z'
updated: '2026-09-20T17:55:00Z'
---

# Requirements: Spell-From-Tiles Exercise Type

## Intent Overview

Add `spell_tiles` as a new exercise type: a word shown in the learner's
from-language, spelled out by tapping character tiles in order.

This is the **second exercise type beyond the original five-type product
scope**, following `015-gap-fill-exercise-type`. It sits next on the
complexity ladder because it is the only remaining candidate with no external
blocker: the audio types (`tap what you hear`, `listen and repeat`) are blocked
on real recordings — every seeded `audio_url` is still `PLACEHOLDER_AUDIO_URL`,
a piano sample — and the typing types are blocked on the unresolved Fidel
keyboard question that `015` explicitly fenced out.

**Why this type and not another.** Every existing type treats a written word as
an opaque blob. `multiple_choice`, `listening` and `match_pairs` test
recognition of a whole word; `sentence_construction` and `gap_fill` test word
*choice* within a sentence. None asks what a word is *made of*. For a
Fidel-script language that is the single largest barrier to reading, and
nothing in the app currently addresses it.

**Why it is cheap — and where it is not.** It reuses `SequenceAnswerKey`
unchanged, so like `gap_fill` it adds **no** member to the `AnswerKey` union —
the second type in a row. Its content derives from `_WORDS` in
`seed_course_content.py`, which is already seeded in all four courses, so it
needs **no new authored content per language** (unlike `gap_fill`, which needed
a hand-authored `blank` index per language).

It is *not* free on the client. The existing word-bank interaction is keyed by
tile **text**, not tile **id** — see FR-2 — and words repeat characters where
sentences do not repeat words. That is the real work in this intent, and it was
found by reading the code before Inception rather than discovered mid-bolt.

## Business Goals

| Goal | Success Metric | Priority |
|------|----------------|----------|
| Teach the script itself, which no existing exercise type does | `spell_tiles` exercises appear in every seeded course and are playable end to end, in both Fidel and Latin | Must |
| Keep the new type fully consistent with the existing exercise engine | Zero changes to Beans/XP/streak/SRS logic, and zero changes to the other five exercise types | Must |
| Show that a second consecutive type can reuse an existing answer key | No new `AnswerKey` union member; no new grading code path | Should |

---

## Functional Requirements

### FR-1: Spell-Tiles Content Model and Seed Content

- **Description**: The backend supports a new `ExerciseType.SPELL_TILES` value.
  A `spell_tiles` exercise carries a set of character tiles, each with a stable
  id, and is prompted by the word in the learner's from-language. The correct
  answer is the ordered sequence of tile ids that spells the learning-language
  word, carried by the **existing `SequenceAnswerKey`** (`correct_sequence`) —
  this type introduces no new answer-key shape.

  Tiles are shuffled, and include distractor characters not used in the correct
  sequence, so `correct_sequence` is a permutation of a **subset** of the tiles.
  This is the shape `sentence_construction` already uses, and it keeps `content`
  from revealing its own answer.

  Content is seeded in all four existing courses through the existing idempotent
  seed loop. Source material already exists: `_WORDS` in `seed_course_content.py`
  carries every lesson's four words in English, Amharic and Afaan Oromo.

- **Acceptance Criteria**:
  - `ExerciseType.SPELL_TILES = "spell_tiles"` added to the domain enum, and
    `ck_exercises_type` widened by a migration using `op.batch_alter_table`
    (SQLite cannot alter a `CHECK` in place — see migrations `c726efa81972`
    and `d1b7e4f2a903`). The duplicate `CHECK` literal in
    `ExerciseModel.__table_args__` must be widened in the same change
  - A `spell_tiles` exercise's correct answer is expressed as a
    `SequenceAnswerKey`; **no new member is added to the `AnswerKey` union**
  - One tile per character of the learning-language word: one tile per Fidel
    character for Amharic (`ሰላም` → `ሰ` `ላ` `ም`), one tile per Latin letter for
    Afaan Oromo. Decomposing a Fidel character into consonant and vowel is a
    different interaction and is out of scope
  - Tiles carry stable ids and **duplicate character text is expected and must
    be preserved** — `Galatoomi` has two `a` and two `o`; `Hanqaaquu` has three
    `a`. Any seed helper that keys a dict by tile text (as
    `id_by_token = {tile["text"]: tile["id"]}` does at
    `seed_course_content.py:275`) silently collapses these and must not be
    reused here
  - Two distractor tiles are added beyond the word's own characters, drawn from
    the same lesson's other words so they are script-mates rather than
    arbitrary. Without them the exercise is an anagram, solvable by elimination
    without knowing the word
  - One `spell_tiles` exercise per seeded lesson, **appended after the
    gap-fill** so no existing exercise's `order_index` moves, with a stable slug
    — exactly the approach `015` took
  - The exercise sets **no** `vocab_item_id`, and a test asserts it. This is not
    an oversight: `list_exercises_by_vocab_item_ids` keeps the first row per
    `vocab_item_id`, so a vocab item maps to exactly one exercise. `015`
    discovered this mid-Construction and had to retract an acceptance criterion;
    it is stated correctly up front here
  - Re-running the seed is idempotent, as for every existing exercise type
- **Priority**: Must

### FR-2: Spell-Tiles Client UI and Client-Side Grading

- **Description**: A new exercise widget shows the from-language word as the
  prompt, a tray for the spelling being built, and the shuffled character tiles
  beneath. Tapping a tile appends its character to the tray and dims that tile;
  tapping a built character removes it. The exercise is graded when the user
  taps Check — the same build-then-check model every other type uses.

  **The interaction must be keyed by tile id, not by tile text.** The existing
  `WordBankBuilder` is text-keyed: it does `built.contains(token)` and
  `onToggle(token)` ([word_bank_builder.dart:76]), and `http_lesson_api.dart`
  flattens tile ids to text at parse time. That is sound for sentences, where a
  token rarely repeats, and wrong for spelling, where characters repeat
  constantly — tapping one `a` would dim both twins and removing one would take
  the wrong tile. A **new sibling widget** is therefore built, leaving
  `WordBankBuilder` and `sentence_construction` untouched.

  Grading is **client-side**, per ADR-5: the response carries
  `correct_sequence` and the client compares locally.

- **Acceptance Criteria**:
  - A new id-keyed tile-spelling widget is added. `WordBankBuilder`,
    `SentenceConstructionExercise` and the `sentence_construction` parse path
    are **not modified**, and their tests are untouched
  - A word containing repeated characters spells correctly: tapping one of two
    identical tiles dims only that tile, and removing one removes the one that
    was tapped. This is asserted by a test using a genuinely repeating word
    (`Galatoomi` or `Hanqaaquu`)
  - The prompt is the word in the learner's from-language; the learner produces
    the learning-language spelling from recall, not by copying a visible model
  - Check is enabled only once at least one tile has been placed
  - On Check, `LessonController`'s existing grade/advance/Beans/XP flow runs
    unchanged
  - Tile states reuse the existing colour language rather than introducing new
    ones
  - Renders without overflow at up to **12 tiles** in one view, in both Fidel
    and Latin, at more than one text scale. Afaan Oromo is the demanding case:
    `Hanqaaquu` is nine letters plus two distractors, where Amharic `እንቁላል`
    is five
- **Priority**: Must

### FR-3: Offline Compatibility

- **Description**: A downloaded lesson pack containing a `spell_tiles` exercise
  must download and play fully offline through the existing pack path. Content
  is text-only with no audio to fetch. It requires the type to be added to
  **both** the serialize and deserialize halves of `lesson_pack_store.dart` —
  still the only seam where an omission fails at runtime rather than at compile
  time, because the write side is a switch over the sealed `Exercise` class and
  the read side is a switch over a string.
- **Acceptance Criteria**:
  - A pack containing a `spell_tiles` exercise downloads successfully
  - The exercise plays with zero network calls once downloaded
  - A round-trip test (serialize → deserialize) covers `spell_tiles`, including
    a word with repeated characters, proving tile ids survive the round trip
    rather than being collapsed
- **Priority**: Must

---

## Non-Functional Requirements

No new NFRs. This intent inherits `002-core-lesson-loop`'s exercise-engine
characteristics (client-side grading, zero added network round-trips per
interaction) and `003-offline-caching-and-sync`'s offline guarantees.

**NFR-3 of `010-multi-language-courses` applies unchanged**: this intent adds
one new instruction string per from-language (en/am/om), agent-authored and not
native-speaker reviewed, and inherits the same release blocker. It adds no
other new content — the words themselves are already seeded and already
reviewed to the same standard as the rest.

---

## Constraints

### Technical Constraints

**Project-wide standards**: loaded from the memory-bank standards folder by the
Construction Agent.

**Intent-specific constraints**:
- Must not change the response shape, grading behaviour or database schema of
  any of the five existing exercise types
- Must not modify `WordBankBuilder` or the `sentence_construction` path. If
  Construction finds sharing genuinely unavoidable, that is a scope change to
  raise at a checkpoint, not to absorb silently
- Must reuse `SequenceAnswerKey`. A new answer-key shape is likewise a
  checkpoint-level scope change
- One word per exercise; multi-word spelling is not in scope
- Tap-a-tile only. Typing into a field remains gated on the Fidel keyboard
  question
- Content must go through the existing idempotent seed loop, not a one-off
  script

### Business Constraints
- None beyond normal project pacing

---

## Assumptions

| Assumption | Risk if Invalid | Mitigation |
|------------|-----------------|------------|
| One tile per Fidel character is the right granularity for v1 | Consonant+vowel decomposition teaches the syllabary structure more directly | That is a distinct interaction (a syllabary picker), so it is a later type rather than a change to this one |
| Two distractor tiles make the exercise non-trivial without making it noisy | Too few and it stays near-anagram; too many and the tile grid overflows | The count is a seed constant, changeable without a model change |
| `LessonController` needs no new method — `toggleWordBankToken` is already a generic toggle over a `List<String>` and works for ids | A second toggle method duplicates state logic | Confirm against real code at the bolt's Plan stage; if a new method is needed, it is a small addition, not a design change |
| Up to 12 tiles fit one screen at reasonable text scales | Afaan Oromo's long words overflow on small devices | Prove it in test at more than one scale, then on device — the `011` banner needed three attempts because predicted extents passed in test and failed on hardware |

---

## Open Questions

| Question | Owner | Due Date | Resolution |
|----------|-------|----------|------------|
| Which of the lesson's four words is spelled? | Construction | Before the seed stage | Open. It should not be a word the lesson already drills three times over; decide against the real seed rather than on paper |
| Does the built spelling render as separate chips or as a joined string? | Construction | Before the bolt's UI stage | Open — deliberately. Joined reads like a real word, which is the point of the exercise; chips make "remove the one I tapped" obvious. This is the same class of detail `015` correctly left to the Plan stage |
| How do we get id-keyed tiles? | User | Checkpoint 1 | **Resolved 2026-09-20**: a new sibling widget, leaving `WordBankBuilder` and `sentence_construction` untouched — no regression risk to a shipped, tested type |
| What is the prompt? | User | Checkpoint 1 | **Resolved 2026-09-20**: the from-language word, so the learner spells from recall |
| Are there distractor tiles? | User | Checkpoint 1 | **Resolved 2026-09-20**: yes, two — otherwise it is an anagram |
| How many per lesson? | User | Checkpoint 1 | **Resolved 2026-09-20**: one, appended after the gap-fill so no `order_index` moves |
| Fidel granularity and the long-word case | User | Checkpoint 1 | **Resolved 2026-09-20**: one tile per Fidel character; accept the wide Latin case and design the layout for up to 12 tiles |
