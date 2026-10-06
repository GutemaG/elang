---
id: 087-path-lessons-service
unit: 001-path-lessons-service
intent: 026-lesson-path-nodes
type: simple-construction-bolt
status: complete
stories: []
created: '2026-10-06T08:58:00Z'
started: '2026-10-06T08:59:00Z'
completed: '2026-10-06T09:08:31Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-10-06T09:00:00Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-10-06T09:02:00Z'
    artifact: implementation-plan.md
  - name: test
    completed: '2026-10-06T09:08:31Z'
    artifact: implementation-plan.md
requires_bolts: []
enables_bolts:
  - 088-path-lesson-nodes
requires_units: []
blocks: false
complexity:
  avg_complexity: 2
  avg_uncertainty: 2
  max_dependencies: 1
  testing_scope: 2
---

# Bolt: 087-path-lessons-service

## Objective

Send each skill's lessons, in order and with whether each is done in the current pass, on `GET /api/v1/skill-tree`.

## Stories Included

Written in the unit brief (`intents/026-lesson-path-nodes/units/001-path-lessons-service/unit-brief.md`), not
as separate files, so `stories:` above is empty.

- [x] **001-lessons-in-the-skill-tree**

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [x] **1. Plan**
- [x] **2. Implement**
- [x] **3. Test**

## Expected Outputs

- A grouped read of lesson ids and titles
- `lessons` on each skill
- Tests; API notes

## Dependencies

### Requires
- None

### Enables
- `088-path-lesson-nodes`
