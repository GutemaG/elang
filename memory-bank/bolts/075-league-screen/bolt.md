---
id: 075-league-screen
unit: 002-league-ui
intent: 023-weekly-leagues
type: simple-construction-bolt
status: complete
stories: []
created: '2026-10-01T06:14:45Z'
started: '2026-10-01T08:04:11Z'
completed: '2026-10-01T08:49:46Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-10-01T08:29:24Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-10-01T08:39:25Z'
    artifact: implementation-plan.md
  - name: test
    completed: '2026-10-01T08:49:46Z'
    artifact: implementation-plan.md
requires_bolts:
  - 073-league-groups-and-ranking
enables_bolts:
  - 076-league-results-and-dashboard
requires_units: []
blocks: false
complexity:
  avg_complexity: 2
  avg_uncertainty: 2
  max_dependencies: 1
  testing_scope: 2
---

# Bolt: 075-league-screen

## Objective

The league screen with the group's ranking, zones, rewards and time left, a saved copy for offline, the "Show me in leagues" switch and the first-visit name notice.

## Stories Included

Written in the unit brief (`intents/023-weekly-leagues/units/002-league-ui/unit-brief.md`), not
as separate files, so `stories:` above is empty.

- [x] **006-league-screen**
- [x] **007-show-in-leagues-switch**

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [x] **1. Plan**
- [x] **2. Implement**
- [x] **3. Test**

## Expected Outputs

- League API client and saved copy
- League screen (both themes, in the sweep)
- Settings switch; name notice; tests

## Dependencies

### Requires
- `073-league-groups-and-ranking`

### Enables
- `076-league-results-and-dashboard`
