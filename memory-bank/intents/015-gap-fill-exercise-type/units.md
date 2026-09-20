---
intent: 015-gap-fill-exercise-type
phase: inception
status: units-decomposed
updated: '2026-09-20T12:45:00Z'
---

# Gap-Fill Exercise Type - Unit Decomposition

## Units Overview

Two units, mirroring the backend-service + frontend-UI split used by `002-core-lesson-loop`, `003-offline-caching-and-sync` and `004-match-pairs-exercise-type`. The seam is the same one every exercise type has used: the UI needs the real serialized contract before it can render or grade against it.

### Unit 1: 001-gap-fill-service

**Description**: Backend `ExerciseType.GAP_FILL` content model, migration, response mapping and seed content across all four courses.

**Requirements**: FR-1

**Deliverables**:
- `ExerciseType.GAP_FILL` enum value and `GapFillContent` value object
- Migration widening `ck_exercises_type` via `op.batch_alter_table`
- Repository reconstruction, response schema and mapping
- Seeded `gap_fill` exercises in all four courses, with authored blank positions and `vocab_item_id` set
- **No** new `AnswerKey` union member — reuses `ChoiceAnswerKey`

**Dependencies**:
- Depends on: none (extends existing `001-lesson-service` code in place)
- Depended by: `002-gap-fill-ui`

**Estimated Complexity**: S

### Unit 2: 002-gap-fill-ui

**Description**: Flutter gap-fill exercise widget wired into the existing exercise engine, plus verification that it survives the offline pack path.

**Requirements**: FR-2, FR-3

**Deliverables**:
- `GapFillExercise` sealed subclass, API parsing, `isAnswerCorrect` arm
- New widget: sentence with a visible gap the selected word fills in place
- Both halves of `lesson_pack_store.dart` plus a round-trip test
- Wiring into `LessonController`'s existing grade/advance flow

**Dependencies**:
- Depends on: `001-gap-fill-service` (needs the real serialized shape)
- Depended by: none

**Estimated Complexity**: S

## Unit Dependency Graph

```text
[001-gap-fill-service] ──> [002-gap-fill-ui]
```

## Execution Order

1. `001-gap-fill-service` (backend model + migration + seed)
2. `002-gap-fill-ui` (client widget + offline verification)

## Note on Grading

There is deliberately **no grading unit or story**. Per ADR-5 all exercise grading in this codebase is client-side, so grading is an acceptance criterion of `002-gap-fill-ui`'s screen story, not work of its own. Intent `004-match-pairs-exercise-type` created a backend grading story here and had to retire it mid-Construction; that is not repeated.
