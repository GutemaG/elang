---
id: 103-super-admin-routes
unit: 002-route-permissions
intent: 028-admin-roles
type: simple-construction-bolt
status: complete
stories: []
created: '2026-10-13T09:30:00Z'
started: '2026-10-13T12:05:00Z'
completed: '2026-10-13T13:24:53Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-10-13T12:10:00Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-10-13T12:30:00Z'
    artifact: implementation-plan.md
requires_bolts:
  - 102-admin-access-check
enables_bolts:
  - 107-route-guard-sweep
requires_units: []
blocks: false
complexity:
  avg_complexity: 1
  avg_uncertainty: 1
  max_dependencies: 2
  testing_scope: 2
---

# Bolt: 103-super-admin-routes

## Objective

Keep configuration, course writes, learners and feedback to super admins.

## Stories Included

Written in the unit brief (`intents/028-admin-roles/units/002-route-permissions/unit-brief.md`), not
as separate files, so `stories:` above is empty.

- [x] **005-super-admin-only-routes**

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [x] **1. Plan**
- [x] **2. Implement**
- [x] **3. Test**

## Expected Outputs

- `require_super_admin` on the FR-5 routes
- Parametrised refusal test

## Dependencies

### Requires
- `102-admin-access-check`

### Enables
- `107-route-guard-sweep`
