---
id: 060-stat-pills-and-beans
unit: 002-stat-pill-ui
intent: 013-stat-pill-interactions
type: simple-construction-bolt
status: complete
stories: []
created: '2026-09-30T05:44:19Z'
started: '2026-09-30T05:51:47Z'
completed: '2026-09-30T06:34:22Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-09-30T05:53:03Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-09-30T06:30:24Z'
    artifact: implementation-plan.md
  - name: test
    completed: '2026-09-30T06:34:21Z'
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

# Bolt: 060-stat-pills-and-beans

## Objective

Make all four counters tappable, and give beans a sheet with the next bean's countdown and the Amole refill, online and offline. Needs no backend change.

## Stories Included

Written in the unit brief (`intents/013-stat-pill-interactions/units/002-stat-pill-ui/unit-brief.md`), not
as separate files, so `stories:` above is empty.

- [ ] **001-tappable-pills (Must)**
- [ ] **002-beans-sheet (Must)**

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [x] **1. Plan**: includes deciding one sheet component or four
- [x] **2. Implement**
- [x] **3. Test**

## Expected Outputs

- A tappable `StatPill` with a 48 dp tap area and one button node, wired through `LessonHud`
- The beans sheet: count, countdown, refill, full and offline states
- Beans timing kept in the offline dashboard copy, older copies still loading
- The streak, Amole and XP pills open a simple placeholder sheet until bolt 061
- Widget tests and gallery entries

## Dependencies

### Requires
- None

### Enables
- `061-streak-and-amole-sheets`
