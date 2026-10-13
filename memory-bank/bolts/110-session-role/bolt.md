---
id: 110-session-role
unit: 004-role-aware-shell
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
  - 102-admin-access-check
enables_bolts:
  - 111-configuration-nav
requires_units: []
blocks: false
complexity:
  avg_complexity: 1
  avg_uncertainty: 1
  max_dependencies: 1
  testing_scope: 1
---

# Bolt: 110-session-role

## Objective

Carry the role in the admin session.

## Stories Included

Written in the unit brief (`intents/028-admin-roles/units/004-role-aware-shell/unit-brief.md`), not
as separate files, so `stories:` above is empty.

- [x] **013-session-knows-role**

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [x] **1. Plan**
- [x] **2. Implement**
- [x] **3. Test**

## Expected Outputs

- `SessionState` role fields, `useAccess()`
- New not-on-the-team text
- Vitest

## Dependencies

### Requires
- `102-admin-access-check`

### Enables
- `111-configuration-nav`
