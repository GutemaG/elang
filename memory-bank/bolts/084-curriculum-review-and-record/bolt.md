---
id: 084-curriculum-review-and-record
unit: 002-curriculum-admin
intent: 025-curriculum-workspace
type: simple-construction-bolt
status: complete
stories: []
created: '2026-10-05T10:30:00Z'
started: '2026-10-05T12:37:45Z'
completed: '2026-10-05T12:43:54Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-10-05T12:38:30Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-10-05T12:42:00Z'
    artifact: implementation-plan.md
  - name: test
    completed: '2026-10-05T12:43:53Z'
    artifact: implementation-plan.md
requires_bolts:
  - 082-curriculum-store
  - 083-curriculum-import
enables_bolts:
  - 086-curriculum-generate-and-publish
requires_units:
  - 001-curriculum-service
blocks: false
complexity:
  avg_complexity: 2
  avg_uncertainty: 1
  max_dependencies: 2
  testing_scope: 2
---

# Bolt: 084-curriculum-review-and-record

## Objective

A lesson's page where the admin and a native speaker correct each row, set its status and comment, and record or upload its audio with the existing recorder and clean-up, moving on with "Next unrecorded".

## Stories Included

Written in the unit brief (`intents/025-curriculum-workspace/units/002-curriculum-admin/unit-brief.md`), not
as separate files, so `stories:` above is empty.

- [x] **011-review-a-lessons-rows**
- [x] **012-record-a-row**

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [x] **1. Plan**
- [x] **2. Implement**
- [x] **3. Test**

## Expected Outputs

- Lesson page: edit, status, comment
- Record or upload per row; next unrecorded
- Tests

## Dependencies

### Requires
- `082-curriculum-store`
- `083-curriculum-import`

### Enables
- `086-curriculum-generate-and-publish`
