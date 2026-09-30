---
id: 067-screens-read-theme
unit: 001-theme-palette
intent: 022-light-and-dark-themes
type: simple-construction-bolt
status: complete
stories: []
created: '2026-09-30T13:52:00Z'
started: '2026-09-30T18:10:17Z'
completed: '2026-09-30T18:54:46Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-09-30T18:14:53Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-09-30T18:39:24Z'
    artifact: implementation-plan.md
  - name: test
    completed: '2026-09-30T18:54:45Z'
    artifact: implementation-plan.md
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

- [x] **002-screens-read-theme**

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [x] **1. Plan**
- [x] **2. Implement**
- [x] **3. Test**

## Expected Outputs

- About 440 colour reads moved in 40 files
- A design rule against direct `AppColors` use
- All existing tests passing unchanged

## Dependencies

### Requires
- `066-palette-by-role`

### Enables
- `068-dark-palette`
