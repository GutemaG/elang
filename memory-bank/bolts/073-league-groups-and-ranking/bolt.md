---
id: 073-league-groups-and-ranking
unit: 001-league-service
intent: 023-weekly-leagues
type: simple-construction-bolt
status: complete
stories: []
created: '2026-10-01T06:14:45Z'
started: '2026-10-01T06:24:57Z'
completed: '2026-10-01T07:13:41Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-10-01T06:41:40Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-10-01T06:54:51Z'
    artifact: implementation-plan.md
  - name: test
    completed: '2026-10-01T07:13:41Z'
    artifact: implementation-plan.md
requires_bolts: []
enables_bolts:
  - 074-league-week-close
  - 075-league-screen
requires_units: []
blocks: false
complexity:
  avg_complexity: 3
  avg_uncertainty: 2
  max_dependencies: 1
  testing_scope: 3
---

# Bolt: 073-league-groups-and-ranking

## Objective

Learners join a group of their tier with the week's first XP and see it ranked through the league endpoint; Google first names are stored; "Show me in leagues" is the first account setting.

## Stories Included

Written in the unit brief (`intents/023-weekly-leagues/units/001-league-service/unit-brief.md`), not
as separate files, so `stories:` above is empty.

- [x] **001-first-name-from-google**
- [x] **002-join-a-weekly-group**
- [x] **003-ranking-and-league-endpoint**
- [x] **004-show-in-leagues-setting**

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [x] **1. Plan**
- [x] **2. Implement**
- [x] **3. Test**

## Expected Outputs

- The migration (league groups, members, results; `users.first_name`)
- League domain constants and tiers; joining on lesson and practice completions
- `given_name` from the Google verifier, stored at sign-in
- `show_in_leagues` in `ACCOUNT_SETTINGS`
- `GET /api/v1/leagues/current` (open week); tests; API notes

## Dependencies

### Requires
- None

### Enables
- `074-league-week-close`
- `075-league-screen`
