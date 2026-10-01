---
id: 074-league-week-close
unit: 001-league-service
intent: 023-weekly-leagues
type: simple-construction-bolt
status: complete
stories: []
created: '2026-10-01T06:14:45Z'
started: '2026-10-01T07:16:08Z'
completed: '2026-10-01T08:02:11Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-10-01T07:18:59Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-10-01T07:51:35Z'
    artifact: implementation-plan.md
  - name: test
    completed: '2026-10-01T08:02:11Z'
    artifact: implementation-plan.md
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

- [x] **005-close-a-week**

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [x] **1. Plan**
- [x] **2. Implement**
- [x] **3. Test**

## Expected Outputs

- Closing on demand, idempotent and concurrent-safe
- Moves and `league_reward` Amole rows
- The last-week result in the endpoint and its acknowledgement; tests; API notes

## Dependencies

### Requires
- `073-league-groups-and-ranking`

### Enables
- `076-league-results-and-dashboard`
