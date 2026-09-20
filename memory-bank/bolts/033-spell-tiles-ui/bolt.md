---
id: 033-spell-tiles-ui
unit: 002-spell-tiles-ui
intent: 016-spell-from-tiles-exercise-type
type: simple-construction-bolt
status: planned
stories:
  - 001-spell-tiles-exercise-screen
  - 002-offline-spell-tiles-verification
created: '2026-09-20T18:10:00Z'
started: null
completed: null
current_stage: null
stages_completed: []
requires_bolts:
  - 032-spell-tiles-service
enables_bolts: []
requires_units: []
blocks: false
complexity:
  avg_complexity: 3
  avg_uncertainty: 2
  max_dependencies: 1
  testing_scope: 4
---

# Bolt: 033-spell-tiles-ui

## Overview

Render and grade `spell_tiles` in the Flutter client with an **id-keyed** tile interaction,
and prove it survives the offline pack path.

## Objective

A learner can spell a word — including one with repeated characters — online and offline,
and the five existing exercise types behave exactly as before.

## Stories Included

- **001-spell-tiles-exercise-screen** (Must)
- **002-offline-spell-tiles-verification** (Must)

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [ ] **1. Plan**
- [ ] **2. Implement**
- [ ] **3. Test**

## Dependencies

### Requires
- `032-spell-tiles-service` (the real serialized contract)

### Enables
- None (terminal bolt for this intent)

## Success Criteria

- [ ] Tapping a tile places its character; Check is disabled until one is placed
- [ ] A word with repeated characters behaves correctly — tapping one twin affects only it
- [ ] Grading is local against `correct_sequence`, with no network call on Check
- [ ] `LessonController`'s grade/advance/Beans/XP flow is reused unchanged
- [ ] Both halves of `lesson_pack_store.dart` handle `spell_tiles`, round-tripped with a repeating word
- [ ] A pack containing a `spell_tiles` exercise downloads, plays offline and syncs
- [ ] Renders without overflow at up to 12 tiles, in Fidel and Latin, at more than one text scale
- [ ] `word_bank_builder.dart`, `SentenceConstructionExercise` and the `sentence_construction` parse path are unchanged in the diff
- [ ] Full Flutter suite green, `flutter analyze` clean, no backend file touched

## Notes

This bolt carries the one genuinely new thing in the intent, and its risk is not where the
sealed class can help.

**Identity by id, end to end.** Every existing tile path in this codebase keys by text:
`WordBankBuilder` does `built.contains(token)`, `http_lesson_api.dart` builds a `textById`
map and discards the ids, the seed does `{tile["text"]: tile["id"]}`. Writing this one by
reflex — by copying the nearest neighbour — reproduces exactly the bug this intent exists to
avoid. Copying the `sentence_construction` parse branch is the specific mistake to not make.

**A passing test can hide it.** A test that spells `ቡና` passes against a text-keyed
implementation. The repeated-character test is the load-bearing one; write it first.

**Do not extend `word_bank_builder.dart`.** It is the layout reference, not the
implementation. Sharing it was considered and rejected at Checkpoint 1 — the reasoning is in
`units.md` under "Note on Not Sharing the Word Bank", so a later reader does not undo the
decision by accident.

**`lesson_pack_store.dart` is still the only unguarded seam.** Bolt `031` lifted its four
mapping functions to the top level and built the round-trip harness, so covering this type is
cheap now. Cheap is not automatic — and the falsification step (remove the read case, watch
it compile and fail at runtime) is an acceptance criterion, not a nicety.

On layout: prefer a structure that cannot overflow over one that predicts its own height. The
`011-dashboard-ui-polish` banner took three attempts because a predicted extent was a pixel
short on device while every test passed. Eleven tiles at 2.0x is this bolt's version of that.
