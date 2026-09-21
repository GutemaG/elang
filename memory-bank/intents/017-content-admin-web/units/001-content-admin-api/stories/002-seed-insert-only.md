---
id: 002-seed-insert-only
unit: 001-content-admin-api
intent: 017-content-admin-web
status: generated
priority: must
created: '2026-09-22T10:00:00Z'
assigned_bolt: 034-admin-api-foundation
implemented: false
---

# Story: 002-seed-insert-only

## User Story

**As a** Buna admin
**I want** the seed never to overwrite what I edited
**So that** the database stays the one source of truth for content

## Acceptance Criteria

- [ ] **Given** an empty database, **When** the seed runs, **Then** it produces exactly today's content (same ids, counts and order)
- [ ] **Given** an exercise whose `content` was changed after seeding, **When** the seed runs again, **Then** that exercise is unchanged
- [ ] **Given** a seeded row was deleted by an admin, **When** the seed runs again, **Then** it is re-inserted -- documented as expected behaviour, since insert-only cannot tell deleted from never-seeded
- [ ] **Given** the seed has run, **When** it runs a second time, **Then** nothing changes
- [ ] **Given** `seed_lesson_content.py`, `seed_course_content.py` and `seed_local_audio.py`, **When** each is run, **Then** all three are insert-only

## Technical Notes

- All three seeds go through `seed_content`, so the change is in one place.
- Existing tests that relied on a re-seed repairing content must be rewritten to the new rule, not deleted. List each one in the test report.
- The re-insert-after-delete behaviour needs a decision at Plan: accept it (simple, documented), or record deleted seed ids. The default is to accept it and document it in the seed's docstring.

## Dependencies

### Requires
- None

### Enables
- 003-content-tree-and-crud-api
