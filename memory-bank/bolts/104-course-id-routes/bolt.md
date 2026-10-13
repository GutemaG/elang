---
id: 104-course-id-routes
unit: 002-route-permissions
intent: 028-admin-roles
type: simple-construction-bolt
status: complete
stories: []
created: '2026-10-13T09:30:00Z'
started: '2026-10-13T13:30:00Z'
completed: '2026-10-13T14:19:03Z'
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
  - 105-child-id-routes
  - 106-language-scoped-routes
requires_units: []
blocks: false
complexity:
  avg_complexity: 2
  avg_uncertainty: 1
  max_dependencies: 2
  testing_scope: 2
---

# Bolt: 104-course-id-routes

## Objective

Filter the course list and check routes named by course.

## Stories Included

Written in the unit brief (`intents/028-admin-roles/units/002-route-permissions/unit-brief.md`), not
as separate files, so `stories:` above is empty.

- [x] **006-course-list-filtered**
- [x] **007-course-id-routes**

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [x] **1. Plan**
- [x] **2. Implement**
- [x] **3. Test**

## Expected Outputs

- `require_course` check
- Filtered `GET /admin/courses`
- Tests for tree, vocab and Workbook routes

## Dependencies

### Requires
- `102-admin-access-check`

### Enables
- `105-child-id-routes`
- `106-language-scoped-routes`
