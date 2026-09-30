---
id: 061-streak-and-amole-sheets
unit: 002-stat-pill-ui
intent: 013-stat-pill-interactions
type: simple-construction-bolt
status: complete
stories: []
created: '2026-09-30T05:44:19Z'
started: '2026-09-30T07:57:55Z'
completed: '2026-09-30T08:23:49Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-09-30T07:58:38Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-09-30T08:22:41Z'
    artifact: implementation-plan.md
  - name: test
    completed: '2026-09-30T08:23:49Z'
    artifact: implementation-plan.md
requires_bolts:
  - 059-stat-pill-service
  - 060-stat-pills-and-beans
enables_bolts: []
requires_units: []
blocks: false
complexity:
  avg_complexity: 2
  avg_uncertainty: 2
  max_dependencies: 2
  testing_scope: 2
---

# Bolt: 061-streak-and-amole-sheets

## Objective

Build the streak calendar, the Amole sheet with recent entries, and the XP sheet, on the reads from bolt 059.

## Stories Included

Written in the unit brief (`intents/013-stat-pill-interactions/units/002-stat-pill-ui/unit-brief.md`), not
as separate files, so `stories:` above is empty.

- [ ] **003-streak-calendar (Should)**
- [ ] **004-amole-sheet (Should)**
- [ ] **005-xp-sheet (Could)**

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [x] **1. Plan**: includes whether calendar months are cached after the first load
- [x] **2. Implement**
- [x] **3. Test**

## Expected Outputs

- `LessonApi` methods for both reads, in the HTTP and fake APIs
- The streak calendar sheet: month view, 6 months back, current and longest streak, loading, error and offline states
- The Amole sheet: explanation, balance, 20 recent entries, empty, error and offline states
- The XP sheet
- Widget tests and gallery entries

## Dependencies

### Requires
- `059-stat-pill-service`
- `060-stat-pills-and-beans`

### Enables
- None
