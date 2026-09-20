---
intent: 015-gap-fill-exercise-type
phase: inception
status: complete
created: '2026-09-20T12:30:00Z'
updated: '2026-09-20T15:20:00Z'
---

# Requirements: Gap-Fill Exercise Type

## Intent Overview

Add `gap_fill` as a new exercise type: a sentence in the learning language with one word removed, and a set of tappable words to fill the gap with.

This is the **first exercise type beyond the original five-type product scope**. The original `002-core-lesson-loop` scope named five types; four are built (`multiple_choice`, `listening`, `sentence_construction`, `match_pairs`) and the fifth (`speak_check`) is blocked on Google Cloud provisioning (`006-speak-check-exercise-type`, Inception complete, Construction not started). `gap_fill` is new scope, chosen because it is the cheapest remaining type to build: it needs no audio, no keyboard, no external service, and no new answer-key shape.

**Why this type and not another.** Every existing type tests either recognition of an isolated word (`multiple_choice`, `listening`, `match_pairs`) or production of a whole sentence from a complete word bank (`sentence_construction`). None tests choosing the *right word for a position in a sentence*. `gap_fill` is the smallest addition that tests a word in context.

**Why it is cheap.** It reuses `ChoiceAnswerKey` and `MultipleChoiceContent`'s `Choice` value object unchanged, so it adds no member to the `AnswerKey` union — the first new exercise type that does not. Its content is derivable from the sentences already seeded in `seed_course_content.py`'s `_SENTENCES`, which already carry per-language answer tokens and distractors.

## Business Goals

| Goal | Success Metric | Priority |
|------|----------------|----------|
| Add contextual/grammatical practice, which no existing exercise type provides | `gap_fill` exercises appear in every seeded course and are playable end to end | Must |
| Keep the new type fully consistent with the existing exercise engine | Zero changes to Beans/XP/streak/SRS logic or to the other four exercise types | Must |
| Demonstrate that adding a type is now cheap when it reuses an existing answer key | No new `AnswerKey` union member; no new grading code path | Should |

---

## Functional Requirements

### FR-1: Gap-Fill Content Model and Seed Content

- **Description**: The backend supports a new `ExerciseType.GAP_FILL` value. A `gap_fill` exercise carries a learning-language sentence with exactly one word removed, a gloss of the full sentence in the learner's from-language, and a set of `Choice` tiles of which exactly one is correct. It is served through the existing lesson-content endpoint with no new endpoint or response envelope, exactly like the other four types. The correct answer is carried by the **existing `ChoiceAnswerKey`** (`correct_choice_id`) — this type introduces no new answer-key shape.

  Content is seeded in all four existing courses (the original English-to-Amharic course plus the three added by `010-multi-language-courses`) through the existing idempotent seed loop. Source material already exists: `_SENTENCES` in `seed_course_content.py` carries, per learning language, the sentence's answer tokens and a set of distractor tokens.

- **Acceptance Criteria**:
  - `ExerciseType.GAP_FILL = "gap_fill"` added to the domain enum, and `ck_exercises_type` widened by a migration using `op.batch_alter_table` (SQLite cannot alter a `CHECK` in place — see migration `c726efa81972`)
  - A `gap_fill` exercise's correct answer is expressed as a `ChoiceAnswerKey`; **no new member is added to the `AnswerKey` union**
  - The blanked position is **authored per language, not computed**, because token counts differ between languages for the same sentence (verified: "I want bread" is three tokens in Afaan Oromo, `Daabboo nan barbaada`, and two in Amharic, `ዳቦ እፈልጋለሁ`)
  - Distractor choices come from the same lesson's vocabulary, so a wrong answer is plausible rather than absurd
  - At least one `gap_fill` exercise is seeded per course, in all four courses
  - ~~The exercise sets `exercises.vocab_item_id` to the word being tested, so it participates in SRS/Practice like the other vocabulary-linked types~~ — **retracted during Construction (2026-09-20, bolt 030)**. An existing test, `test_vocab_is_linked_only_from_multiple_choice_and_none_is_shared`, caught this as soon as it was implemented: `list_exercises_by_vocab_item_ids` keeps the **first row per `vocab_item_id`**, so a vocab item maps to exactly one exercise. A gap-fill sharing a word with the multiple-choice exercise that already teaches it would either never be served in Practice or would displace that exercise, decided by a UUID comparison — no added SRS coverage, and arbitrary behaviour. Gap-fill therefore sets **no** `vocab_item_id`, and a test asserts that. Genuinely widening SRS coverage means seeding vocab items for the words that currently have none, which is separate scope.
  - Re-running the seed is idempotent, as for every existing exercise type
- **Priority**: Must

### FR-2: Gap-Fill Client UI and Client-Side Grading

