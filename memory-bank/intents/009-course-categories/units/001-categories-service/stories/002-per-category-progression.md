---
id: 002-per-category-progression
unit: 001-categories-service
intent: 009-course-categories
status: complete
priority: must
created: '2026-09-19T19:35:00Z'
assigned_bolt: 021-categories-service
implemented: true
---

# Story: 002-per-category-progression

## User Story

**As a** Buna learner
**I want** to start any category and progress through it in order
**So that** I can choose what to study without finishing everything else first

## Acceptance Criteria

- [ ] **Given** a brand-new user, **When** the skill tree is read, **Then** exactly the first skill of each category is active and every other skill is locked
- [ ] **Given** a user completes skill N of a category, **When** completion is processed, **Then** skill N+1 of the same category unlocks and no other category changes
- [ ] **Given** a user completes the last skill of a category, **When** completion is processed, **Then** nothing further unlocks and no error occurs
- [ ] **Given** a locked skill in any category, **When** its lesson is requested by id, **Then** the request is rejected (403)
- [ ] **Given** an existing user with Greetings completed, **When** the tree is read after migration, **Then** their states and crown levels are unchanged

## Technical Notes

- One shared definition of "next skill in category" used by `SkillTreeProgressionPolicy`, `state_for_skill`, and `LessonCompletionService` so they cannot disagree.
- Pure domain logic with unit tests; no I/O.

## Dependencies

### Requires
- `001-category-content-model-and-migration`

### Enables
- `003-skill-tree-api-with-categories`

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Category with a single skill | That skill is active for new users; completing it unlocks nothing |
| Category with zero skills | Ignored; no error |
| User already has a progress row for a category's first skill | Row wins over the on-the-fly bootstrap, as today |

## Out of Scope

- Cross-category prerequisites
