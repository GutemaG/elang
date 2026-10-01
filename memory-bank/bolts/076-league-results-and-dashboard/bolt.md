---
id: 076-league-results-and-dashboard
unit: 002-league-ui
intent: 023-weekly-leagues
type: simple-construction-bolt
status: planned
stories: []
created: '2026-10-01T06:14:45Z'
started: null
completed: null
current_stage: null
stages_completed: []
requires_bolts:
  - 074-league-week-close
  - 075-league-screen
enables_bolts: []
requires_units: []
blocks: false
complexity:
  avg_complexity: 2
  avg_uncertainty: 1
  max_dependencies: 2
  testing_scope: 2
---

# Bolt: 076-league-results-and-dashboard

## Objective

Last week's result in a one-time sheet, and the learner's tier and rank on the dashboard.

## Stories Included

Written in the unit brief (`intents/023-weekly-leagues/units/002-league-ui/unit-brief.md`), not
as separate files, so `stories:` above is empty.

- [ ] **008-week-result-sheet**
- [ ] **009-dashboard-league-card**

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [ ] **1. Plan**
- [ ] **2. Implement**
- [ ] **3. Test**

## Expected Outputs

- Result sheet with acknowledgement
- Dashboard league card, refreshed after lessons; tests; debug APK

## Dependencies

### Requires
- `074-league-week-close`
- `075-league-screen`

### Enables
- None
