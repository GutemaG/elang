---
id: 007-core-lesson-loop-ui
unit: 002-core-lesson-loop-ui
intent: 002-core-lesson-loop
type: simple-construction-bolt
status: complete
stories:
  - 005-real-backend-integration
created: '2026-09-15T18:00:00Z'
started: '2026-09-16T15:00:00Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-09-16T15:05:00Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-09-16T16:30:00Z'
    artifact: (code changes across lib/shared/services, lib/features/lesson, backend/app amendments)
  - name: test
    completed: '2026-09-16T16:45:00Z'
    artifact: test-walkthrough.md
requires_bolts:
  - 004-lesson-content-service
  - 005-lesson-engagement-service
  - 006-core-lesson-loop-ui
enables_bolts: []
requires_units:
  - 001-lesson-service
blocks: true
complexity:
  avg_complexity: 2
  avg_uncertainty: 2
  max_dependencies: 3
  testing_scope: 3
completed: '2026-09-16T08:12:33Z'
---

# Bolt: 007-core-lesson-loop-ui

## Overview

Second and final bolt for the `002-core-lesson-loop-ui` unit. Wires the fake `LessonApi` from bolt 006 to the now-fully-implemented `001-lesson-service` backend (bolts 004 + 005) — same integration-seam pattern as `001-auth-onboarding`'s bolt 003, this time planned upfront rather than discovered afterward.

## Objective

Replace the fake `LessonApi` with a real HTTP-backed implementation, without changing screen/controller code beyond what the real response shapes require.

## Stories Included

- **005-real-backend-integration**: Real backend integration (Must)

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- ✅ **1. Plan**
- ✅ **2. Implement**
- ✅ **3. Test**

## Dependencies

### Requires
- `004-lesson-content-service` (Required): must be complete
- `005-lesson-engagement-service` (Required): must be complete
- `006-core-lesson-loop-ui` (Required): must be complete (the screens this plugs into)

### Enables
- None (terminal bolt for this intent, for now)

## Success Criteria

- [x] Real `LessonApi` implementation calling all live `001-lesson-service` endpoints
- [x] Full lesson loop (dashboard → lesson → completion → updated dashboard) works end-to-end against the real backend
- [x] Existing widget tests from bolt 006 still pass; new tests added for the real API's error-mapping

## Notes

Blocked until all 3 of its prerequisite bolts are complete — unlike `001-auth-onboarding`, this dependency is explicit from the start rather than a mid-project discovery.
