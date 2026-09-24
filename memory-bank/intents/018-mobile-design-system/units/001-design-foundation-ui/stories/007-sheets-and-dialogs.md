---
id: 007-sheets-and-dialogs
unit: 001-design-foundation-ui
intent: 018-mobile-design-system
status: draft
priority: must
created: '2026-09-24T12:55:00Z'
assigned_bolt: 043-design-surfaces
implemented: false
---

# Story: 007-sheets-and-dialogs

## User Story

**As a** Buna learner
**I want** every pop-up sheet and confirmation to look like part of the same family
**So that** a sheet never feels like a stock system dialog

## Acceptance Criteria

- [ ] **Given** `showAppSheet`, **When** opened, **Then** it has a 32 px top radius, cream background, drag handle, the warm backdrop (`rgba(43,33,24,.45)`) and `AppShadows.overlay`
- [ ] **Given** `showAppDialog`, **When** opened, **Then** it uses the same surface, radius, backdrop and `SheetHero` layout, with a destructive primary where the action deletes something
- [ ] **Given** `SheetHero`, **When** filled, **Then** it shows an illustration circle with a soft glow and optional badge (e.g. "0/5"), a toned title, an optional second-language line, body text, and an action stack of primary, secondary and text link, in the mockup's spacing
- [ ] **Given** a sheet taller than the screen at 1.3× text, **When** shown, **Then** it scrolls and its actions stay reachable
- [ ] **Given** both functions, **When** closed, **Then** they return the chosen value exactly as the `showModalBottomSheet` / `showDialog` calls they replace do

## Reference Design (FR-11)

- `stich-screens/extracted/stitch_ethiopian_language_learning_app/out_of_beans_refill_modal`
- `stich-screens/extracted/stitch_ethiopian_language_learning_app/level_up_streak_freeze_modal`
- Dialogs and the settings sheet: fetched references (e.g. Duolingo's confirm sheets, Material 3 bottom sheets) in Plan

## Technical Notes

- `SheetHero` takes an `illustration` widget so today's icons work now and mascot art can drop in later.

## Dependencies

### Requires
- 003-buttons
- 006-cards-and-surfaces

### Enables
- 003-screen-migration-ui stories 002-004
- 002-question-kit-ui story 004 (exit sheet)

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Back gesture on a sheet | Closes it with a null result, as today |

## Out of Scope

- New mascot artwork
