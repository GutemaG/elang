---
id: 003-skill-tree-api-with-categories
unit: 001-categories-service
intent: 009-course-categories
status: complete
priority: must
created: '2026-09-19T19:35:00Z'
assigned_bolt: 021-categories-service
implemented: true
---

# Story: 003-skill-tree-api-with-categories

## User Story

**As a** Buna client app
**I want** the skill tree grouped by real categories from the backend
**So that** the dashboard can render each category without hardcoded titles

## Acceptance Criteria

- [ ] **Given** several categories, **When** `GET /skill-tree` is called, **Then** every category (id, title, subtitle, order) is returned in order and each skill carries its `category_id`
- [ ] **Given** the response, **Then** existing fields (`state`, `crown_level`, `lesson_id`, `content_version`, HUD stats) are unchanged
- [ ] **Given** the hardcoded `UNIT_TITLE`/`UNIT_SUBTITLE`, **Then** they are removed from the backend
- [ ] **Given** N categories and M skills, **When** the tree is read, **Then** the query count does not grow with N or M (existing performance test still passes)

## Technical Notes

- Prefer an additive response shape; the envelope choice (nested vs flat + categories list) gets an ADR at design time and is verified against the Flutter parser.
- Extend `tests/fakes.py` in-memory repositories for categories.

## Dependencies

### Requires
- `001-category-content-model-and-migration`, `002-per-category-progression`

### Enables
- `001-dashboard-grouped-by-category` (UI unit)

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Category with no skills | Returned with empty skills, or omitted (decided at design; must not crash the client) |

## Out of Scope

- Flutter parsing (UI unit)
