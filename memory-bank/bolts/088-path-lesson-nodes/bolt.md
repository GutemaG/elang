---
id: 088-path-lesson-nodes
unit: 002-path-lessons-app
intent: 026-lesson-path-nodes
type: simple-construction-bolt
status: complete
stories: []
created: '2026-10-06T08:58:00Z'
started: '2026-10-06T09:10:00Z'
completed: '2026-10-06T09:32:00Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-10-06T09:11:00Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-10-06T09:20:00Z'
    artifact: implementation-plan.md
  - name: test
    completed: '2026-10-06T09:32:00Z'
    artifact: implementation-plan.md
requires_bolts:
  - 087-path-lessons-service
enables_bolts: []
requires_units:
  - 001-path-lessons-service
blocks: false
complexity:
  avg_complexity: 2
  avg_uncertainty: 2
  max_dependencies: 1
  testing_scope: 2
---

# Bolt: 088-path-lesson-nodes

## Objective

Draw one bubble per lesson on the home path, under its skill's label, with lesson states and taps, and no "Lesson N of M".

## Stories Included

Written in the unit brief (`intents/026-lesson-path-nodes/units/002-path-lessons-app/unit-brief.md`), not
as separate files, so `stories:` above is empty.

- [x] **002-one-bubble-per-lesson**
- [x] **003-lesson-states-and-taps**
- [x] **004-no-parts-of-a-skill**
- [x] **005-older-backend-and-saved-copies**

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [x] **1. Plan**
- [x] **2. Implement**
- [x] **3. Test**

## Expected Outputs

- The model and the path's stops
- Lesson bubbles, skill labels, popover states
- Strings in three languages
- Tests

## Dependencies

### Requires
- `087-path-lessons-service`

### Enables
- None
