---
id: 083-curriculum-import
unit: 002-curriculum-admin
intent: 025-curriculum-workspace
type: simple-construction-bolt
status: complete
stories: []
created: '2026-10-05T10:30:00Z'
started: '2026-10-05T12:23:55Z'
completed: '2026-10-05T12:36:52Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-10-05T12:26:00Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-10-05T12:33:00Z'
    artifact: implementation-plan.md
  - name: test
    completed: '2026-10-05T12:36:51Z'
    artifact: implementation-plan.md
requires_bolts:
  - 082-curriculum-store
enables_bolts:
  - 084-curriculum-review-and-record
requires_units:
  - 001-curriculum-service
blocks: false
complexity:
  avg_complexity: 2
  avg_uncertainty: 2
  max_dependencies: 1
  testing_scope: 2
---

# Bolt: 083-curriculum-import

## Objective

The Curriculum tab for each course: the overview with progress, reading the curriculum workbook in the browser, the import preview and confirm, and export to Excel.

## Stories Included

Written in the unit brief (`intents/025-curriculum-workspace/units/002-curriculum-admin/unit-brief.md`), not
as separate files, so `stories:` above is empty.

- [x] **007-curriculum-tab-and-overview**
- [x] **008-read-the-workbook**
- [x] **009-import-preview-and-confirm**
- [x] **010-export-to-excel**

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [x] **1. Plan**
- [x] **2. Implement**
- [x] **3. Test**

## Expected Outputs

- Curriculum page and overview
- Workbook reader (library chosen at plan)
- Import preview and confirm; export
- Tests

## Dependencies

### Requires
- `082-curriculum-store`

### Enables
- `084-curriculum-review-and-record`
