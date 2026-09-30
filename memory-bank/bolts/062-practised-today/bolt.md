---
id: 062-practised-today
unit: 001-daily-reminder-service
intent: 021-daily-reminder
type: simple-construction-bolt
status: complete
stories: []
created: '2026-09-30T08:40:29Z'
started: '2026-09-30T08:44:00Z'
completed: '2026-09-30T08:49:49Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-09-30T08:47:00Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-09-30T08:49:09Z'
    artifact: implementation-plan.md
  - name: test
    completed: '2026-09-30T08:49:49Z'
    artifact: implementation-plan.md
requires_bolts: []
enables_bolts:
  - 063-reminder-scheduler
requires_units: []
blocks: false
complexity:
  avg_complexity: 1
  avg_uncertainty: 1
  max_dependencies: 0
  testing_scope: 1
---

# Bolt: 062-practised-today

## Objective

Add `practised_today` to the skill tree answer, from the streak row it already reads. No table, no migration.

## Stories Included

Written in the unit brief (`intents/021-daily-reminder/units/001-daily-reminder-service/unit-brief.md`), not
as separate files, so `stories:` above is empty.

- [x] **001-practised-today (Must)**

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [x] **1. Plan**: includes confirming no extra query
- [x] **2. Implement**
- [x] **3. Test**

## Expected Outputs

- `practised_today` in the use case, schema and route
- pytest: new learner, today, yesterday, review only, query count
- API notes updated

## Dependencies

### Requires
- None

### Enables
- `063-reminder-scheduler`
