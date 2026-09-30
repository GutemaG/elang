---
id: 070-appearance-setting
unit: 002-appearance-setting
intent: 022-light-and-dark-themes
type: simple-construction-bolt
status: complete
stories: []
created: '2026-09-30T13:52:00Z'
started: '2026-09-30T19:37:34Z'
completed: '2026-09-30T20:13:06Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-09-30T19:38:45Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-09-30T20:09:17Z'
    artifact: implementation-plan.md
  - name: test
    completed: '2026-09-30T20:13:06Z'
    artifact: implementation-plan.md
requires_bolts:
  - 068-dark-palette
enables_bolts: []
requires_units: []
blocks: false
complexity:
  avg_complexity: 1
  avg_uncertainty: 1
  max_dependencies: 2
  testing_scope: 2
---

# Bolt: 070-appearance-setting

## Objective

System, Light or Dark in Settings, kept on the phone and applied at once.

## Stories Included

Written in the unit brief (`intents/022-light-and-dark-themes/units/002-appearance-setting/unit-brief.md`), not
as separate files, so `stories:` above is empty.

- [x] **006-appearance-choice**

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [x] **1. Plan**
- [x] **2. Implement**
- [x] **3. Test**

## Expected Outputs

- The appearance preference on the phone
- `themeMode` wired in `MaterialApp`
- The Settings row; tests

## Dependencies

### Requires
- `068-dark-palette`

### Enables
- None
