---
id: 068-dark-palette
unit: 001-theme-palette
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
  - 067-screens-read-theme
enables_bolts:
  - 069-theme-gallery-preview
  - 070-appearance-setting
requires_units: []
blocks: false
complexity:
  avg_complexity: 2
  avg_uncertainty: 3
  max_dependencies: 1
  testing_scope: 2
---

# Bolt: 068-dark-palette

## Objective

Add the warm dark palette and `AppTheme.dark`, the picture card, system bars and launch screen, and the contrast test.

## Stories Included

Written in the unit brief (`intents/022-light-and-dark-themes/units/001-theme-palette/unit-brief.md`), not
as separate files, so `stories:` above is empty.

- [ ] **003-dark-palette**
- [ ] **004-contrast-guard**

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [ ] **1. Plan**
- [ ] **2. Implement**
- [ ] **3. Test**

## Expected Outputs

- The dark palette and `AppTheme.dark`
- The contrast test for both palettes
- The screen sweep in dark

## Dependencies

### Requires
- `067-screens-read-theme`

### Enables
- `069-theme-gallery-preview`
- `070-appearance-setting`
