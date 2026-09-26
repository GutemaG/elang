---
id: 047-dashboard-on-kit
unit: 003-screen-migration-ui
intent: 018-mobile-design-system
type: simple-construction-bolt
status: complete
stories:
  - 002-dashboard-and-course-picker-on-the-library
created: '2026-09-24T12:55:00Z'
started: '2026-09-25T20:50:30Z'
completed: '2026-09-26T05:28:36Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-09-25T20:54:39Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-09-26T04:33:47Z'
    artifact: implementation-walkthrough.md
  - name: test
    completed: '2026-09-26T05:28:35Z'
    artifact: test-walkthrough.md
requires_bolts:
  - 043-design-surfaces
enables_bolts:
  - 049-settings-downloads-and-sweep
requires_units: []
blocks: false
complexity:
  avg_complexity: 3
  avg_uncertainty: 2
  max_dependencies: 1
  testing_scope: 3
---

# Bolt: 047-dashboard-on-kit

## Objective

Move the dashboard, its header, banners, path nodes, practice card, sync banner, the course picker and the home placeholder onto the library, matching the dashboard mockup.

## Stories Included

- [x] **002-dashboard-and-course-picker-on-the-library** (Must)

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [x] **1. Plan**: includes choosing and recording each story's reference design (FR-11): the Stitch mockup, or fetched external designs
- [x] **2. Implement**
- [x] **3. Test**

## Expected Outputs

- Dashboard and course files on the library
- Their files off the allow-list

## Dependencies

### Requires
- `043-design-surfaces`

### Enables
- `049-settings-downloads-and-sweep`

## Success Criteria

- Every story's acceptance criteria met
- Gallery shows every new component and state
- Rules test passes; its allow-list is no longer than before
- `flutter analyze` clean; full Flutter test suite passes
