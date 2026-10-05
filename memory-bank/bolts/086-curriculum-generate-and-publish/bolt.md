---
id: 086-curriculum-generate-and-publish
unit: 002-curriculum-admin
intent: 025-curriculum-workspace
type: simple-construction-bolt
status: complete
stories: []
created: '2026-10-05T10:30:00Z'
started: '2026-10-05T13:03:49Z'
completed: '2026-10-05T13:11:00Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-10-05T13:04:30Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-10-05T13:08:00Z'
    artifact: implementation-plan.md
  - name: test
    completed: '2026-10-05T13:11:00Z'
    artifact: implementation-plan.md
requires_bolts:
  - 084-curriculum-review-and-record
  - 085-curriculum-publish-service
enables_bolts: []
requires_units:
  - 001-curriculum-service
blocks: false
complexity:
  avg_complexity: 3
  avg_uncertainty: 2
  max_dependencies: 2
  testing_scope: 2
---

# Bolt: 086-curriculum-generate-and-publish

## Objective

Generate a lesson's exercises from its rows with the lesson CSV import's rules, preview and edit them in the existing exercise editor, and publish the lesson from its page.

## Stories Included

Written in the unit brief (`intents/025-curriculum-workspace/units/002-curriculum-admin/unit-brief.md`), not
as separate files, so `stories:` above is empty.

- [x] **013-generate-exercises**
- [x] **014-edit-generated-exercises**
- [x] **015-publish-from-the-admin**

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [x] **1. Plan**
- [x] **2. Implement**
- [x] **3. Test**

## Expected Outputs

- Generate from rows; preview
- Edit in the exercise editor; reset to generated
- Publish button and state
- Tests

## Dependencies

### Requires
- `084-curriculum-review-and-record`
- `085-curriculum-publish-service`

### Enables
None.
