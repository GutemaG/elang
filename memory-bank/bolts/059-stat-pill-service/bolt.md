---
id: 059-stat-pill-service
unit: 001-stat-pill-service
intent: 013-stat-pill-interactions
type: simple-construction-bolt
status: complete
stories: []
created: '2026-09-30T05:44:19Z'
started: '2026-09-30T06:37:35Z'
completed: '2026-09-30T07:56:33Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-09-30T06:41:14Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-09-30T07:45:32Z'
    artifact: implementation-plan.md
  - name: test
    completed: '2026-09-30T07:56:33Z'
    artifact: implementation-plan.md
requires_bolts: []
enables_bolts:
  - 061-streak-and-amole-sheets
requires_units: []
blocks: false
complexity:
  avg_complexity: 2
  avg_uncertainty: 1
  max_dependencies: 1
  testing_scope: 2
---

# Bolt: 059-stat-pill-service

## Objective

Add the two read-only endpoints the streak and Amole sheets need: practised days with the current and longest streak, and recent Amole entries. No table, no migration.

## Stories Included

Written in the unit brief (`intents/013-stat-pill-interactions/units/001-stat-pill-service/unit-brief.md`), not
as separate files, so `stories:` above is empty.

- [ ] **001-streak-history-read (Should)**
- [ ] **002-amole-history-read (Should)**

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [x] **1. Plan**: includes choosing both route names and response shapes
- [x] **2. Implement**
- [x] **3. Test**

## Expected Outputs

- Streak history route, schema and repository query (fixed query count, 186-day cap)
- Amole history route, schema and repository query
- pytest coverage for ranges, limits, empty learners, other learners' rows and 401
- API notes updated

## Dependencies

### Requires
- None

### Enables
- `061-streak-and-amole-sheets`
