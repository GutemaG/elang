---
id: 002-new-category-end-to-end-verification
unit: 002-categories-ui
intent: 009-course-categories
status: complete
priority: must
created: '2026-09-19T19:35:00Z'
assigned_bolt: 023-categories-ui
implemented: true
---

# Story: 002-new-category-end-to-end-verification

## User Story

**As a** Buna learner
**I want** lessons in new categories to work exactly like the original ones
**So that** every category is a fully functioning course

## Acceptance Criteria

- [ ] **Given** a new-category lesson, **When** completed, **Then** XP, Amole and streak are awarded and vocab progress rows are created
- [ ] **Given** a new-category lesson, **When** downloaded, **Then** it can be taken offline
- [ ] **Given** newly learned vocab, **When** due, **Then** it appears in Practice
- [ ] **Given** completing the first skill in a new category, **Then** the second skill of that category (only) unlocks
- [ ] **Given** the full backend and Flutter suites, **Then** they pass

## Technical Notes

- Mostly verification: backend integration test across a new category, Flutter widget tests with a multi-category fake tree, plus a manual on-device check against the migrated dev database.

## Dependencies

### Requires
- `001-dashboard-grouped-by-category`

### Enables
- None

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| User completes lessons in two categories same day | Streak increments once, as today |

## Out of Scope

- New features; this story only verifies
