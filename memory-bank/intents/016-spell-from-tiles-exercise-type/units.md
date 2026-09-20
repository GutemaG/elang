---
intent: 016-spell-from-tiles-exercise-type
phase: inception
status: units-decomposed
updated: '2026-09-20T18:10:00Z'
---

# Spell-From-Tiles Exercise Type - Unit Decomposition

## Units Overview

Two units, mirroring the backend-service + frontend-UI split used by `002-core-lesson-loop`, `003-offline-caching-and-sync`, `004-match-pairs-exercise-type` and `015-gap-fill-exercise-type`. The seam is the same one every exercise type has used: the UI needs the real serialized contract before it can render or grade against it.

The two units are **not** the same size this time. The backend unit is the cheapest an exercise type has been — no new answer key, no new authored content, source material already seeded. The client unit carries the one genuinely new thing in this intent, an id-keyed tile interaction. The bolt plan reflects that rather than pretending they are symmetric.

### Unit 1: 001-spell-tiles-service

**Description**: Backend `ExerciseType.SPELL_TILES` content model, migration, response mapping and seed content across all four courses.

**Requirements**: FR-1

**Deliverables**:
- `ExerciseType.SPELL_TILES` enum value and `SpellTilesContent` value object
- Migration widening `ck_exercises_type` via `op.batch_alter_table`, on `d1b7e4f2a903`
- Repository reconstruction, response schema and mapping
- Seeded `spell_tiles` exercises in all four courses, with shuffled id-keyed character tiles and two distractors, **preserving duplicate characters**
- **No** new `AnswerKey` union member — reuses `SequenceAnswerKey`
- **No** `vocab_item_id`, asserted by a test

**Dependencies**:
- Depends on: none (extends existing `001-lesson-service` code in place)
- Depended by: `002-spell-tiles-ui`

**Estimated Complexity**: S

### Unit 2: 002-spell-tiles-ui

**Description**: A new id-keyed tile-spelling widget wired into the existing exercise engine, plus verification that it survives the offline pack path.

**Requirements**: FR-2, FR-3

**Deliverables**:
- `SpellTilesExercise` sealed subclass, API parsing that **keeps tile ids**, `isAnswerCorrect` arm
- A new widget: a spelling tray over a shuffled tile bank, keyed by id so repeated characters behave
- Both halves of `lesson_pack_store.dart` plus a round-trip test using a word with repeated characters
- Wiring into `LessonController`'s existing grade/advance flow

**Dependencies**:
- Depends on: `001-spell-tiles-service` (needs the real serialized shape)
- Depended by: none

**Estimated Complexity**: M — larger than `015`'s client unit, because the interaction is new rather than an arm on an existing widget

## Unit Dependency Graph

```text
[001-spell-tiles-service] ──> [002-spell-tiles-ui]
```

## Execution Order

1. `001-spell-tiles-service` (backend model + migration + seed)
2. `002-spell-tiles-ui` (client widget + offline verification)

## Note on Grading

There is deliberately **no grading unit or story**. Per ADR-5 all exercise grading in this codebase is client-side, so grading is an acceptance criterion of `002-spell-tiles-ui`'s screen story, not work of its own. `004-match-pairs-exercise-type` created a backend grading story here and had to retire it mid-Construction; `015` did not repeat it, and neither does this.

## Note on Not Sharing the Word Bank

There is also deliberately no "generalise `WordBankBuilder`" unit. It was considered and rejected at Checkpoint 1: making the existing widget id-keyed would edit a shipped, tested type and its parse path for the benefit of a type that does not exist yet. The duplication is a known, accepted cost, recorded here so a later reader does not mistake it for an oversight. If a third tile-based type appears, that is the moment to reconsider — not now.
