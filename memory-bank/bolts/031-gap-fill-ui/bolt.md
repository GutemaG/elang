---
id: 031-gap-fill-ui
unit: 002-gap-fill-ui
intent: 015-gap-fill-exercise-type
type: simple-construction-bolt
status: planned
stories:
  - 001-gap-fill-exercise-screen
  - 002-offline-gap-fill-verification
created: '2026-09-20T12:45:00Z'
started: null
completed: null
current_stage: null
stages_completed: []
requires_bolts:
  - 030-gap-fill-service
enables_bolts: []
requires_units: []
blocks: false
complexity:
  avg_complexity: 2
  avg_uncertainty: 2
  max_dependencies: 1
  testing_scope: 4
---

# Bolt: 031-gap-fill-ui

## Overview

Render and grade `gap_fill` in the Flutter client: a sentence with a gap the chosen word
fills in place, graded locally on Check, and proven to survive the offline pack path.

## Objective

A learner can complete a gap-fill exercise online and offline, and the four existing
exercise types behave exactly as before.

## Stories Included

- **001-gap-fill-exercise-screen** (Must)
- **002-offline-gap-fill-verification** (Must)

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [ ] **1. Plan**
- [ ] **2. Implement**
- [ ] **3. Test**

## Dependencies

### Requires
- `030-gap-fill-service` (the real serialized contract)

### Enables
- None (terminal bolt for this intent)

## Success Criteria

- [ ] Tapping a word puts it **in the gap**; Check is disabled until something is chosen
- [ ] Grading is local against `correct_choice_id`, with no network call on Check
- [ ] `LessonController`'s grade/advance/Beans/XP flow is reused unchanged
- [ ] Both halves of `lesson_pack_store.dart` handle `gap_fill`, with a round-trip test
- [ ] A pack containing a `gap_fill` exercise downloads, plays offline and syncs
- [ ] Renders without overflow in Fidel and Latin at more than one text scale
- [ ] Full Flutter suite green, `flutter analyze` clean, no backend file touched

## Notes

The sealed `Exercise` class turns most missed seams into compile errors. The exception is
`lesson_pack_store.dart`, which maps JSON by hand — a missing case there fails at runtime
instead. Treat that as the riskiest line in the bolt and test it directly.

On layout: prefer a structure that cannot overflow over one that predicts its own height.
The `011-dashboard-ui-polish` banner took three attempts to get right because a predicted
extent was a pixel short on device while every test passed — the test font's metrics are
not a phone's.
