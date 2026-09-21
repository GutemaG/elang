---
id: 006-vocabulary-api
unit: 001-content-admin-api
intent: 017-content-admin-web
status: generated
priority: could
created: '2026-09-22T10:00:00Z'
assigned_bolt: 040-admin-vocabulary
implemented: false
---

# Story: 006-vocabulary-api

## User Story

**As a** Buna admin
**I want** to list and edit a course's vocabulary
**So that** practice uses correct words without a code change

## Acceptance Criteria

- [ ] **Given** a course, **When** `GET /admin/courses/{id}/vocab` is called, **Then** it lists its vocab items
- [ ] **Given** a vocab item with learner SRS progress, **When** its text is edited, **Then** the progress rows are kept and practice still serves it

## Technical Notes

- Deleting vocab items is out of scope for v1.

## Dependencies

### Requires
- 003-content-tree-and-crud-api

### Enables
- 006-vocabulary-screen
