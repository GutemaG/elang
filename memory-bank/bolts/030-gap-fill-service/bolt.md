---
id: 030-gap-fill-service
unit: 001-gap-fill-service
intent: 015-gap-fill-exercise-type
type: simple-construction-bolt
status: complete
stories:
  - 001-serve-gap-fill-exercise-content
created: '2026-09-20T12:45:00Z'
started: '2026-09-20T13:00:00Z'
completed: '2026-09-20T13:46:13Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-09-20T13:15:00Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-09-20T14:30:00Z'
    artifact: implementation-walkthrough.md
  - name: test
    completed: '2026-09-20T15:15:00Z'
    artifact: test-walkthrough.md
requires_bolts: []
enables_bolts:
  - 031-gap-fill-ui
requires_units: []
blocks: false
complexity:
  avg_complexity: 2
  avg_uncertainty: 2
  max_dependencies: 0
  testing_scope: 3
---

# Bolt: 030-gap-fill-service

## Overview

Add `gap_fill` to the backend lesson engine: the enum value, a `GapFillContent` value
object, a migration widening `ck_exercises_type`, response mapping, and seed content in
all four courses.

## Objective

A `gap_fill` exercise is served through the existing lesson-content endpoint, carrying
everything the client needs to render and grade it locally, with no new endpoint, no new
answer-key shape, and no change to the four existing types.

## Stories Included

- **001-serve-gap-fill-exercise-content** (Must)

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [ ] **1. Plan**
- [ ] **2. Implement**
- [ ] **3. Test**

## Dependencies

### Requires
- None — extends existing `001-lesson-service` code in place

### Enables
- `031-gap-fill-ui` (needs the real serialized contract)

## Success Criteria

- [ ] `ExerciseType.GAP_FILL` added; `GapFillContent` joins the `ExerciseContent` union
- [ ] The `AnswerKey` union is **unchanged** — `ChoiceAnswerKey` is reused
- [ ] Migration widens `ck_exercises_type` via `op.batch_alter_table`, with a verified downgrade/re-upgrade, and the duplicate literal in `ExerciseModel.__table_args__` updated too
- [ ] `gap_fill` exercises seeded in all four courses with authored per-language blank positions and `vocab_item_id` set
- [ ] Re-running the seed changes nothing
- [ ] `database-schema.md` updated
- [ ] Full backend suite green, no client file touched

## Notes

Two known traps, both from bolt 011's record:

1. **A migration IS needed.** Bolt 011 assumed it was not and was corrected during
   Implement. The `CHECK` is declared in two places — the migration and
   `ExerciseModel.__table_args__`.
2. **Keep `content` and `answer_key` separate.** Every existing type does; bolt 011's
   first design merged them into a self-revealing blob and had to be corrected.

One real decision to make at Plan, against real code, not on paper: whether the gap is a
sentinel in the existing non-null `prompt` column or structured segments inside
`content`. Write it down; if it turns out to be load-bearing for future types, it may
warrant an ADR.