- **Description**: A new exercise widget renders the sentence with a visible gap, the from-language gloss beneath it, and the choices as tappable tiles reusing the existing `ChoiceTile`. Tapping a tile places that word into the gap; tapping again (or tapping another tile) changes the selection. The exercise is graded when the user taps Check — the same build-then-check model every other type in this codebase uses.

  Grading is **client-side**, per ADR-5: the response carries `correct_choice_id` and the client compares locally. The backend performs no `gap_fill`-specific grading. *(This FR states grading as client-side from the outset deliberately: intent `004-match-pairs-exercise-type` originally scoped a backend grading story and had to retire it mid-Construction once ADR-5 was found. That mistake is not repeated here.)*

- **Acceptance Criteria**:
  - The sentence renders with the gap visually distinct from the surrounding words, in both Fidel and Latin script
  - Selecting a tile fills the gap with that word in place, so the learner reads the completed sentence before checking
  - Check is enabled only once a tile is selected
  - Selecting a different tile before Check replaces the selection; no partial or per-tap grading
  - On Check, `LessonController`'s existing grade/advance/Beans/XP flow runs unchanged
  - Unselected, selected, correct and incorrect tile states reuse the existing tile colour language rather than introducing new states
- **Priority**: Must

### FR-3: Offline Compatibility

- **Description**: A downloaded lesson pack containing a `gap_fill` exercise must download and play fully offline through the existing pack path (`003-offline-caching-and-sync`). Content is text-only with no audio to fetch, so this should hold by construction — but it requires the type to be added to **both** the serialize and deserialize halves of `lesson_pack_store.dart`, which is the step most easily missed (it is the only place where an omission fails silently at runtime rather than at compile time, since the sealed-class switches will not compile without their new arm).
- **Acceptance Criteria**:
  - A pack containing a `gap_fill` exercise downloads successfully
  - The exercise plays with zero network calls once downloaded, identical to the other offline-capable types
  - A round-trip test (serialize → deserialize) covers `gap_fill`, as for the existing types
- **Priority**: Must

---

## Non-Functional Requirements

No new NFRs. This intent inherits `002-core-lesson-loop`'s exercise-engine characteristics (client-side grading, zero added network round-trips per interaction) and `003-offline-caching-and-sync`'s offline guarantees.

**NFR-3 of `010-multi-language-courses` applies unchanged**: the Amharic and Afaan Oromo content this intent adds is agent-authored and not native-speaker reviewed. This intent adds one new instruction string per from-language (en/am/om) plus per-sentence blank choices, and inherits the same release blocker.

---

## Constraints

### Technical Constraints

**Project-wide standards**: loaded from the memory-bank standards folder by the Construction Agent.

**Intent-specific constraints**:
- Must not change the response shape, grading behaviour or database schema of `multiple_choice`, `listening`, `sentence_construction` or `match_pairs`
- Must reuse `ChoiceAnswerKey`. If Construction finds a new answer-key shape is genuinely required, that is a scope change to raise at a checkpoint, not to absorb silently — the cheapness of this type is one of its stated goals
- One blank per sentence for v1
- Select-a-word only. Typing into the gap is a different type (`typeCloze`-style) and depends on the unresolved Fidel keyboard question — explicitly out of scope
- Content must go through the existing idempotent seed loop, not a one-off script

### Business Constraints
- None beyond normal project pacing

---

## Assumptions

| Assumption | Risk if Invalid | Mitigation |
|------------|-----------------|------------|
| One gap per sentence is sufficient for v1 | Multi-gap exercises are a richer drill | The content model can carry a list of gaps later; a one-gap exercise stays valid |
| Choosing from tiles (not typing) is the right v1 interaction | Typing tests recall more strongly | Typing is a separate planned type, gated on the keyboard decision — not a change to this one |
| The existing `_SENTENCES` material is rich enough to blank meaningfully | Too few sentences to make the type feel present (one per lesson today) | Authoring more sentences is content work, additive, and does not change the model |
| Distractors drawn from the same lesson are plausible enough to be useful | A distractor may be grammatically impossible, making the answer guessable | Blank position and distractors are authored, not computed, so a bad pairing is a content fix |

---

## Open Questions

| Question | Owner | Due Date | Resolution |
|----------|-------|----------|------------|
| Does the gap live in the `prompt` column as a sentinel, or as structured before/after segments in `content`? | Construction | Before the bolt's domain-model stage | Open — flagged deliberately. `exercises.prompt` already exists and is non-null; a sentinel is simpler, structured segments render more safely. Decide against real code, not on paper (this is exactly the class of detail `004` got wrong on paper) |
| Should `gap_fill` count toward SRS/Practice? | User | Before requirements finalised | **Resolved 2026-09-20 (Checkpoint 2)**: yes — set `vocab_item_id`, as FR-1 states. It tests a specific word, so excluding it would make Practice weaker for no reason |
| How many gap-fill exercises per lesson? | User | Before requirements finalised | **Resolved 2026-09-20 (Checkpoint 2)**: one per lesson that has a seeded sentence, added to the existing exercise sequence rather than replacing an existing exercise |
