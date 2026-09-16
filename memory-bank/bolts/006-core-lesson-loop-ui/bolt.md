---
id: 006-core-lesson-loop-ui
unit: 002-core-lesson-loop-ui
intent: 002-core-lesson-loop
type: simple-construction-bolt
status: complete
stories:
  - 001-skill-tree-dashboard-screen
  - 002-lesson-exercise-screens
  - 003-out-of-beans-and-refill-modal
  - 004-lesson-complete-streak-and-levelup-modals
created: '2026-09-15T18:00:00Z'
started: '2026-09-16T09:00:00Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-09-16T09:15:00Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-09-16T10:30:00Z'
    artifact: implementation-walkthrough.md
  - name: test
    completed: '2026-09-16T11:00:00Z'
    artifact: test-walkthrough.md
requires_bolts: []
enables_bolts:
  - 007-core-lesson-loop-ui
requires_units: []
blocks: false
complexity:
  avg_complexity: 2
  avg_uncertainty: 2
  max_dependencies: 2
  testing_scope: 2
completed: '2026-09-16T06:47:19Z'
---

# Bolt: 006-core-lesson-loop-ui

## Overview

First bolt for the `002-core-lesson-loop-ui` unit. Builds all lesson-loop screens (skill-tree dashboard, lesson exercises, out-of-beans modal, lesson-complete/streak/level-up modals) against a documented fake API, in parallel with the `001-lesson-service` backend bolts — same successful pattern as `001-auth-onboarding`'s original mock-first UI bolt.

## Objective

Deliver all new screens matching the Highland Pulse designs, fully testable in isolation via a fake `LessonApi` implementation, without waiting on the real backend to be complete.

## Stories Included

- **001-skill-tree-dashboard-screen**: Skill-tree home dashboard (Must)
- **002-lesson-exercise-screens**: Lesson exercise screens for all 3 types (Must)
- **003-out-of-beans-and-refill-modal**: Out-of-beans interruption + refill (Must)
- **004-lesson-complete-streak-and-levelup-modals**: Lesson-complete summary + streak/level-up (Should)

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- ✅ **1. Plan**
- ✅ **2. Implement**
- ✅ **3. Test**

## Dependencies

### Requires
- None to start (can scaffold against `001-lesson-service`'s Technical Design contract once available, before its implementation is complete — same pattern as `001-auth-onboarding`)

### Enables
- `007-core-lesson-loop-ui` (real integration swaps the fake API this bolt introduces)

## Success Criteria

- [x] All 4 stories' screens render matching their respective Stitch designs
- [x] Full lesson flow (dashboard → lesson → completion) is navigable end-to-end against the fake API
- [x] Widget tests cover all new screens

## Notes

Can run in parallel with bolts 004/005 (backend), matching how the user previously worked on `001-auth-onboarding`'s backend and frontend bolts simultaneously.
