---
intent: 004-match-pairs-exercise-type
phase: inception
status: complete
created: '2026-09-17T04:00:00Z'
updated: '2026-09-17T05:00:00Z'
---

# Requirements: Match-Pairs Exercise Type

## Intent Overview

Add `match_pairs` as a fourth exercise type in the lesson engine, alongside the existing `multiple_choice`, `listening`, and `sentence_construction` types. The original core-lesson-loop scope called for 5 exercise types; only 3 were built (`002-core-lesson-loop`). This intent closes one of the two remaining gaps. No external service dependency (unlike `speak_check`, which needs Google Cloud Speech-to-Text and is sequenced later as `006-speak-check-exercise-type`).

A `match_pairs` exercise presents a shuffled set of Amharic-term tiles and their English-translation tiles across two columns; the user taps one tile from each column to attempt a pair. This mirrors the existing tap-based interaction already used by `multiple_choice`/`sentence_construction` (no new drag-gesture code needed) and needs no new content-authoring pipeline (text/text pairs only, reusing the curriculum's existing word/phrase data).

## Business Goals

| Goal | Success Metric | Priority |
|------|----------------|----------|
| Close the exercise-type gap from original MVP scope | 4 of 5 planned exercise types shipped (up from 3) | Must |
| Keep the new type fully consistent with the existing exercise engine | Zero changes required to Beans/XP/streak logic or to the other 3 exercise types | Must |

---

## Functional Requirements

### FR-1: Match-Pairs Content Model
- **Description**: The backend supports a new `ExerciseType.MATCH_PAIRS` value. A `match_pairs` exercise's content is a set of N term/translation tiles (text ↔ text), served through the existing skill-tree/lesson-content endpoints exactly like the other 3 types — no separate endpoint or response envelope. **Corrected during Construction's Implement stage (2026-09-17)**: content (`MatchPairsContent`: shuffleable `left_tiles`/`right_tiles`) and the correct-answer data (`PairAnswerKey`: `correct_pairs`) are kept separate, mirroring `multiple_choice`'s existing split — not merged into one self-revealing content blob as originally described here. Also required a migration widening the `exercises` table's `type` `CHECK` constraint, which the original description incorrectly assumed was unnecessary.
- **Acceptance Criteria**:
  - `ExerciseType.MATCH_PAIRS = "match_pairs"` added to the domain enum
  - `MatchPairsContent` holds `left_tiles`/`right_tiles` (reusing the existing `Choice` value object); `PairAnswerKey` holds the correct `(left_id, right_id)` pairing
  - At least 1 seeded `match_pairs` exercise exists in the curriculum after this intent
  - Existing lesson-content serialization requires no per-type special-casing beyond the new content/answer-key shapes
- **Priority**: Must

### FR-2: Match-Pairs Grading (Client-Side)
- **Description**: **Corrected during Construction (2026-09-17)** — originally scoped as backend validation; ADR-5 (`001-lesson-service`, bolt 005) already established that all exercise grading is client-side (the lesson-content response carries the correct-answer data, and the client grades instantly and locally; the server only bounds the Beans/XP ledger, it doesn't compute or re-verify per-exercise correctness). `match_pairs` follows the same pattern: the client compares the user's tap-matched pairs against the `correct_pairs` answer-key data served alongside FR-1's content (a separate field, like `multiple_choice`'s `correct_choice_id` — not embedded in `content` itself, correcting this FR's own earlier draft). The exercise is correct only if every pair is matched correctly — no partial credit.
- **Acceptance Criteria**:
  - Submitting all pairs correctly matched (client-side comparison) → exercise marked correct
  - Any incorrect pair attempt → exercise marked incorrect, no partial credit
  - The existing Beans/XP/streak award flow (`001-lesson-service` bolt 005) runs unchanged; the backend performs zero match_pairs-specific grading logic
- **Priority**: Must
- **Delivered by**: `002-match-pairs-ui`'s story `001-match-pairs-exercise-screen` (its own tap-attempt AC already covers this) — no separate backend story exists for this FR

### FR-3: Match-Pairs Client UI (Tap-Tile-Pairs)
- **Description**: A new exercise screen/widget renders two shuffled columns of tiles (left = Amharic terms, right = English translations). **Corrected during Construction's Plan stage (2026-09-17)**: tapping one tile from each column tentatively links them (no grading yet); the exercise is graded atomically, all at once, when the user taps "Check" — exactly the same build-then-check model already used by the other 3 exercise types (`multiple_choice`'s select-then-Check, `sentence_construction`'s word-bank-then-Check), not live per-pair lock/flash feedback as originally described here. See `memory-bank/bolts/012-match-pairs-ui/implementation-plan.md`'s Technical Approach for the full reasoning.
- **Acceptance Criteria**:
  - User can complete a `match_pairs` exercise using tap-only interaction (no drag gestures): tap-to-link/unlink, Check enabled only once every tile is linked
  - Unselected, armed (awaiting its pair), linked (pre-check), and correct/incorrect (post-check) tile states are visually distinct, reusing this codebase's existing tile color language
  - On completion, `LessonController`'s existing grade/advance/Beans-XP flow runs unchanged
- **Priority**: Must

### FR-4: Offline Compatibility
- **Description**: A downloaded lesson pack containing a `match_pairs` exercise must download and play fully offline through the existing pack-download/offline-take path (`003-offline-caching-and-sync`) with zero special-casing — text-only content, no audio files to fetch, so this should work by construction rather than requiring new offline-path code.
- **Acceptance Criteria**:
  - A pack containing a `match_pairs` exercise downloads successfully
  - The exercise plays with zero network calls once downloaded, identical to the other offline-capable exercise types today
- **Priority**: Must

---

## Non-Functional Requirements

No new NFRs beyond project standards — this intent reuses `002-core-lesson-loop`'s existing exercise-engine performance characteristics (client-side grading, zero added network round-trips per interaction) and `003-offline-caching-and-sync`'s existing offline guarantees.

---

## Constraints

### Technical Constraints

**Project-wide standards**: Required standards will be loaded from memory-bank standards folder by Construction Agent.

**Intent-specific constraints**:
- Must not change the response shape or grading behavior of the existing `multiple_choice`, `listening`, or `sentence_construction` exercise types
- Pair content is text ↔ text only for v1 (no audio pairs) — reuses existing curriculum data, no new content-authoring pipeline

### Business Constraints
- None identified beyond normal project pacing

---

## Assumptions

| Assumption | Risk if Invalid | Mitigation |
|------------|-----------------|------------|
| Tap-tile-pairs (not drag-to-match) is an acceptable v1 interaction | User may want a more visually engaging drag interaction later | Can be added as a follow-up intent without changing the content/grading model |
| Text ↔ text pairs (not audio ↔ text) are sufficient for v1 | If audio pairs are wanted later, requires a content-model extension | Content model can add an optional audio field later without breaking existing pairs |

---

## Open Questions

| Question | Owner | Due Date | Resolution |
|----------|-------|----------|------------|
| Pair content type | User | Before requirements finalized | **Resolved**: text ↔ text (Amharic term ↔ English translation) |
| Interaction model | User | Before Technical Design | **Resolved**: tap-tile-pairs |
