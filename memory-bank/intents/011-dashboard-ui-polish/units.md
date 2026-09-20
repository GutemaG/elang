---
intent: 011-dashboard-ui-polish
phase: inception
created: '2026-09-21T02:25:00Z'
---

# Units: dashboard-ui-polish

## Overview

One unit. The whole intent is Flutter presentation inside one feature area, with no
backend counterpart, so the usual backend/frontend split does not apply. The work divides
into two bolts along a real seam: the **scroll shell** (what is pinned, what scrolls, how
it scrolls) can be built and tested without touching course selection, and the **course
control** then drops into the header the first bolt produced.

## Units

### 001-dashboard-shell-ui (frontend)

**Purpose**: Rebuild the dashboard as one scroll surface with a pinned stats header and
sticky category banners, then replace the course chip with a badge that expands a course
rail carrying add-a-course, course settings and Manage Downloads.
**Assigned Requirements**: FR-1, FR-2, FR-3, FR-4, FR-5, FR-6
**Complexity**: Moderate. No new data flow, but it restructures the most-tested screen in
the app, so the risk is concentrated in keeping existing dashboard, offline and picker
tests meaningful rather than in new logic.
**Depends on**: `010-multi-language-courses` (complete)
**Bolts**: `028-dashboard-shell` (simple-construction-bolt: pinned header, one scroll
surface, sticky banners), `029-course-switcher-panel` (simple-construction-bolt: rail,
catalog, relocated settings and downloads, regression pass)

## Dependency Graph

```text
028-dashboard-shell --> 029-course-switcher-panel
```

The header sliver that bolt 028 builds is where bolt 029's badge and rail live, so 029
cannot start until 028's shell exists. Nothing else in the repo depends on either.

## Notes

- Bolt 028 deliberately leaves the existing `_CourseChip` and the two icon buttons in
  place (inside the new header) so the shell can land with the course flow untouched and
  every existing test still asserting something real. Bolt 029 replaces them.
- Four of the intent's open questions are Technical Design decisions for bolt 028
  (sticky banner mechanism, panel as overlay vs sliver) and bolt 029 (deriving "my
  courses", badge artwork). Expect at least one ADR from 029.
