---
id: 029-course-switcher-panel
unit: 001-dashboard-shell-ui
intent: 011-dashboard-ui-polish
type: simple-construction-bolt
status: complete
stories:
  - 003-course-rail-and-add-course
  - 004-course-settings-and-downloads-access
created: '2026-09-21T03:00:00Z'
started: '2026-09-21T05:35:00Z'
completed: '2026-09-20T11:40:49Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-09-21T05:50:00Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-09-21T06:30:00Z'
    artifact: implementation-walkthrough.md
requires_bolts:
  - 028-dashboard-shell
enables_bolts: []
requires_units: []
blocks: false
complexity:
  avg_complexity: 3
  avg_uncertainty: 3
  max_dependencies: 1
  testing_scope: 4
---

# Bolt: 029-course-switcher-panel

## Overview

Replace the course chip with a badge that expands a horizontal rail of the learner's
courses, add a `+ Course` tile opening the rebuilt catalog, and move course settings and
Manage Downloads out of the top bar into that panel.

## Objective

Choosing a course, adding one and reaching course settings read as a single, polished
flow from one control in the header, with nothing already shipped regressing.

## Stories Included

- **003-course-rail-and-add-course** (Must)
- **004-course-settings-and-downloads-access** (Must)

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [ ] **1. Plan**
- [ ] **2. Implement**
- [ ] **3. Test**

## Dependencies

### Requires
- `028-dashboard-shell` (the header the panel hangs from)

### Enables
- None (terminal bolt for this intent)

## Success Criteria

- [ ] The rail comes from the course API, active course ringed, animated open and close
- [ ] `+ Course` opens the rebuilt catalog; coming-soon courses disabled
- [ ] Course settings and Manage Downloads reachable from the panel in two taps
- [ ] ADR-14 offline rules unchanged and still proven by tests
- [ ] Full Flutter suite green, `flutter analyze` clean, no backend or model file touched

## Notes

Expect an ADR: `GET /courses` returns every course, so how the rail derives "my courses"
is a real decision. What the badge displays (no flag artwork ships) belongs with it.
