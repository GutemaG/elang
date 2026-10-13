---
id: 107-route-guard-sweep
unit: 002-route-permissions
intent: 028-admin-roles
type: simple-construction-bolt
status: complete
stories: []
created: '2026-10-13T09:30:00Z'
started: '2026-10-13T13:30:00Z'
completed: '2026-10-13T14:19:05Z'
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
  - 103-super-admin-routes
  - 105-child-id-routes
  - 106-language-scoped-routes
enables_bolts: []
requires_units: []
blocks: false
complexity:
  avg_complexity: 2
  avg_uncertainty: 2
  max_dependencies: 2
  testing_scope: 2
---

# Bolt: 107-route-guard-sweep

## Objective

Fail the build when an admin route has no role rule.

## Stories Included

Written in the unit brief (`intents/028-admin-roles/units/002-route-permissions/unit-brief.md`), not
as separate files, so `stories:` above is empty.

- [x] **010-route-guard-sweep**

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [x] **1. Plan**
- [x] **2. Implement**
- [x] **3. Test**

## Expected Outputs

- Route rule table
- Sweep test over every `/api/v1/admin` route
- Cross-course attempt test

## Dependencies

### Requires
- `103-super-admin-routes`
- `105-child-id-routes`
- `106-language-scoped-routes`

### Enables
- None
