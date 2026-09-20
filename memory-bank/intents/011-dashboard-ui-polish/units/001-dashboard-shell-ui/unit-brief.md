---
unit: 001-dashboard-shell-ui
intent: 011-dashboard-ui-polish
phase: inception
status: planned
created: '2026-09-21T02:30:00Z'
updated: '2026-09-21T02:30:00Z'
---

# Unit Brief: Dashboard Shell UI

## Purpose

Make the skill path the dominant element of the dashboard: pin the stats and the course
control to the top, let the page scroll as one smooth surface with the current section's
banner sticking beneath the header, and collapse course selection, adding a course and
course settings into that one control.

## Scope

### In Scope
- One `CustomScrollView` owning the dashboard, with consistent, always-scrollable physics
- A pinned header sliver carrying the course badge and the relocated `LessonHud` stats
- Sync banner and offline note as slivers inside the scroll view
- A pinned category banner per category, replaced by the next as the learner scrolls
- Animated scroll to top when the course changes
- A course badge that expands a horizontal rail of the learner's courses, active one ringed
- A `+ Course` tile opening the rebuilt catalog, grouped by the language the learner speaks
- Course settings and Manage Downloads relocated into the expanded panel
- Updating the affected dashboard, picker, settings and HUD tests

### Out of Scope
- Any backend, API, schema or Flutter model change
- `SkillPathNode` visuals, the serpentine path, Practice card content, lesson screens
- `SettingsScreen`'s own layout; a bottom navigation bar; a profile screen
- Interface localisation; flag artwork or new illustrations

## Assigned Requirements

| FR | Requirement | Priority |
|----|-------------|----------|
| FR-1 | Pinned Dashboard Header | Must |
| FR-2 | One Smooth Scroll Surface | Must |
| FR-3 | Sticky Category Section Banners | Must |
| FR-4 | Course Rail in the Header | Must |
| FR-5 | Add a Course and Course Settings | Must |
| FR-6 | Behaviour Preserved | Must |

## Domain Concepts

| Entity | Description | Attributes |
|--------|-------------|------------|
| Dashboard header | Pinned sliver: course badge + stat pills | collapsed/expanded state |
| Course rail | Horizontal list of the learner's courses plus `+ Course` | derived from `CourseList` |
| Sticky section banner | One per `SkillCategory`, pinned under the header | title, subtitle, completed/total |

No new persisted entity. Everything is derived from the existing `SkillTreeResponse`,
`CourseList` and `BeansStatus`.

## Constraints

- Read the real dashboard, `LessonHud`, `_CategoryBanner`, `course_picker.dart` and the
  six affected test files at Plan time before restructuring.
- Highland Pulse tokens only; a genuinely new token goes in the token file.
- No overflow at 320dp and 360dp with 1.3x text and the longest seeded titles.
- Every new tap target at least 48dp with a button semantic and a meaningful label.
- ADR-14's offline rules keep holding unchanged.
- Existing tests are updated to the new structure, never deleted to make a build pass.

## Bolt Suggestions

| Bolt | Type | Stories | Objective |
|------|------|---------|-----------|
| 028-dashboard-shell | simple-construction-bolt | 001, 002 | Pinned header with stats, one smooth scroll surface, sticky category banners |
| 029-course-switcher-panel | simple-construction-bolt | 003, 004 | Course badge and rail, `+ Course` catalog, relocated settings and downloads, regression pass |
