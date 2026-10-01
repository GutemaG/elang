---
id: 074-league-week-close
unit: 001-league-service
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
  - 073-league-groups-and-ranking
enables_bolts:
  - 076-league-results-and-dashboard
requires_units: []
blocks: false
complexity:
  avg_complexity: 3
  avg_uncertainty: 2
  max_dependencies: 1
  testing_scope: 3
---

# Bolt: 074-league-week-close

## Objective

An ended week is closed exactly once on the first league request after it: results stored, tiers moved, top three rewarded in Amole, and the result shown once.

## Stories Included

Written in the unit brief (`intents/023-weekly-leagues/units/001-league-service/unit-brief.md`), not
as separate files, so `stories:` above is empty.

- [ ] **005-close-a-week**

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [ ] **1. Plan**
- [ ] **2. Implement**
- [ ] **3. Test**

## Expected Outputs

- Closing on demand, idempotent and concurrent-safe
- Moves and `league_reward` Amole rows
- The last-week result in the endpoint and its acknowledgement; tests; API notes

## Dependencies

### Requires
- `073-league-groups-and-ranking`

### Enables
- `076-league-results-and-dashboard`
