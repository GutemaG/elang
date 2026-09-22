---
id: 003-content-tree-and-crud-api
unit: 001-content-admin-api
intent: 017-content-admin-web
status: complete
priority: must
created: '2026-09-22T10:00:00Z'
assigned_bolt: 035-admin-content-api
implemented: true
---

# Story: 003-content-tree-and-crud-api

## User Story

**As a** Buna admin
**I want** to read the whole course tree and create, edit, reorder and delete its parts over an API
**So that** the admin site can manage content without SQL

## Acceptance Criteria

- [ ] **Given** a course id, **When** `GET /admin/courses/{id}/tree` is called, **Then** it returns sections → skills → lessons → exercises in `order_index` order with child counts and each listening exercise's audio status (`placeholder` / `hosted`)
- [ ] **Given** valid input, **When** a section, skill, lesson or exercise is created, **Then** it gets a uuid4 id, is appended last in its parent, and appears in the learner `/skill-tree` or lesson fetch on the next request
- [ ] **Given** a parent and a full ordered list of its children's ids, **When** `PUT .../order` is called, **Then** the order is applied in one transaction; a list that is missing, duplicates or adds ids is rejected with `422` and nothing changes
- [ ] **Given** the categories `(course_id, order_index)` uniqueness, **When** sections are reordered, **Then** the constraint is never violated mid-transaction
- [ ] **Given** a skill or lesson with rows in `user_skill_progress` or `lesson_attempts`, **When** it is deleted, **Then** it returns `409` with the number of affected learners and nothing is deleted
- [ ] **Given** content with no learner history, **When** it is deleted with `?confirm=true`, **Then** it and its children are deleted; without `confirm` it returns `409` describing what would be deleted
- [ ] **Given** a course, **When** its title is edited, **Then** the change is saved; there is no endpoint to create or delete a course
- [ ] **Given** any admin write, **When** it succeeds, **Then** one structured log line records the admin email, entity, id and action

## Technical Notes

- Use application-layer use cases in `app/application/`, following `course_use_cases.py`; routers stay thin.
- Reorder under a unique constraint: offset all indexes to a temporary range first, then write the final ones, in one transaction. SQLite and Postgres must both pass.
- Deleting an exercise also needs a guard if learner SRS rows reference its vocab item; check at Plan.

## Dependencies

### Requires
- 001-admin-authorization
- 002-seed-insert-only

### Enables
- 004-exercise-write-validation
