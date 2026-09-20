---
unit: 001-dashboard-shell-ui
intent: 011-dashboard-ui-polish
created: '2026-09-21T03:05:00Z'
last_updated: '2026-09-21T07:10:00Z'
---

# Construction Log: dashboard-shell-ui

## Original Plan

**From Inception**: 2 bolts planned
**Planned Date**: 2026-09-21

| Bolt ID | Stories | Type |
|---------|---------|------|
| 028-dashboard-shell | 001, 002 | simple-construction-bolt |
| 029-course-switcher-panel | 003, 004 | simple-construction-bolt |

## Replanning History

| Date | Action | Change | Reason | Approved |
|------|--------|--------|--------|----------|

## Current Bolt Structure

| Bolt ID | Stories | Status | Changed |
|---------|---------|--------|---------|
| 028-dashboard-shell | 001-002 | ✅ complete | 2026-09-21 |
| 029-course-switcher-panel | 003-004 | ✅ complete | 2026-09-21 |

## Execution History

| Date | Bolt | Event | Details |
|------|------|-------|---------|
| 2026-09-21T03:05:00Z | 028-dashboard-shell | started | Stage 1: Plan |
| 2026-09-21T03:30:00Z | 028-dashboard-shell | stage-complete | plan → implement |
| 2026-09-21T04:10:00Z | 028-dashboard-shell | stage-complete | implement → test |
| 2026-09-21T04:50:00Z | 028-dashboard-shell | bolt-complete | Stories 001, 002 complete; 284 Flutter tests pass |
| 2026-09-21T05:35:00Z | 029-course-switcher-panel | started | Stage 1: Plan |
| 2026-09-21T05:50:00Z | 029-course-switcher-panel | stage-complete | plan → implement (ADR-15) |
| 2026-09-21T06:30:00Z | 029-course-switcher-panel | stage-complete | implement → test |
| 2026-09-21T07:10:00Z | 029-course-switcher-panel | bolt-complete | Stories 003, 004 complete; unit and intent complete; 314 Flutter tests pass |

## Notes

- Bolt 028 found two things the plan had asserted without checking: pinned slivers
  accumulate at the top rather than displacing each other (fixed with
  `SliverMainAxisGroup` per category), and the scroll position did not survive a reload
  because the `FutureBuilder`'s waiting branch replaced the scroll view (fixed by
  re-rendering the last loaded dashboard while a reload is in flight).
- Bolt 029 inherits one open decision: `GET /courses` returns every course, so how the
  rail derives "my courses" is undecided and expected to produce an ADR. What the course
  badge displays belongs with it, since no flag artwork ships.
- `_HeaderLeading` in the dashboard screen is the slot bolt 029 replaced wholesale.
- Bolt 029 resolved that open decision as ADR-15: the rail is the courses with a cached
  dashboard, plus the active one, plus anything with progress. It reuses ADR-14's store,
  so clearing cached dashboards now also empties the rail.
- Three defects this unit found only because a test was finally written for them, all of
  the same shape: a widget that looks right but is wrong to a screen reader or to a hit
  test. `Semantics(label:)` without `container`/`excludeSemantics` needed fixing three
  times, in the stat pills, the course tiles and the catalog's progress bar.
