---
id: 070-appearance-setting
unit: 002-appearance-setting
intent: 022-light-and-dark-themes
type: simple-construction-bolt
status: planned
stories: []
created: '2026-09-30T13:52:00Z'
started: null
completed: null
current_stage: null
stages_completed: []
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

- [ ] **006-appearance-choice**

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [ ] **1. Plan**
- [ ] **2. Implement**
- [ ] **3. Test**

## Expected Outputs

- The appearance preference on the phone
- `themeMode` wired in `MaterialApp`
- The Settings row; tests

## Dependencies

### Requires
- `068-dark-palette`

### Enables
- None
