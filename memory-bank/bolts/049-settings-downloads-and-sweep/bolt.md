---
id: 049-settings-downloads-and-sweep
unit: 003-screen-migration-ui
intent: 018-mobile-design-system
type: simple-construction-bolt
status: complete
stories:
  - 004-settings-and-downloads-on-the-library
  - 005-consistency-sweep
created: '2026-09-24T12:55:00Z'
started: '2026-09-26T05:34:17Z'
completed: '2026-09-26T06:30:22Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-09-26T05:36:05Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-09-26T05:59:46Z'
    artifact: implementation-walkthrough.md
  - name: test
    completed: '2026-09-26T06:30:22Z'
    artifact: test-walkthrough.md
requires_bolts:
  - 045-lesson-screen-on-kit
  - 046-onboarding-screens-on-kit
  - 047-dashboard-on-kit
  - 048-lesson-complete-and-sheets-on-kit
enables_bolts: []
requires_units: []
blocks: false
complexity:
  avg_complexity: 2
  avg_uncertainty: 1
  max_dependencies: 1
  testing_scope: 3
---

# Bolt: 049-settings-downloads-and-sweep

## Objective

Move settings and downloads onto the library, then run the app-wide sweep: empty allow-list, layout and text-scale checks, reduced motion, and on-device font and reference checks.

## Stories Included

- [x] **004-settings-and-downloads-on-the-library** (Must)
- [x] **005-consistency-sweep** (Must)

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [x] **1. Plan**: includes choosing and recording each story's reference design (FR-11): the Stitch mockup, or fetched external designs
- [x] **2. Implement**
- [x] **3. Test**

## Expected Outputs

- Settings and downloads on the library
- Empty rules allow-list
- Sweep findings in the test walkthrough

## Dependencies

### Requires
- `045-lesson-screen-on-kit`
- `046-onboarding-screens-on-kit`
- `047-dashboard-on-kit`
- `048-lesson-complete-and-sheets-on-kit`

### Enables
- None in this intent (bolt 033, spell tiles, should follow 044)

## Success Criteria

- Every story's acceptance criteria met
- Gallery shows every new component and state
- Rules test passes; its allow-list is no longer than before
- `flutter analyze` clean; full Flutter test suite passes
