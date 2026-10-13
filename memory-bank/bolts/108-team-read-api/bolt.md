---
id: 108-team-read-api
unit: 003-team-api
intent: 028-admin-roles
type: simple-construction-bolt
status: complete
stories: []
created: '2026-10-13T09:30:00Z'
started: '2026-10-13T13:30:00Z'
completed: '2026-10-13T14:19:06Z'
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
  - 102-admin-access-check
enables_bolts:
  - 109-team-write-api
  - 112-team-list-page
requires_units: []
blocks: false
complexity:
  avg_complexity: 1
  avg_uncertainty: 1
  max_dependencies: 1
  testing_scope: 2
---

# Bolt: 108-team-read-api

## Objective

List the team for super admins.

## Stories Included

Written in the unit brief (`intents/028-admin-roles/units/003-team-api/unit-brief.md`), not
as separate files, so `stories:` above is empty.

- [x] **011-list-team**

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [x] **1. Plan**
- [x] **2. Implement**
- [x] **3. Test**

## Expected Outputs

- `GET /admin/team` with owners, courses and last sign-in
- Tests

## Dependencies

### Requires
- `102-admin-access-check`

### Enables
- `109-team-write-api`
- `112-team-list-page`
