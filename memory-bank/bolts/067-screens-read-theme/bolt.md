---
id: 067-screens-read-theme
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
  - 066-palette-by-role
enables_bolts:
  - 068-dark-palette
requires_units: []
blocks: false
complexity:
  avg_complexity: 2
  avg_uncertainty: 1
  max_dependencies: 1
  testing_scope: 2
---

# Bolt: 067-screens-read-theme

## Objective

Move every screen and shared widget from `AppColors` to the theme's palette, and add the design rule that keeps it so.

## Stories Included

Written in the unit brief (`intents/022-light-and-dark-themes/units/001-theme-palette/unit-brief.md`), not
as separate files, so `stories:` above is empty.

- [ ] **002-screens-read-theme**

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [ ] **1. Plan**
- [ ] **2. Implement**
- [ ] **3. Test**

## Expected Outputs

- About 440 colour reads moved in 40 files
- A design rule against direct `AppColors` use
- All existing tests passing unchanged

## Dependencies

### Requires
- `066-palette-by-role`

### Enables
- `068-dark-palette`
