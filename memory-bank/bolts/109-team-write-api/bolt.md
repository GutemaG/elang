---
id: 109-team-write-api
unit: 003-team-api
intent: 028-admin-roles
type: simple-construction-bolt
status: complete
stories: []
created: '2026-10-13T09:30:00Z'
started: '2026-10-13T13:30:00Z'
completed: '2026-10-13T14:19:07Z'
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
  - 108-team-read-api
enables_bolts:
  - 113-team-member-dialogs
requires_units: []
blocks: false
complexity:
  avg_complexity: 2
  avg_uncertainty: 1
  max_dependencies: 2
  testing_scope: 2
---

# Bolt: 109-team-write-api

## Objective

Add, change and remove admins with the team rules.

## Stories Included

Written in the unit brief (`intents/028-admin-roles/units/003-team-api/unit-brief.md`), not
as separate files, so `stories:` above is empty.

- [x] **012-change-team**

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [x] **1. Plan**
- [x] **2. Implement**
- [x] **3. Test**

## Expected Outputs

- `POST`, `PUT`, `DELETE /admin/team…`
- Errors from FR-11
- Tests including immediate loss of access

## Dependencies

### Requires
- `108-team-read-api`

### Enables
- `113-team-member-dialogs`
