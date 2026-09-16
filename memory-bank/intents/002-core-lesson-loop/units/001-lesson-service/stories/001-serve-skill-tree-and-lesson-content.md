---
id: 001-serve-skill-tree-and-lesson-content
unit: 001-lesson-service
intent: 002-core-lesson-loop
status: complete
priority: must
created: '2026-09-15T18:00:00Z'
assigned_bolt: 004-lesson-content-service
implemented: true
---

# Story: 001-serve-skill-tree-and-lesson-content

## User Story

**As a** Buna user
**I want** to see my skill tree and fetch a lesson's full content in one request
**So that** I can browse what's unlocked and start a lesson without waiting on multiple round trips

## Acceptance Criteria

- [ ] **Given** a signed-in user, **When** they request their skill tree, **Then** all skills are returned with accurate per-skill state (locked/active/completed) and crown level for that user
- [ ] **Given** a skill with no prior progress for this user, **When** the skill tree is fetched, **Then** it appears `locked` unless it is the first skill (which is `active` by default for every new user)
- [ ] **Given** an active or completed skill node, **When** its lesson content is requested, **Then** the full ordered list of exercises (prompts, choices/word-bank/audio URL as applicable) is returned in a single response
- [ ] **Given** a locked skill's lesson is requested directly, **When** the backend processes it, **Then** the request is rejected (locked skills are not accessible even by direct ID)

## Technical Notes

- This story defines the read-side content model (`skills`, `lessons`, `exercises`) and the `user_skill_progress` read path. Write-side progress updates belong to stories 003/004.
- Answer keys/correct answers should not be exposed in the lesson-content payload if grading is server-side (story 002) — exact payload shape is a Technical Design decision.
- Every skill is `locked` by default except the first, which is `active` for a user with no progress rows yet (bootstraps new users without a separate "initialize progress" step).

## Dependencies

### Requires
- `001-auth-service` (existing) for session validation and `user_id` resolution

### Enables
- 002-answer-exercises-and-manage-beans (needs lesson/exercise content to validate answers against)
- 005-seed-curriculum-content (needs this story's schema to seed into)
- Frontend story 001-skill-tree-dashboard-screen and 002-lesson-exercise-screens

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Brand-new user with zero progress rows | Skill tree still returns correctly — first skill `active`, rest `locked`, computed on the fly rather than requiring pre-seeded progress rows |
| Lesson ID that doesn't exist | Clear 404-style error, not a crash |
| Skill tree requested with an expired/invalid session token | Same auth-failure behavior as existing `001-auth-service` endpoints |

## Out of Scope

- Answer validation (story 002)
- Any UI (owned by `002-core-lesson-loop-ui`)
