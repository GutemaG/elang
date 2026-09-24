---
id: 004-settings-and-downloads-on-the-library
unit: 003-screen-migration-ui
intent: 018-mobile-design-system
status: draft
priority: must
created: '2026-09-24T12:55:00Z'
assigned_bolt: 049-settings-downloads-and-sweep
implemented: false
---

# Story: 004-settings-and-downloads-on-the-library

## User Story

**As a** Buna learner
**I want** settings and downloads to look like the rest of the app instead of stock system screens
**So that** every screen, even the utility ones, feels like Buna

## Acceptance Criteria

- [ ] **Given** settings, **When** shown, **Then** it uses `AppPage` with a top bar, `SectionHeader`s and `ListRow`s in `AppCard`s; switches and values keep their behaviour
- [ ] **Given** the daily-goal sheet and the sign-out and delete confirmations, **When** opened, **Then** they use `showAppSheet` / `showAppDialog`, with a destructive primary for deleting
- [ ] **Given** download management, **When** shown, **Then** each pack is a `ListRow` in an `AppCard`, the empty list is an `EmptyState` and removal asks through `showAppDialog`
- [ ] **Given** the settings and downloads tests, **When** run, **Then** all pass, changed only for replaced types (e.g. `SwitchListTile` and `TextButton` finders)

## Reference Design (FR-11)

- No mockups; fetched references in Plan (e.g. Duolingo settings, Material 3 settings lists)

## Technical Notes

- The debug gallery's entry point can live on this screen in debug builds (story 004 of unit 001).

## Dependencies

### Requires
- 001-design-foundation-ui

### Enables
- 005-consistency-sweep

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Signed-out state | Unchanged behaviour, shared styling |

## Out of Scope

- New settings
