---
id: 100-admin-roles-domain
unit: 001-admin-access-service
intent: 028-admin-roles
type: simple-construction-bolt
status: complete
stories: []
created: '2026-10-13T09:30:00Z'
started: '2026-10-13T09:40:00Z'
completed: '2026-10-13T10:00:12Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-10-13T09:45:00Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-10-13T10:00:00Z'
    artifact: implementation-plan.md
requires_bolts: []
enables_bolts:
  - 101-admin-members-store
requires_units: []
blocks: false
complexity:
  avg_complexity: 1
  avg_uncertainty: 1
  max_dependencies: 1
  testing_scope: 1
---

# Bolt: 100-admin-roles-domain

## Objective

Model owners, super admins and course admins as pure domain code.

## Stories Included

Written in the unit brief (`intents/028-admin-roles/units/001-admin-access-service/unit-brief.md`), not
as separate files, so `stories:` above is empty.

- [x] **001-admin-roles-domain**

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [x] **1. Plan**
- [x] **2. Implement**
- [x] **3. Test**

## Expected Outputs

- `ADMIN_ROLES`, `AdminAccess`, `normalise_email`, `resolve_access` in `app/domain/admin.py`
- Unit tests

## Dependencies

### Requires
- None

### Enables
- `101-admin-members-store`
