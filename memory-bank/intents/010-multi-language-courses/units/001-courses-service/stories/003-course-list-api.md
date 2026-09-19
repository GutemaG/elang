---
id: 003-course-list-api
unit: 001-courses-service
intent: 010-multi-language-courses
status: complete
priority: must
created: '2026-09-20T13:00:00Z'
assigned_bolt: 024-courses-service
implemented: true
---

# Story: 003-course-list-api

## User Story

**As a** Buna learner
**I want** to see every course, including ones coming soon
**So that** I can pick the language I want to learn from the language I speak

## Acceptance Criteria

- [ ] **Given** an authenticated user, **When** the course list is requested, **Then** every course is returned in stable order with learning language, from-language, title and status
- [ ] **Given** the list, **When** it is read, **Then** exactly one course is marked active for the user
- [ ] **Given** coming-soon courses exist, **When** the list is read, **Then** they are included and marked
- [ ] **Given** N courses, **When** the list is read, **Then** the query count does not grow with N
- [ ] **Given** an unauthenticated request, **When** the list is requested, **Then** it is rejected

## Technical Notes

- Optional progress summary per course (completed skills / total skills), computed without per-course queries.

## Dependencies

### Requires
- `001-course-model-and-migration`, `002-active-course-per-user`

### Enables
- UI `001-course-switcher-and-settings-picker`

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Course with no categories | Listed with 0/0 progress |
| No available course | Not possible after migration (English to Amharic) |

## Out of Scope

- Filtering by from-language (client groups the list)
