---
id: 001-category-content-model-and-migration
unit: 001-categories-service
intent: 009-course-categories
status: complete
priority: must
created: '2026-09-19T19:35:00Z'
assigned_bolt: 021-categories-service
implemented: true
---

# Story: 001-category-content-model-and-migration

## User Story

**As a** Buna content maintainer
**I want** skills grouped into named categories in the database
**So that** the app can present multiple course categories instead of one flat list

## Acceptance Criteria

- [ ] **Given** the migration runs on a database with existing skills, **When** it completes, **Then** a "Foundations & Greetings" category (subtitle `ሰላምታ እና ፊደል መግቢያ`) exists and both existing skills belong to it
- [ ] **Given** a database with users, progress, attempts and vocab progress, **When** the migration runs, **Then** none of that data changes
- [ ] **Given** the migration, **When** downgraded, **Then** the schema returns to its prior state without error
- [ ] **Given** any skill row, **When** inserted without a category, **Then** the database rejects it (NOT NULL FK)

## Technical Notes

- Backfill in the migration (add nullable column, backfill, then set NOT NULL) so it works on populated databases (SQLite needs batch mode).
- Decide at design time whether `uq_skills_order_index` stays global or becomes unique per category.

## Dependencies

### Requires
- None

### Enables
- `002-per-category-progression`, `003-skill-tree-api-with-categories`, `004-seed-four-new-categories`

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Empty database (fresh install) | Migration succeeds; category created for later seeding |
| Migration run twice | Alembic prevents re-run; no duplicate category |

## Out of Scope

- Seeding the four new categories (story 004)
