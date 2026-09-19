---
id: 005-course-scoped-practice
unit: 001-courses-service
intent: 010-multi-language-courses
status: complete
priority: must
created: '2026-09-20T13:00:00Z'
assigned_bolt: 024-courses-service
implemented: true
---

# Story: 005-course-scoped-practice

## User Story

**As a** Buna learner
**I want** Practice to review only words from my current course
**So that** I do not get Afaan Oromo questions while studying Amharic

## Acceptance Criteria

- [ ] **Given** due words in two courses, **When** the due count and Practice items are requested, **Then** only the active course's words are returned
- [ ] **Given** a Practice answer, **When** it is submitted, **Then** only that word's Leitner box changes
- [ ] **Given** the user switches course, **When** the due count is read again, **Then** it reflects the new course
- [ ] **Given** words due in the other course, **When** the user switches back, **Then** their schedules are unchanged
- [ ] **Given** the due queries, **When** measured, **Then** the query count is constant

## Technical Notes

- Depends on the Technical Design decision that vocab is per course (recommended) or otherwise resolvable to a course.

## Dependencies

### Requires
- `004-course-scoped-skill-tree-and-progress`

### Enables
- UI `004-multi-course-end-to-end-verification`

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| A word tested in two courses | Tracked separately per course |
| No due words in active course | Count 0, "caught up" as today |

## Out of Scope

- Cross-course review sessions
