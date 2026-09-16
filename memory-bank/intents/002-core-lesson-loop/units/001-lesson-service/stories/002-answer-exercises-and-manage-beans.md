---
id: 002-answer-exercises-and-manage-beans
unit: 001-lesson-service
intent: 002-core-lesson-loop
status: complete
priority: must
created: '2026-09-15T18:00:00Z'
assigned_bolt: 005-lesson-engagement-service
implemented: true
---

# Story: 002-answer-exercises-and-manage-beans

## User Story

**As a** Buna user
**I want** my exercise answers graded and my mistakes to cost a bean, with beans regenerating over time
**So that** mistakes have a real but non-punishing cost

## Acceptance Criteria

- [ ] **Given** a submitted answer to any of the 3 exercise types, **When** the backend grades it, **Then** it returns correct/incorrect and, on incorrect, decrements the user's bean count by exactly 1
- [ ] **Given** a user with 0 beans, **When** they attempt to start or continue a lesson, **Then** the request is rejected with a clear "out of beans" error (not a generic failure) and no further answer is accepted until beans are available
- [ ] **Given** time has passed since a bean was consumed, **When** the user's bean count is queried, **Then** beans regenerate at the configured rate (computed from `last_regen_at`, not a scheduled background job) up to the maximum
- [ ] **Given** a user requests an immediate refill, **When** they have sufficient refill currency, **Then** beans are restored to the maximum and the currency is deducted
- [ ] **Given** a correct answer, **When** it's graded, **Then** no bean is consumed

## Technical Notes

- Bean regeneration is computed lazily from `last_regen_at` on read/write, not via Celery/Redis — keeps this story self-contained without new infrastructure. Exact rate/max are Technical Design constants (see requirements.md Open Questions).
- The "minimal currency" for immediate refill is introduced only for this purpose — no purchase/IAP flow, no store UI. A simple integer balance is sufficient; how a user acquires it (e.g. earned via lesson completion) is a Technical Design decision.
- Depends on story 001's lesson/exercise content existing to grade against.

## Dependencies

### Requires
- 001-serve-skill-tree-and-lesson-content (exercises to grade against)

### Enables
- 003-complete-lesson-award-xp-and-progress (a completed lesson attempt requires beans not having hit 0)
- Frontend story 002-lesson-exercise-screens and 003-out-of-beans-and-refill-modal

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| User submits an answer to an exercise not in their current lesson attempt | Rejected — prevents answer submission outside a legitimate lesson attempt |
| Beans exactly at 0 when the last wrong answer is submitted | That submission is still graded (it caused the 0), but the *next* action is blocked |
| Clock skew / regen computed with a future `last_regen_at` | Regen never goes negative; treat as 0 additional beans rather than erroring |

## Out of Scope

- XP award / lesson completion (story 003)
- Any UI (owned by `002-core-lesson-loop-ui`)
- Full gem economy / IAP (explicitly out of scope per requirements.md)
