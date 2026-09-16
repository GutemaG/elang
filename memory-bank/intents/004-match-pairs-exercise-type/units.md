---
intent: 004-match-pairs-exercise-type
phase: inception
status: units-decomposed
updated: '2026-09-17T04:20:00Z'
---

# Match-Pairs Exercise Type - Unit Decomposition

## Units Overview

This intent decomposes into 2 units of work, mirroring the split already used by `002-core-lesson-loop` and `003-offline-caching-and-sync` (backend service + frontend UI):

### Unit 1: 001-match-pairs-service

**Description**: Backend `ExerciseType.MATCH_PAIRS` content model, seed data, and grading logic.

**Requirements**: FR-1, FR-2

**Deliverables**:
- `ExerciseType.MATCH_PAIRS` enum value
- Content/correct-answer models for term/translation pairs
- Grading use-case logic (all-or-nothing)
- ≥1 seeded `match_pairs` exercise

**Dependencies**:
- Depends on: none (extends existing `001-lesson-service` code from `002-core-lesson-loop`)
- Depended by: `002-match-pairs-ui`

**Estimated Complexity**: S

### Unit 2: 002-match-pairs-ui

**Description**: Flutter tap-tile-pairs exercise screen, wired into the existing exercise engine, verified against the existing offline path.

**Requirements**: FR-3, FR-4

**Deliverables**:
- New match-pairs exercise widget/screen (tap-tile-pairs interaction)
- Wiring into `LessonController`'s existing grade/advance flow
- Verification that a downloaded pack containing a `match_pairs` exercise plays offline with zero network calls (no new offline-path code expected)

**Dependencies**:
- Depends on: `001-match-pairs-service` (needs the new content shape to render/grade against)
- Depended by: none

**Estimated Complexity**: S

## Unit Dependency Graph

```text
[001-match-pairs-service] ──> [002-match-pairs-ui]
```

## Execution Order

1. `001-match-pairs-service` (backend content + grading)
2. `002-match-pairs-ui` (client UI + offline verification)
