---
unit: 002-gap-fill-ui
intent: 015-gap-fill-exercise-type
phase: inception
status: complete
created: '2026-09-20T12:45:00Z'
updated: '2026-09-20T12:45:00Z'
---

# Unit Brief: Gap-Fill UI

## Purpose

Render and grade the `gap_fill` exercise in the Flutter client, and prove it survives the offline pack path. Grading lives here, not in the backend, per ADR-5.

## Scope

### In Scope
- `GapFillExercise` as a new subclass of the sealed `Exercise` in `lib/shared/models/exercise.dart`, plus its `isAnswerCorrect` arm
- Parsing in `http_lesson_api.dart`'s `_toExercise`, and in `fake_lesson_api.dart`
- **Both halves** of `lesson_pack_store.dart` (serialize and deserialize) plus a round-trip test
- A new widget rendering the sentence with a visible gap that the selected word fills in place
- New arms in `lesson_screen.dart`'s body switch and its `canSubmit` switch
- Verification that a pack containing a `gap_fill` exercise downloads, plays offline and syncs

### Out of Scope
- Any change to `LessonController`'s grade/advance/Beans/XP flow — it is reused unchanged
- Any change to `SyncEngine`/`PendingSyncQueueStore`/`LessonPackDownloader`
- Any change to the other four exercise widgets
- Typing into the gap; multi-gap sentences

---

## Assigned Requirements

| FR | Requirement | Priority |
|----|-------------|----------|
| FR-2 | Gap-Fill Client UI and Client-Side Grading | Must |
| FR-3 | Offline Compatibility | Must |

---

## Domain Concepts

### Key Entities
| Entity | Description | Attributes |
|--------|-------------|------------|
| `GapFillExercise` | Client model, a new arm of the sealed `Exercise` | the sentence split around its gap, the gloss, the options, and the correct option |

### Key Operations
| Operation | Description | Inputs | Outputs |
|-----------|-------------|--------|---------|
| Grade locally | Compare the selected option against the correct one, via the existing `isAnswerCorrect` | exercise + selected index | bool |

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
| 001-gap-fill-exercise-screen | Fill the gap by tapping a word | Must | Generated |
| 002-offline-gap-fill-verification | Gap-fill works inside a downloaded pack | Must | Generated |

---

## Dependencies

### Depends On
| Unit | Reason |
|------|--------|
| `001-gap-fill-service` | Needs the real serialized contract to render and grade against |

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
Flutter, extending the files bolts 007 and 012 established. The sealed `Exercise` class makes most omissions compile errors — with **one exception**: `lesson_pack_store.dart` maps to and from JSON by hand, so a missing case there fails at runtime, not at build. That is the seam this unit must not miss.

The tile presentation should reuse `choice_tile.dart` rather than introducing a new tile style; the only genuinely new rendering is the sentence with a gap that fills in place.

### Integration Points
| Integration | Type | Protocol |
|-------------|------|----------|
| Existing lesson-content endpoint | API | REST over HTTPS |
| Existing offline pack store | Local | JSON on device |

---

## Constraints

- Build-then-Check, graded atomically on Check — the model every existing type uses. No live per-tap feedback.
- Reuse the existing tile colour language for unselected/selected/correct/incorrect; do not introduce new states.
- The sentence must render correctly in **both** Fidel and Latin script, and at large text scales. Text metrics in this codebase have bitten before (see the `011-dashboard-ui-polish` banner overflow follow-ups) — prefer layouts that cannot overflow over predicted heights.
- Grading is local. No network call on Check.

---

## Success Criteria

### Functional
- [ ] A learner can complete a `gap_fill` exercise by tapping a word and then Check
- [ ] The chosen word appears in the gap before checking, so the learner reads the whole sentence
- [ ] The exercise plays offline from a downloaded pack with zero network calls

### Non-Functional
- [ ] No regression to the other four exercise types
- [ ] Full Flutter suite green, `flutter analyze` clean

### Quality
- [ ] Widget tests covering select, re-select, correct and incorrect
- [ ] A pack serialize/deserialize round-trip test covering `gap_fill`
- [ ] Rendering verified in Fidel and Latin at more than one text scale

---

## Bolt Suggestions

| Bolt | Type | Stories | Objective |
|------|------|---------|-----------|
| 031-gap-fill-ui | simple-construction-bolt | 001, 002 | Widget, parsing, offline round-trip and verification |

---

## Notes

The riskiest line of this unit is not the widget — it is the hand-written JSON in `lesson_pack_store.dart`, the only seam the compiler does not guard. Test it explicitly rather than trusting it.
