---
id: 102-admin-access-check
unit: 001-admin-access-service
intent: 028-admin-roles
type: simple-construction-bolt
status: complete
stories: []
created: '2026-10-13T09:30:00Z'
started: '2026-10-13T11:05:00Z'
completed: '2026-10-13T12:51:40Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-10-13T11:10:00Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-10-13T11:40:00Z'
    artifact: implementation-plan.md
requires_bolts:
  - 101-admin-members-store
enables_bolts:
  - 103-super-admin-routes
  - 104-course-id-routes
  - 108-team-read-api
  - 110-session-role
requires_units: []
blocks: false
complexity:
  avg_complexity: 2
  avg_uncertainty: 1
  max_dependencies: 2
  testing_scope: 2
---

# Bolt: 102-admin-access-check

## Objective

Resolve access on every admin request and expose it on `/admin/me`.

## Stories Included

Written in the unit brief (`intents/028-admin-roles/units/001-admin-access-service/unit-brief.md`), not
as separate files, so `stories:` above is empty.

- [x] **003-admin-access-check**
- [x] **004-admin-me-role**

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [x] **1. Plan**
- [x] **2. Implement**
- [x] **3. Test**

## Expected Outputs

- `require_admin` returning `AdminAccess`, `require_super_admin`, `AdminContext.access`
- `/admin/me` with role and courses
- Integration tests

## Dependencies

### Requires
- `101-admin-members-store`

### Enables
- `103-super-admin-routes`
- `104-course-id-routes`
- `108-team-read-api`
- `110-session-role`
