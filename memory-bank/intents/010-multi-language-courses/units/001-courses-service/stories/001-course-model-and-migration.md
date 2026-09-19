---
id: 001-course-model-and-migration
unit: 001-courses-service
intent: 010-multi-language-courses
status: complete
priority: must
created: '2026-09-20T13:00:00Z'
assigned_bolt: 024-courses-service
implemented: true
---

# Story: 001-course-model-and-migration

## User Story

**As a** Buna learner
**I want** courses to be a real concept, each tied to a learning language and a from-language
**So that** the app can offer more than one course without mixing their content

## Acceptance Criteria

- [ ] **Given** the migration runs on a database with users and progress, **When** it finishes, **Then** a course English to Amharic exists and all five categories belong to it, with no skill, lesson, exercise, vocab or progress row lost
- [ ] **Given** the migration, **When** it is downgraded, **Then** the schema returns to the previous state cleanly
- [ ] **Given** a course pair that already exists, **When** another with the same pair is created, **Then** it is rejected
- [ ] **Given** an unknown language code, **When** a course is created, **Then** it is rejected
- [ ] **Given** a course with status `coming_soon` and no categories, **When** it is stored, **Then** no error occurs

## Technical Notes

- Language codes `am`, `om`, `en`. Decide in Technical Design whether vocab items gain `course_id`.
- Non-destructive, reversible migration (NFR-1).

## Dependencies

### Requires
- None

### Enables
- `002-active-course-per-user`, `003-course-list-api`, `004-course-scoped-skill-tree-and-progress`

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Same language as learning and from | Rejected |
| Category with no course after migration | Not possible; column is NOT NULL |

## Out of Scope

- Seeding Afaan Oromo content
