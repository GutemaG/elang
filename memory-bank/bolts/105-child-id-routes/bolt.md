---
id: 105-child-id-routes
unit: 002-route-permissions
intent: 028-admin-roles
type: simple-construction-bolt
status: complete
stories: []
created: '2026-10-13T09:30:00Z'
started: '2026-10-13T13:30:00Z'
completed: '2026-10-13T14:19:04Z'
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
  - 104-course-id-routes
enables_bolts:
  - 107-route-guard-sweep
requires_units: []
blocks: false
complexity:
  avg_complexity: 2
  avg_uncertainty: 2
  max_dependencies: 2
  testing_scope: 2
---

# Bolt: 105-child-id-routes

## Objective

Check the course behind section, skill, lesson, exercise and word routes.

## Stories Included

Written in the unit brief (`intents/028-admin-roles/units/002-route-permissions/unit-brief.md`), not
as separate files, so `stories:` above is empty.

- [x] **008-child-id-routes**

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [x] **1. Plan**
- [x] **2. Implement**
- [x] **3. Test**

## Expected Outputs

- `course_of(kind, id)` repository method
- Checks on child routes, uploads with `lesson_id` and generate with `lesson_id`
- Tests

## Dependencies

### Requires
- `104-course-id-routes`

### Enables
- `107-route-guard-sweep`
