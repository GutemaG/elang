---
id: 114-course-admin-workspace
unit: 006-course-admin-workspace
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
  - 106-language-scoped-routes
  - 111-configuration-nav
enables_bolts: []
requires_units: []
blocks: false
complexity:
  avg_complexity: 1
  avg_uncertainty: 1
  max_dependencies: 1
  testing_scope: 1
---

# Bolt: 114-course-admin-workspace

## Objective

Hide course and chart actions from course admins.

## Stories Included

Written in the unit brief (`intents/028-admin-roles/units/006-course-admin-workspace/unit-brief.md`), not
as separate files, so `stories:` above is empty.

- [x] **018-course-admin-workspace**

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [x] **1. Plan**
- [x] **2. Implement**
- [x] **3. Test**

## Expected Outputs

- Empty states and hidden actions in course lists, course tree and Sounds
- Vitest

## Dependencies

### Requires
- `106-language-scoped-routes`
- `111-configuration-nav`

### Enables
- None
