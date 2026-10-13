---
id: 111-configuration-nav
unit: 004-role-aware-shell
intent: 028-admin-roles
type: simple-construction-bolt
status: complete
stories: []
created: '2026-10-13T09:30:00Z'
started: '2026-10-13T13:30:00Z'
completed: '2026-10-13T14:19:08Z'
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
  - 110-session-role
enables_bolts:
  - 112-team-list-page
  - 114-course-admin-workspace
requires_units: []
blocks: false
complexity:
  avg_complexity: 1
  avg_uncertainty: 1
  max_dependencies: 1
  testing_scope: 1
---

# Bolt: 111-configuration-nav

## Objective

Group configuration pages and keep course admins out of them.

## Stories Included

Written in the unit brief (`intents/028-admin-roles/units/004-role-aware-shell/unit-brief.md`), not
as separate files, so `stories:` above is empty.

- [x] **014-configuration-nav**

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [x] **1. Plan**
- [x] **2. Implement**
- [x] **3. Test**

## Expected Outputs

- Configuration nav group, `/team` placeholder
- Super-admin route guard in `App.tsx`
- Vitest

## Dependencies

### Requires
- `110-session-role`

### Enables
- `112-team-list-page`
- `114-course-admin-workspace`
