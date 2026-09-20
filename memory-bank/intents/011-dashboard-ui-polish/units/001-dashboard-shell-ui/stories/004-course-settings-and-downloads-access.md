---
id: 004-course-settings-and-downloads-access
unit: 001-dashboard-shell-ui
intent: 011-dashboard-ui-polish
status: complete
priority: must
created: '2026-09-21T02:50:00Z'
assigned_bolt: 029-course-switcher-panel
implemented: true
---

# Story: 004-course-settings-and-downloads-access

## User Story

**As a** Buna learner
**I want** course settings and my downloads to live with the course they belong to,
instead of as icons competing with my lessons
**So that** the top of the screen is about my course and I still reach both in two taps

## Acceptance Criteria

- [ ] **Given** the two icon buttons that were in the dashboard top bar, **When** the refactor lands, **Then** they are gone from the top bar and the header carries only the course badge and the stats
- [ ] **Given** the expanded course panel, **When** it renders, **Then** it offers a course settings entry and a Manage Downloads entry beneath the rail
- [ ] **Given** the course settings entry, **When** it is tapped, **Then** the existing `SettingsScreen` opens, built with the same dependencies as before
- [ ] **Given** the Manage Downloads entry, **When** it is tapped, **Then** the existing `DownloadManagementScreen` opens and still lists each pack under its course
- [ ] **Given** either entry, **When** counted from the dashboard at rest, **Then** it is reachable in two taps
- [ ] **Given** the Settings screen's own Course row, **When** it is used, **Then** it opens the same catalog and still switches course
- [ ] **Given** the whole Flutter suite, **When** it runs, **Then** it passes, with the dashboard, picker, settings and HUD tests updated to the new structure rather than deleted
- [ ] **Given** `flutter analyze`, **When** it runs, **Then** it reports no new errors or warnings
- [ ] **Given** the backend, **When** this intent is complete, **Then** no backend, API, schema or Flutter model file has changed

## Technical Notes

- This story is where the intent's regression obligation (FR-6) is proved: skill node
  taps, locked nodes, per-node download affordances, the Practice card's offline and
  nothing-due states, the sync banner, the offline saved-progress note, the error state
  with Retry, and reload-on-return from a lesson all still behave as before.
- The manual on-device pass belongs here too: the shell and the panel need to be seen on
  a real device at a real scroll velocity, which no widget test covers.
- Entry labels should read as course-scoped ("Course settings") even though
  `SettingsScreen` is account-wide today; renaming or splitting that screen is out of
  scope.

## Dependencies

### Requires
- `003-course-rail-and-add-course` (the panel that hosts both entries)

### Enables
- Nothing; this closes the intent

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Offline | Both entries still open their screens; Manage Downloads works offline as today |
| Dashboard in its error state | Panel is unreachable, as the header is not shown; Retry is the only action, as today |
| Returning from Settings after a course switch there | Dashboard reloads and shows the newly active course |

## Out of Scope

- Redesigning `SettingsScreen` or `DownloadManagementScreen`
- Splitting account settings from course settings
- Adding a profile screen or bottom navigation
