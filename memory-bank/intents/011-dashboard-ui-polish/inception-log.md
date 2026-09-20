---
intent: 011-dashboard-ui-polish
created: '2026-09-21T02:00:00Z'
status: complete
completed: '2026-09-21T03:00:00Z'
---

# Inception Log: dashboard-ui-polish

## Overview

**Intent**: Rework the dashboard shell so the course content is the focus: stats pinned
in a header, one smooth scroll surface with sticky category banners, and course
selection, adding a course and course settings collapsed into one header control.
**Type**: UI refactor (Flutter only; no backend, API, schema or model change)
**Created**: 2026-09-21

## Progress

| Artifact | Status |
|----------|--------|
| Requirements | Approved at Checkpoint 2 (2026-09-21) |
| System Context | Generated |
| Units (1) | Generated |
| Stories (4) | Generated |
| Bolt Plan (2) | Generated: 028, 029 |

Checkpoint 3 (artifacts review) approved 2026-09-21. Checkpoint 4 approved: ready for
Construction. Bolts 028 and 029 created; bolt 028 started.

## Summary

- **Functional Requirements**: 6
- **Non-Functional Requirements**: 5
- **Units**: 1
- **Stories**: 4
- **Bolts Planned**: 2

## Next Steps

`/specsmd-construction-agent --unit="001-dashboard-shell-ui" --bolt-id="028-dashboard-shell"`

## Decision Log

| Date | Decision | Rationale | Approved |
|------|----------|-----------|----------|
| 2026-09-21 | Track the UI polish as its own intent with bolts, not a direct commit | User's choice; keeps the memory-bank consistent with intents 009/010 | Yes |
| 2026-09-21 | Course switcher is a header dropdown rail, not a polished bottom sheet | User's choice; closest to the supplied Duolingo screenshots | Yes |
| 2026-09-21 | "Fixed header" means moving `LessonHud` into the already-fixed top row | Verified in source: the top bar is a fixed `Column`; it is the stats that scroll away | Yes |
| 2026-09-21 | Manage Downloads and Settings leave the top bar for the course panel | The intent is to reduce chrome above the content; there is no bottom nav to move them to | Yes |
| 2026-09-21 | One unit, split into a shell bolt and a course-control bolt | The shell can be built and tested without touching course selection; the rail then drops into the header it produces | Yes |
| 2026-09-21 | No backend change in this intent | Everything needed is already returned by `GET /courses` and `GET /skill-tree` | Yes |

## Scope Changes

| Date | Change | Decision |
|------|--------|----------|
| 2026-09-21 | A UX review proposed a bottom navigation bar, which would make story 004's "Settings and Manage Downloads move into the course panel" wrong | Deferred. Story 004 stands as written and bolt 029 builds it. A later intent adds the bottom nav and moves both entries to a profile tab, accepting that this code is touched twice. |
| 2026-09-21 | The same review raised settings grouping, tappable stat pills and richer path nodes | Out of this intent. Opened as intents 012, 013 and 014 rather than growing 011. |
| 2026-09-21 | The review also proposed custom Ethiopian illustrations, mascots and a Fidel section | Declined for now; not opened as an intent. Recorded in 014's out-of-scope. |
| 2026-09-21 | The review reported the course pill truncating to "Amh…" | Not a scope change: it is a consequence of bolt 028 keeping two icon buttons in the header. Bolt 029 removes them and returns roughly 96dp to the chip. |
