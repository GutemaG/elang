---
id: 004-course-scoped-skill-tree-and-progress
unit: 001-courses-service
intent: 010-multi-language-courses
status: complete
priority: must
created: '2026-09-20T13:00:00Z'
assigned_bolt: 024-courses-service
implemented: true
---

# Story: 004-course-scoped-skill-tree-and-progress

## User Story

**As a** Buna learner
**I want** each course to keep its own skills, crowns and unlocks
**So that** switching courses never mixes or loses what I have done

## Acceptance Criteria

- [ ] **Given** an active course, **When** the skill tree is read, **Then** only that course's categories and skills are returned
- [ ] **Given** a user new to a course, **When** its tree is read, **Then** the first skill of each category is active and the rest locked
- [ ] **Given** progress in course A, **When** the user switches to B and back, **Then** states and crown levels in A are exactly as before
- [ ] **Given** a lesson completed in course A, **When** course B is read, **Then** B is unchanged
- [ ] **Given** XP, streak, Beans and Amole, **When** the user switches course, **Then** they are unchanged
- [ ] **Given** a locked skill, **When** its lesson is requested by id, **Then** 403; **Given** a lesson of a `coming_soon` course, **Then** it is not startable
- [ ] **Given** the skill-tree read, **When** measured, **Then** the query count is constant and existing response fields are unchanged

## Technical Notes

- One shared course-scoping rule for the tree read, `LessonAccessPolicy` and completion-unlock.
- Decide in Technical Design whether completing a lesson of a non-active course is allowed (needed for the queued offline case).

## Dependencies

### Requires
- `001-course-model-and-migration`, `002-active-course-per-user`

### Enables
- `005-course-scoped-practice`, UI stories

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Queued completion for a non-active course | Recorded against its own course (per the design decision) |
| Course with an empty category | 0/0, no error |

## Out of Scope

- Per-course XP, streak or Amole
