---
id: 082-curriculum-store
unit: 001-curriculum-service
intent: 025-curriculum-workspace
type: simple-construction-bolt
status: complete
stories: []
created: '2026-10-05T10:30:00Z'
started: '2026-10-05T12:02:06Z'
completed: '2026-10-05T12:19:52Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-10-05T12:05:00Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-10-05T12:12:00Z'
    artifact: implementation-plan.md
  - name: test
    completed: '2026-10-05T12:19:51Z'
    artifact: implementation-plan.md
requires_bolts: []
enables_bolts:
  - 083-curriculum-import
  - 084-curriculum-review-and-record
  - 085-curriculum-publish-service
requires_units: []
blocks: false
complexity:
  avg_complexity: 2
  avg_uncertainty: 2
  max_dependencies: 0
  testing_scope: 2
---

# Bolt: 082-curriculum-store

## Objective

Keep a course's curriculum as a draft: the plan and row tables (one backward-compatible migration), an atomic import that merges by ID with a dry run, the read with counts, editing a row with a version check, and a row's audio.

## Stories Included

Written in the unit brief (`intents/025-curriculum-workspace/units/001-curriculum-service/unit-brief.md`), not
as separate files, so `stories:` above is empty.

- [x] **001-draft-curriculum-tables**
- [x] **002-import-the-curriculum**
- [x] **003-edit-a-row**
- [x] **004-a-rows-audio**

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [x] **1. Plan**
- [x] **2. Implement**
- [x] **3. Test**

## Expected Outputs

- Migration: plan entries and rows
- Import (with dry run), read, edit a row, set a row's audio
- Tests; API notes

## Dependencies

### Requires
None.

### Enables
- `083-curriculum-import`
- `084-curriculum-review-and-record`
- `085-curriculum-publish-service`
