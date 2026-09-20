---
id: 001-pinned-header-with-stats
unit: 001-dashboard-shell-ui
intent: 011-dashboard-ui-polish
status: complete
priority: must
created: '2026-09-21T02:35:00Z'
assigned_bolt: 028-dashboard-shell
implemented: true
---

# Story: 001-pinned-header-with-stats

## User Story

**As a** Buna learner
**I want** my streak, beans, XP and Amole to stay at the top of the screen while I scroll
**So that** I always see what I have earned without scrolling back up

## Acceptance Criteria

- [ ] **Given** the dashboard has loaded, **When** it first paints, **Then** one compact header row shows the course control on the left and the streak, beans, XP and Amole pills on the right
- [ ] **Given** the learner scrolls to the bottom of the longest course, **When** they stop, **Then** the header is still fully visible
- [ ] **Given** content scrolls behind the header, **When** it passes under, **Then** the header has its own surface and a bottom edge so nothing shows through
- [ ] **Given** `LessonHud` was the first item in the scroll body, **When** the refactor lands, **Then** the stats are no longer in the scroll body and appear exactly once on screen
- [ ] **Given** 320dp and 360dp widths at 1.3x text with the longest seeded course name, **When** rendered, **Then** nothing overflows
- [ ] **Given** a screen reader, **When** it reaches a stat pill, **Then** the existing semantic labels ("N of M beans remaining", "N total XP", "N Amole") still read

## Technical Notes

- `LessonHud` already wraps itself in `FittedBox`/`LayoutBuilder` to survive narrow
  screens; keep that behaviour rather than re-solving it in the header.
- The existing `lesson_hud_narrow_test` must keep testing the widget directly; the
  dashboard tests are what change.
- Bolt 028 keeps `_CourseChip` and the Downloads/Settings icon buttons in the header
  unchanged; story 003 replaces them.

## Dependencies

### Requires
- Nothing outside the repo; intent 010 is complete

### Enables
- `003-course-rail-and-add-course` (the rail lives in this header)

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Offline, dashboard from cache | Header renders with the cached stats; the offline note appears below it |
| Error state with Retry | Header is not shown; the error state owns the screen as today |
| Loading | Header is not shown; the spinner owns the screen as today |
| Course with no title from the backend | Course control reads "Courses" as today |

## Out of Scope

- Changing what the stats mean, their values or their icons
- Any change to the course control's behaviour
