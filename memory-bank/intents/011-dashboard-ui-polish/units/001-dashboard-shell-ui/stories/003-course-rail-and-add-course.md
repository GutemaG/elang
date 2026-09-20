---
id: 003-course-rail-and-add-course
unit: 001-dashboard-shell-ui
intent: 011-dashboard-ui-polish
status: generated
priority: must
created: '2026-09-21T02:45:00Z'
assigned_bolt: 029-course-switcher-panel
implemented: false
---

# Story: 003-course-rail-and-add-course

## User Story

**As a** Buna learner
**I want** to tap my course badge and see my courses side by side, with a clear way to
add another
**So that** switching between the languages I study takes one tap and starting a new one
is obvious

## Acceptance Criteria

- [ ] **Given** the pinned header, **When** the course badge is tapped, **Then** a panel expands directly beneath it holding a horizontal rail of the learner's courses and a trailing `+ Course` tile
- [ ] **Given** the rail, **When** it renders, **Then** its courses come from the course API and exactly one tile — the active course — is visibly ringed
- [ ] **Given** a different course in the rail, **When** it is tapped, **Then** the switch is made, the panel collapses, and the dashboard shows that course's tree, Practice count and banners
- [ ] **Given** the active course in the rail, **When** it is tapped, **Then** the panel collapses and nothing else changes
- [ ] **Given** the panel is open, **When** the badge is tapped again or the learner taps outside it, **Then** it collapses
- [ ] **Given** the panel opens or closes, **When** it does, **Then** the change is animated rather than instant
- [ ] **Given** more courses than fit the width, **When** the rail renders, **Then** it scrolls horizontally and no tile is clipped
- [ ] **Given** the `+ Course` tile, **When** it is tapped, **Then** the catalog opens showing every course grouped by the language the learner speaks, with coming-soon courses disabled
- [ ] **Given** an available course in the catalog, **When** it is chosen, **Then** the switch is made and the dashboard shows that course
- [ ] **Given** a switch that fails, **When** the error returns, **Then** the current course stays active and a message is shown
- [ ] **Given** the learner is offline and chooses a course never opened before, **When** it is refused, **Then** the existing "Connect to the internet…" message is shown and the current course stays active
- [ ] **Given** every tile and row in the panel, **When** measured, **Then** each is at least 48dp in both directions and exposes a button semantic with a meaningful label
- [ ] **Given** 320dp and 360dp at 1.3x text with the longest seeded titles, **When** the panel is open, **Then** nothing overflows

## Technical Notes

- `GET /courses` returns **every** course, not "courses I have joined". How the rail
  derives "my courses" — active plus any with progress, a locally remembered list in
  `CourseCacheStore`, or every available course — is a Technical Design decision for this
  bolt and is expected to produce an ADR.
- No flag artwork ships today; what the badge and tiles show (language code, initial,
  or something else) is part of the same design decision.
- `pickAndSwitchCourse` keeps its current contract so `SettingsScreen` needs no change;
  the catalog sheet's internals are what get rebuilt.
- ADR-14 is untouched: switching still goes through `CachingCourseApi`, so the offline
  rules, the pending switch and the `offline_not_cached` message all keep working.

## Dependencies

### Requires
- `001-pinned-header-with-stats` (the header the panel hangs from)

### Enables
- `004-course-settings-and-downloads-access` (shares the panel)

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Exactly one course available | Rail shows it ringed, plus `+ Course`; the catalog shows the rest as coming soon |
| Course list fails to load | Badge still shows the active course from the skill tree; the panel shows a retry |
| Offline with a cached list | Rail renders from the cached list with the local active course marked |
| Active course later becomes coming-soon | Out of scope here; the existing intent 010 follow-up still stands |
| Panel open when a lesson is opened | Panel is collapsed on return; the dashboard reloads as today |

## Out of Scope

- Removing a course from the rail, reordering it, or any "leave course" action
- Per-course stats in the rail beyond what the API already returns
- A waitlist for coming-soon courses
