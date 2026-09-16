---
id: 011-match-pairs-service
unit: 001-match-pairs-service
intent: 004-match-pairs-exercise-type
type: ddd-construction-bolt
status: complete
stories:
  - 001-serve-match-pairs-exercise-content
created: '2026-09-17T04:35:00Z'
started: '2026-09-17T05:05:00Z'
completed: '2026-09-16T20:25:25Z'
current_stage: null
stages_completed:
  - name: model
    completed: '2026-09-17T05:10:00Z'
    artifact: ddd-01-domain-model.md
  - name: design
    completed: '2026-09-17T05:20:00Z'
    artifact: ddd-02-technical-design.md
  - name: adr
    completed: '2026-09-17T05:25:00Z'
    artifact: none (no ADR-worthy decisions found)
  - name: implement
    completed: '2026-09-17T05:50:00Z'
    artifact: backend/app (amended) + migration c726efa81972
  - name: test
    completed: '2026-09-17T06:10:00Z'
    artifact: ddd-03-test-report.md
requires_bolts: []
enables_bolts:
  - 012-match-pairs-ui
requires_units: []
blocks: false
complexity:
  avg_complexity: 1
  avg_uncertainty: 1
  max_dependencies: 1
  testing_scope: 1
---

# Bolt: 011-match-pairs-service

## Overview

Only bolt for the `001-match-pairs-service` unit. Extends the existing `001-lesson-service` backend (from `002-core-lesson-loop`, bolts 004/005) with a 4th exercise type, `match_pairs`: content model + seed data only, reusing the existing `ExerciseType` dispatch pattern exactly.

**Scope corrected 2026-09-17** during this bolt's own Stage 1 (Domain Model) prior-decision lookup: the original plan included a `002-grade-match-pairs-attempts` story here, but ADR-5 (bolt 005) already established that all exercise grading is client-side. That story is retired (see `memory-bank/intents/004-match-pairs-exercise-type/units/001-match-pairs-service/stories/002-grade-match-pairs-attempts.md`) and its behavior is delivered by `012-match-pairs-ui` instead — no backend grading logic exists for this exercise type.

## Objective

Deliver the content contract that `012-match-pairs-ui` builds against, with zero regression to the existing `multiple_choice`/`listening`/`sentence_construction` exercise types.

## Stories Included

- **001-serve-match-pairs-exercise-content**: Serve match-pairs exercise content (incl. seed data) (Must)

## Bolt Type

**Type**: DDD Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/ddd-construction-bolt.md`

## Stages

- [ ] **1. Domain Model**: Pending → ddd-01-domain-model.md
- [ ] **2. Technical Design**: Pending → ddd-02-technical-design.md
- [ ] **3. ADR Analysis**: Pending → adr-*.md (if any decision warrants one)
- [ ] **4. Implement**: Pending → backend/ (amended)
- [ ] **5. Test**: Pending → ddd-03-test-report.md

## Dependencies

### Requires
- None to start — amends `001-lesson-service` (intent `002-core-lesson-loop`), which is already complete

### Enables
- `012-match-pairs-ui` (needs the real content shape and grading contract, not a guessed one)

## Success Criteria

- [ ] `ExerciseType.MATCH_PAIRS` served through the existing lesson-content endpoint with no per-type special-casing beyond content shape
- [ ] Served content is self-sufficient for client-side grading (each `{left, right}` pair is its own ground truth — no separate answer-key field)
- [ ] At least 1 seeded `match_pairs` exercise exists in the curriculum
- [ ] `002-core-lesson-loop`'s existing backend test suite still passes in full

## Notes

Small, self-contained — no new external dependency, no expected schema risk since exercises already store type-specific content as JSON per `002-core-lesson-loop`'s domain model (verify during Technical Design). Single bolt is likely sufficient.
