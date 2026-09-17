---
id: 018-amole-ui
unit: 002-amole-ui
intent: 007-amole-currency
type: simple-construction-bolt
status: complete
stories:
  - 001-amole-balance-on-dashboard
created: '2026-09-17T16:30:00Z'
started: '2026-09-17T20:00:00Z'
completed: '2026-09-17T16:16:57Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-09-17T20:00:00Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-09-17T20:20:00Z'
    artifact: implementation-walkthrough.md
  - name: test
    completed: '2026-09-17T20:35:00Z'
    artifact: test-walkthrough.md
requires_bolts:
  - 017-amole-service
enables_bolts: []
requires_units:
  - 001-amole-service
blocks: false
complexity:
  avg_complexity: 1
  avg_uncertainty: 1
  max_dependencies: 1
  testing_scope: 1
---

# Bolt: 018-amole-ui

## Overview

Adds the Amole balance display to the home dashboard. This is the entire remaining frontend scope for this intent — the out-of-Beans modal's spend UI (what the original build prompt described as "002-amole-ui") is already shipped and correct.

## Objective

The dashboard shows the current Amole balance next to XP/streak, updating after any lesson completion or refill.

## Stories Included

- **001-amole-balance-on-dashboard**: dashboard display (Must)

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [x] **1. Plan**: ✅ Complete → implementation-plan.md
- [x] **2. Implement**: ✅ Complete → implementation-walkthrough.md
- [x] **3. Test**: ✅ Complete → test-walkthrough.md

## Dependencies

### Requires
- `017-amole-service` (needs the retrofitted balance value to display; response shape is unchanged so this is low-risk to build against, but should not start before `017` lands)

### Enables
- None (terminal bolt for this intent)

## Success Criteria

- [ ] Balance visible on the dashboard, next to XP/streak
- [ ] Updates after lesson completion and after a refill, with no manual refresh needed
- [ ] Zero regression to `skill_tree_dashboard_screen_test.dart`

## Notes

Verify at Plan stage exactly how the dashboard already fetches beans-status data (for the existing Beans HUD) and reuse that path rather than adding a second fetch.
