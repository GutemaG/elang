---
unit: 002-match-pairs-ui
intent: 004-match-pairs-exercise-type
phase: inception
status: complete
created: '2026-09-17T04:25:00Z'
updated: '2026-09-17T04:25:00Z'
unit_type: frontend
default_bolt_type: simple-construction-bolt
---

# Unit Brief: Match-Pairs UI

## Purpose

Flutter client work: a new tap-tile-pairs exercise screen for the `match_pairs` exercise type, wired into the existing `LessonController`/exercise-engine flow exactly as `multiple_choice`, `listening`, and `sentence_construction` are today. Verifies zero-regression compatibility with the existing offline download/take path from `003-offline-caching-and-sync`.

**Reassigned during Construction (2026-09-17)**: this unit now also owns match-pairs grading (FR-2), not just the UI (FR-3). `001-match-pairs-service`'s Stage 1 domain-model work surfaced ADR-5 (`memory-bank/bolts/005-lesson-engagement-service/adr-5-client-side-grading-with-bounded-server-ledger.md`): all exercise grading in this codebase is client-side, so `match_pairs` grading belongs here, not in the backend unit. It requires no separate story — it's already covered by story `001-match-pairs-exercise-screen`'s tap-attempt acceptance criteria.

## Scope

### In Scope
- New match-pairs exercise widget/screen: two shuffled columns (Amharic term / English translation), tap-one-from-each-side interaction, locked-correct / incorrect-attempt / unselected visual states
- **Grading**: comparing a tap-matched pair against the canonical pairing already present in the served content (client-side, instant — no backend call)
- Wiring into `LessonController`'s existing grade/advance/Beans-XP flow
- Verification that a downloaded pack containing a `match_pairs` exercise plays fully offline with zero network calls

### Out of Scope
- Backend content serving (owned by `001-match-pairs-service`) — this unit consumes that content, it doesn't fetch/store it independently
- Any change to the other 3 exercise-type screens
- Any change to the offline download/sync code itself (verification only — expected to work by construction since content is text-only)

---

## Assigned Requirements

| FR | Requirement | Priority |
|----|-------------|----------|
| FR-2 | Match-Pairs Grading (Client-Side) | Must |
| FR-3 | Match-Pairs Client UI (Tap-Tile-Pairs) | Must |
| FR-4 | Offline Compatibility | Must |

---

## Domain Concepts

### Key Entities
| Entity | Description | Attributes |
|--------|-------------|------------|
| `MatchPairsTileState` (client-only) | Per-tile UI state during an attempt | unselected / selected / locked-correct / incorrect-flash |

### Key Operations
| Operation | Description | Inputs | Outputs |
|-----------|-------------|--------|---------|
| RenderMatchPairsExercise | Show shuffled tile columns | `MatchPairsContent` | Rendered exercise screen |
| AttemptPair | Handle a tap-one-from-each-side pair attempt; **grades locally** by comparing the two selected tile ids against the served `correct_pairs` (the API response's answer-key field — **corrected during `011-match-pairs-service`'s Implement stage**: content and answer key are separate, like `multiple_choice`, not merged into one self-revealing blob) | two selected tile ids | Locked (correct) or flash-and-deselect (incorrect) |
| CompleteExercise | All pairs matched → hand off to existing grade/advance flow | — | Same `LessonController` flow as other exercise types |

---

## Story Summary

| Metric | Count |
|--------|-------|
| Total Stories | 2 |
| Must Have | 2 |
| Should Have | 0 |
| Could Have | 0 |

### Stories

| Story ID | Title | Priority | Status |
|----------|-------|----------|--------|
| 001-match-pairs-exercise-screen | Take a match-pairs exercise via tap-tile-pairs | Must | Complete |
| 002-offline-match-pairs-verification | Match-pairs exercises work fully offline | Must | Complete |

---

## Dependencies

### Depends On
| Unit | Reason |
|------|--------|
| `001-match-pairs-service` | Needs the new content shape to render and the grading contract to submit against |

### Depended By
| Unit | Reason |
|------|--------|
| None | Terminal unit for this intent |

### External Dependencies
| System | Purpose | Risk |
|--------|---------|------|
| None | — | — |

---

## Technical Context

### Suggested Technology
Flutter/Dart, extending `lib/features/lesson/` (new widget alongside `choice_tile.dart`, `word_bank_builder.dart`) rather than a parallel feature tree — same pattern used by every prior lesson-loop/offline bolt.

### Integration Points
| Integration | Type | Protocol |
|-------------|------|----------|
| `001-match-pairs-service` | API | REST over HTTPS (existing lesson-content/completion endpoints) |

### Data Storage
| Data | Type | Volume | Retention |
|------|------|--------|-----------|
| None new | — | — | Reuses existing `LessonPackStore`/`PendingSyncQueueStore` from `003-offline-caching-and-sync` untouched |

---

## Constraints

- Reuses `LessonController`'s existing grade/advance/Beans-XP logic exactly — no parallel implementation.
- Must not require any change to `003-offline-caching-and-sync`'s download/offline-take code; this unit's second story exists specifically to verify that claim rather than assume it.

---

## Success Criteria

### Functional
- [x] A user can complete a `match_pairs` exercise via tap-only interaction with correct visual feedback at each state (atomic Check model, not live per-pair feedback — see Story 001's corrected AC)
- [x] A downloaded pack containing a `match_pairs` exercise plays fully offline with zero network calls

### Non-Functional
- [x] No regression to the other 3 exercise-type screens or to the existing offline path (126/127 Flutter tests pass; the 1 failure is a pre-existing unrelated e2e test)

### Quality
- [x] Widget test coverage for the new exercise screen and its offline path (8 new tests)
- [x] All acceptance criteria met
- [x] Code reviewed and approved

---

## Bolt Suggestions

| Bolt | Type | Stories | Objective |
|------|------|---------|-----------|
| TBD-match-pairs-ui | simple-construction-bolt | 001, 002 | Tap-tile-pairs screen + offline verification |

---

## Notes

Small, self-contained unit. Depends on `001-match-pairs-service` completing first (needs the real content/grading contract, not a guessed shape).
