---
id: 066-palette-by-role
unit: 001-theme-palette
intent: 022-light-and-dark-themes
type: simple-construction-bolt
status: complete
stories: []
created: '2026-09-30T13:52:00Z'
started: '2026-09-30T14:29:14Z'
completed: '2026-09-30T15:18:23Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-09-30T15:00:11Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-09-30T15:10:43Z'
    artifact: implementation-plan.md
  - name: test
    completed: '2026-09-30T15:18:22Z'
    artifact: implementation-plan.md
requires_bolts: []
enables_bolts:
  - 067-screens-read-theme
requires_units: []
blocks: false
complexity:
  avg_complexity: 2
  avg_uncertainty: 2
  max_dependencies: 1
  testing_scope: 2
---

# Bolt: 066-palette-by-role

## Objective

Put every colour in one palette file by role (light values unchanged) and build the theme, tones, shadows and text colours from it.

## Stories Included

Written in the unit brief (`intents/022-light-and-dark-themes/units/001-theme-palette/unit-brief.md`), not
as separate files, so `stories:` above is empty.

- [x] **001-palette-by-role**

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [x] **1. Plan**
- [x] **2. Implement**
- [x] **3. Test**

## Expected Outputs

- `AppPalette` with `light`, and a `context.colors` accessor
- `AppTheme`, `AppTone`, `AppShadows` built from a palette
- Tests; light mode unchanged

## Dependencies

### Requires
- None

### Enables
- `067-screens-read-theme`
