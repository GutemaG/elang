---
id: 001-match-pairs-exercise-screen
unit: 002-match-pairs-ui
intent: 004-match-pairs-exercise-type
status: complete
priority: must
created: '2026-09-17T04:30:00Z'
assigned_bolt: null
implemented: true
---

# Story: 001-match-pairs-exercise-screen

## User Story

**As a** Buna learner
**I want** to complete a match-pairs exercise by tapping tiles
**So that** I can practice term/translation recall without needing drag gestures

## Acceptance Criteria

- [x] **Given** a `match_pairs` exercise loads, **When** the screen renders, **Then** two shuffled columns of tiles are shown (left = Amharic terms, right = English translations)
- [x] **Given** one tile is already selected (armed), **When** the user taps a tile in the other column, **Then** the pair links (visually distinct, tentative — not yet graded); tapping a linked left tile again unlinks it. **Corrected during Plan** (see `memory-bank/bolts/012-match-pairs-ui/implementation-plan.md`): live per-pair correct/incorrect feedback before completion was replaced with this codebase's existing atomic model (build → one "Check" → single whole-exercise verdict), matching every other exercise type rather than inventing a new interaction paradigm
- [x] **Given** all pairs are linked, **When** the user taps Check, **Then** the exercise is graded atomically (correct only if every pair matches) and hands off to `LessonController`'s existing grade/advance/Beans-XP flow exactly as the other 3 exercise types do

## Technical Notes

- New widget alongside `lib/features/lesson/widgets/choice_tile.dart` — reuse its correct/incorrect visual-feedback pattern where applicable
- Wire into `LessonController` the same way `sentence_construction`'s `word_bank_builder.dart` is wired — no new controller-level branching beyond exercise-type dispatch
- Tap-tile-pairs only (no drag-and-drop) per requirements.md's resolved decision
- **This story's pair-attempt evaluation IS the grading logic (FR-2)** — reassigned here from the backend unit during Construction per ADR-5 (client-side grading). No grading *call* to the backend, but the backend DOES serve a `correct_pairs` answer-key field (`MatchPairsExerciseResponse`, separate from `left_tiles`/`right_tiles` — corrected during `011-match-pairs-service`'s Implement stage to match `multiple_choice`'s existing content/answer-key split); compare the tap against that.

## Dependencies

### Requires
- `001-match-pairs-service`'s stories (needs the real content shape and grading contract)

### Enables
- 002-offline-match-pairs-verification

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| User taps the same tile twice | Second tap deselects it (no-op attempt), does not count as an incorrect pair attempt |
| User taps two tiles from the same column | Not treated as a pair attempt (a pair requires one from each column) |

## Out of Scope

- Offline verification (see 002-offline-match-pairs-verification)
- Drag-to-match interaction (not in scope for v1)
