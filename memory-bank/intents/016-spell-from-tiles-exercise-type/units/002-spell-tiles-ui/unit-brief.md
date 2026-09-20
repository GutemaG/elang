---
unit: 002-spell-tiles-ui
intent: 016-spell-from-tiles-exercise-type
phase: inception
status: stories-defined
created: '2026-09-20T18:10:00Z'
updated: '2026-09-20T18:10:00Z'
---

# Unit Brief: Spell-Tiles UI

## Purpose

Render and grade the `spell_tiles` exercise in the Flutter client with an **id-keyed** tile interaction, and prove it survives the offline pack path. Grading lives here, not in the backend, per ADR-5.

## Scope

### In Scope
- `SpellTilesExercise` as a new subclass of the sealed `Exercise` in `lib/shared/models/exercise.dart`, plus its `isAnswerCorrect` arm
- Parsing in `http_lesson_api.dart`'s `_toExercise` that **preserves tile ids**, and in `fake_lesson_api.dart`
- **Both halves** of `lesson_pack_store.dart` plus a round-trip test using a word with repeated characters
- A new id-keyed widget: a spelling tray over a shuffled tile bank
- New arms in `lesson_screen.dart`'s body switch and its `canSubmit` switch

### Out of Scope
- **Any change to `word_bank_builder.dart`, `SentenceConstructionExercise`, or the `sentence_construction` parse path.** This is a hard boundary, decided at Checkpoint 1
- Any change to `LessonController`'s grade/advance/Beans/XP flow
- Any change to `SyncEngine`/`PendingSyncQueueStore`/`LessonPackDownloader`
- Any change to the other five exercise widgets
- Typing the spelling instead of tapping tiles

---

## Assigned Requirements

| FR | Requirement | Priority |
|----|-------------|----------|
| FR-2 | Spell-Tiles Client UI and Client-Side Grading | Must |
| FR-3 | Offline Compatibility | Must |

---

## Domain Concepts

### Key Entities
| Entity | Description | Attributes |
|--------|-------------|------------|
| `SpellTilesExercise` | Client model, a new arm of the sealed `Exercise` | the from-language prompt word, the id-bearing tiles in display order, and the correct tile-id sequence |

A tile type carrying `(id, text)` is needed. `MatchPairsTile` already exists with exactly that shape and exactly that rationale — "needs a stable id because position alone can no longer identify which tile". Whether to reuse it or add a sibling is a Plan-stage call; reusing a type named for another exercise has its own cost.

### Key Operations
| Operation | Description | Inputs | Outputs |
|-----------|-------------|--------|---------|
| Place a tile | Append a tile id to the built spelling | tile id | updated `List<String>` |
| Remove a tile | Remove **that** tile id from the built spelling | tile id | updated `List<String>` |
| Grade locally | Compare the built id sequence against the correct one | exercise + `List<String>` | bool |

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
| 001-spell-tiles-exercise-screen | Spell a word by tapping character tiles | Must | Generated |
| 002-offline-spell-tiles-verification | Spell-tiles works inside a downloaded pack | Must | Generated |

---

## Dependencies

### Depends On
| Unit | Reason |
|------|--------|
| `001-spell-tiles-service` | Needs the real serialized contract to render and grade against |

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

Flutter, extending the files bolts 007, 012 and 031 established.

The central discipline is **identity by id, end to end**. `LessonController.toggleWordBankToken` is already a generic toggle over a `List<String>` and may work unchanged when handed ids rather than tokens — confirm that against the real code at the Plan stage rather than assuming it, and if it does, consider whether its name still tells the truth. The parse step and the widget are where text-keying currently lives, and both must be written fresh for this type.

`word_bank_builder.dart` is the design reference for the tray-over-bank layout. It is **not** the implementation to extend.

### Integration Points
| Integration | Type | Protocol |
|-------------|------|----------|
| Existing lesson-content endpoint | API | REST over HTTPS |
| Existing offline pack store | Local | JSON on device |

---

## Constraints

- Build-then-Check, graded atomically on Check. No live per-tap feedback.
- Reuse the existing tile colour language for unselected/placed/correct/incorrect; do not introduce new states.
- Must render without overflow at up to **12 tiles**, in both Fidel and Latin, at more than one text scale. Afaan Oromo is the demanding case. Text metrics in this codebase have bitten before (the `011-dashboard-ui-polish` banner needed three attempts) — prefer layouts that cannot overflow over predicted extents.
- Grading is local. No network call on Check.
- Tests must use a genuinely repeating word. A test that only spells `ቡና` would pass against a text-keyed implementation and prove nothing.

---

## Success Criteria

### Functional
- [ ] A learner can spell a word by tapping tiles in order and then Check
- [ ] A word with repeated characters behaves correctly: tapping one twin affects only that twin
- [ ] The exercise plays offline from a downloaded pack with zero network calls

### Non-Functional
- [ ] No regression to the other five exercise types, and `sentence_construction`'s files are untouched
- [ ] Full Flutter suite green, `flutter analyze` clean

### Quality
- [ ] Widget tests covering place, remove, correct, incorrect, **and a repeated-character word**
- [ ] A pack serialize/deserialize round-trip test covering `spell_tiles` with a repeating word
- [ ] Rendering verified at up to 12 tiles in Fidel and Latin at more than one text scale

---

## Bolt Suggestions

| Bolt | Type | Stories | Objective |
|------|------|---------|-----------|
| 033-spell-tiles-ui | simple-construction-bolt | 001, 002 | Widget, parsing, offline round-trip and verification |

---

## Notes

Two risks, ranked.

**First: silent text-keying.** Every existing tile path in this codebase keys by text. Writing this one by reflex reproduces the bug the intent exists to avoid, and a test using a non-repeating word will not catch it. The repeated-character test is the load-bearing one.

**Second: `lesson_pack_store.dart`.** Still the only seam the compiler does not guard in both directions. `031` built the round-trip harness and lifted the mapping functions to the top level, so covering this type is now cheap — but cheap is not automatic.
