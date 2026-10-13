---
id: 113-team-member-dialogs
unit: 005-team-page
intent: 028-admin-roles
type: simple-construction-bolt
status: complete
stories: []
created: '2026-10-13T09:30:00Z'
started: '2026-10-13T13:30:00Z'
completed: '2026-10-13T14:19:09Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-10-13T16:30:00Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-10-13T16:30:00Z'
    artifact: implementation-plan.md
  - name: test
    completed: '2026-10-13T16:30:00Z'
    artifact: implementation-plan.md
requires_bolts:
  - 109-team-write-api
  - 112-team-list-page
enables_bolts: []
requires_units: []
blocks: false
complexity:
  avg_complexity: 2
  avg_uncertainty: 1
  max_dependencies: 1
  testing_scope: 1
---

# Bolt: 113-team-member-dialogs

## Objective

Add, edit and remove admins from the Team page.

## Stories Included

Written in the unit brief (`intents/028-admin-roles/units/005-team-page/unit-brief.md`), not
as separate files, so `stories:` above is empty.

- [x] **016-member-dialog**
- [x] **017-remove-member**

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [x] **1. Plan**
- [x] **2. Implement**
- [x] **3. Test**

## Expected Outputs

- `MemberDialog`, `RemoveMemberDialog`
- Vitest

## Dependencies

### Requires
- `109-team-write-api`
- `112-team-list-page`

### Enables
- None
