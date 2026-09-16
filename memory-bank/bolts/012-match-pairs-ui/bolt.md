---
id: 012-match-pairs-ui
unit: 002-match-pairs-ui
intent: 004-match-pairs-exercise-type
type: simple-construction-bolt
status: complete
stories:
  - 001-match-pairs-exercise-screen
  - 002-offline-match-pairs-verification
created: '2026-09-17T04:35:00Z'
started: '2026-09-17T06:20:00Z'
completed: '2026-09-16T21:04:08Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-09-17T06:25:00Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-09-17T06:55:00Z'
    artifact: implementation-walkthrough.md
requires_bolts:
  - 011-match-pairs-service
enables_bolts: []
requires_units:
  - 001-match-pairs-service
blocks: false
complexity:
  avg_complexity: 1
  avg_uncertainty: 1
  max_dependencies: 1
  testing_scope: 2
---

# Bolt: 012-match-pairs-ui

## Overview

Only bolt for the `002-match-pairs-ui` unit. Flutter tap-tile-pairs exercise screen for `match_pairs`, wired into the existing `LessonController`/exercise-engine flow exactly as the other 3 exercise types, plus explicit verification against the existing offline download/take path from `003-offline-caching-and-sync`.

**Scope expanded 2026-09-17**: this unit now also delivers client-side grading (FR-2), reassigned here from `011-match-pairs-service` during that bolt's Stage 1 — ADR-5 (bolt 005) established all grading is client-side. No new story was needed; `001-match-pairs-exercise-screen`'s existing tap-attempt acceptance criteria already covers it.

## Objective

Deliver "a learner can take a match-pairs exercise, online or offline, with correct Beans/XP bookkeeping" end-to-end, with zero regression to the other 3 exercise-type screens or the existing offline path.

## Stories Included

- **001-match-pairs-exercise-screen**: Take a match-pairs exercise via tap-tile-pairs (Must)
- **002-offline-match-pairs-verification**: Match-pairs exercises work fully offline (Must)

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [ ] **1. Plan**: Pending → implementation-plan.md
- [ ] **2. Implement**: Pending → implementation-walkthrough.md
- [ ] **3. Test**: Pending → test-walkthrough.md

## Dependencies

### Requires
- `011-match-pairs-service` — ✅ complete as of 2026-09-17. Real contract to build against: `MatchPairsExerciseResponse` (`left_tiles`, `right_tiles`, `correct_pairs`) in `backend/app/infrastructure/api/lesson_schemas.py`.

### Enables
- None (terminal bolt for this intent)

## Success Criteria

- [ ] A user can complete a `match_pairs` exercise via tap-only interaction with correct locked-correct/incorrect-attempt/unselected visual states
- [ ] Grading is fully client-side (comparison against the served content's own pairing) — no backend grading call
- [ ] Completion hands off to `LessonController`'s existing grade/advance/Beans-XP flow unchanged
- [ ] A downloaded pack containing a `match_pairs` exercise plays fully offline with zero network calls
- [ ] An offline completion syncs through the existing `SyncEngine` with zero changes to that code

## Notes

`011-match-pairs-service` is now complete, so this bolt is unblocked. When starting: the response field for grading is `correct_pairs` (a list of `[left_id, right_id]` pairs), served alongside `left_tiles`/`right_tiles` — **not** a self-revealing single content blob (that was corrected during `011`'s Implement stage; see its `ddd-01-domain-model.md`/`ddd-02-technical-design.md` correction notes before assuming the shape described in this unit's original inception docs).
