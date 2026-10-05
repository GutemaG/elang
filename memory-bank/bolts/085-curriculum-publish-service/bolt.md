---
id: 085-curriculum-publish-service
unit: 001-curriculum-service
intent: 025-curriculum-workspace
type: simple-construction-bolt
status: complete
stories: []
created: '2026-10-05T10:30:00Z'
started: '2026-10-05T12:45:04Z'
completed: '2026-10-05T13:03:00Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-10-05T12:46:00Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-10-05T12:52:00Z'
    artifact: implementation-plan.md
  - name: test
    completed: '2026-10-05T13:02:59Z'
    artifact: implementation-plan.md
requires_bolts:
  - 082-curriculum-store
enables_bolts:
  - 086-curriculum-generate-and-publish
requires_units: []
blocks: false
complexity:
  avg_complexity: 3
  avg_uncertainty: 2
  max_dependencies: 1
  testing_scope: 2
---

# Bolt: 085-curriculum-publish-service

## Objective

Keep a lesson's draft exercises and publish one lesson into the live course: its category and skill when new, the lesson, its exercises and vocab items, in one transaction, beside the existing content.

## Stories Included

Written in the unit brief (`intents/025-curriculum-workspace/units/001-curriculum-service/unit-brief.md`), not
as separate files, so `stories:` above is empty.

- [x] **005-draft-exercises**
- [x] **006-publish-a-lesson**

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [x] **1. Plan**
- [x] **2. Implement**
- [x] **3. Test**

## Expected Outputs

- Migration: draft exercises and what was published
- Save draft exercises; publish a lesson; publish state in the read
- Tests; API notes

## Dependencies

### Requires
- `082-curriculum-store`

### Enables
- `086-curriculum-generate-and-publish`
