---
id: 032-spell-tiles-service
unit: 001-spell-tiles-service
intent: 016-spell-from-tiles-exercise-type
type: simple-construction-bolt
status: complete
stories:
  - 001-serve-spell-tiles-exercise-content
created: '2026-09-20T18:10:00Z'
started: '2026-09-20T18:35:00Z'
completed: '2026-09-20T16:47:37Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-09-20T18:40:00Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-09-20T19:20:00Z'
    artifact: implementation-walkthrough.md
  - name: test
    completed: '2026-09-20T19:55:00Z'
    artifact: test-walkthrough.md
requires_bolts: []
enables_bolts:
  - 033-spell-tiles-ui
requires_units: []
blocks: false
complexity:
  avg_complexity: 2
  avg_uncertainty: 1
  max_dependencies: 0
  testing_scope: 3
---

# Bolt: 032-spell-tiles-service

## Overview

Add `spell_tiles` to the backend: enum value, content value object, migration, response
mapping and seed content in all four courses. No new answer key.

## Objective

A lesson containing a `spell_tiles` exercise serves through the existing endpoint with no
new envelope, and the five existing exercise types behave exactly as before.

## Stories Included

- **001-serve-spell-tiles-exercise-content** (Must)

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [ ] **1. Plan**
- [ ] **2. Implement**
- [ ] **3. Test**

## Dependencies

### Requires
- None

### Enables
- `033-spell-tiles-ui` (needs the real serialized contract)

## Success Criteria

- [ ] `ExerciseType.SPELL_TILES` and `SpellTilesContent` added; `AnswerKey` union unchanged
- [ ] Migration on `d1b7e4f2a903` widens `ck_exercises_type`, verified by hand up and down
- [ ] `ExerciseModel.__table_args__`'s duplicate CHECK literal widened in the same change
- [ ] Seeded in all four courses, appended after the gap-fill, idempotent
- [ ] A word with repeated characters keeps every tile, asserted by a test
- [ ] `vocab_item_id` is null, asserted by a test
- [ ] `test_exercise_type_dispatch.py` extended for the sixth type, not weakened
- [ ] Full backend suite green; ruff and mypy no worse than before; no client file touched

## Notes

Three traps, all of them known in advance because earlier bolts hit them.

**The seed's text-keyed helpers.** `_choices` and the `id_by_token = {tile["text"]: tile["id"]}`
idiom both assume tile text is unique. For spelling it is not — `Galatoomi` has two `a` and
two `o`. Write a separate helper with a docstring saying why, as bolt `030` did for
`_gap_choices`. Reusing the existing one will pass a naive test and produce a broken exercise.

**The migration is real work and the suite will not prove it.** The test DB uses
`Base.metadata.create_all` and never runs migrations. Bolt `011` assumed no migration was
needed and was wrong. Verify on a scratch SQLite file, six types → five → six.

**The guarded fall-through.** `_content_from_json` and `to_exercise_response` both end in a
`raise` that bolt `030` added, after discovering an unguarded `match_pairs` branch was
silently eating unknown types. Add explicit branches; leave the guard a `raise`.

One free win, worth confirming rather than assuming: `_answer_key_from_json` already handles
`correct_sequence` and should need no edit at all.
