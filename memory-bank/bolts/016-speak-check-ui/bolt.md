---
id: 016-speak-check-ui
unit: 002-speak-check-ui
intent: 006-speak-check-exercise-type
type: simple-construction-bolt
status: deferred
stories:
  - 001-speak-check-exercise-screen
  - 002-exclude-speak-check-from-offline-packs
created: '2026-09-17T15:00:00Z'
started: null
completed: null
current_stage: null
stages_completed: []

requires_bolts:
  - 015-speak-check-service
enables_bolts: []
requires_units:
  - 001-speak-check-service
blocks: true

complexity:
  avg_complexity: 2
  avg_uncertainty: 2
  max_dependencies: 1
  testing_scope: 2
---

# Bolt: 016-speak-check-ui

## ⛔ DEFERRED — Do Not Start

Blocked on `015-speak-check-service`, which is itself **deferred by explicit user decision on 2026-09-17** (Google Cloud Speech-to-Text provisioning postponed to the future). Do not start this bolt until `015` is complete and un-deferred.

## Overview

The client half of `speak_check`: recording UI, submission, pass/fail feedback with unlimited retries, and offline-pack exclusion.

## Objective

Deliver a working `speak_check` exercise screen end-to-end against the real `015-speak-check-service` contract, with zero regression to any existing exercise type or the offline-download flow.

## Stories Included

- **001-speak-check-exercise-screen**: recording UI + feedback (Must)
- **002-exclude-speak-check-from-offline-packs**: offline exclusion (Must)

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [ ] **1. Plan**: Pending → implementation-plan.md
- [ ] **2. Implement**: Pending → implementation-walkthrough.md
- [ ] **3. Test**: Pending → test-walkthrough.md

## Dependencies

### Requires
- `015-speak-check-service` (needs the real endpoint contract — currently blocked)

### Enables
- None (terminal bolt for this intent)

## Success Criteria

- [ ] Recording UI works end-to-end against the real backend
- [ ] Unlimited retries, no attempt cap
- [ ] `speak_check` exercises correctly excluded from offline packs, with zero regression to lessons without one
- [ ] No regression to any existing exercise type

## Notes

New Flutter recording package needed (none exists yet) — a Technical Design decision at Plan stage, following this bolt type's existing "read real source, then plan" convention (same as `012-match-pairs-ui`).
