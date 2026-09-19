---
id: 001-dashboard-grouped-by-category
unit: 002-categories-ui
intent: 009-course-categories
status: complete
priority: must
created: '2026-09-19T19:35:00Z'
assigned_bolt: 023-categories-ui
implemented: true
---

# Story: 001-dashboard-grouped-by-category

## User Story

**As a** Buna learner
**I want** the home dashboard to show each course category with its own skills
**So that** I can see and choose between categories at a glance

## Acceptance Criteria

- [ ] **Given** N categories, **When** the dashboard loads, **Then** N banners render in order, each with title, Amharic subtitle, "x/y Completed" and a progress bar
- [ ] **Given** a category, **Then** its skills render as a path beneath its banner, with the zig-zag offset restarting per category
- [ ] **Given** existing skill behaviors (locked/active/completed, crown, download, tap-to-start), **Then** they are unchanged
- [ ] **Given** a 360dp-wide screen, **Then** nothing overflows
- [ ] **Given** the Flutter model/HTTP/Fake APIs, **Then** they parse and expose categories, with existing tests updated

## Technical Notes

- Read the real `_UnitBanner`, `_lateralOffset`, and node-building code at Plan stage.
- Practice card and HUD stay above the first category.

## Dependencies

### Requires
- `003-skill-tree-api-with-categories`, `004-seed-four-new-categories` (backend unit)

### Enables
- `002-new-category-end-to-end-verification`

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Category with no skills | No crash; banner with 0/0 or omitted |
| Older API response without categories | Falls back gracefully or fails clearly per design decision |

## Out of Scope

- Category picker screen
