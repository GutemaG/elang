---
id: 003-complete-lesson-award-xp-and-progress
unit: 001-lesson-service
intent: 002-core-lesson-loop
status: complete
priority: must
created: '2026-09-15T18:00:00Z'
assigned_bolt: 005-lesson-engagement-service
implemented: true
---

# Story: 003-complete-lesson-award-xp-and-progress

## User Story

**As a** Buna user
**I want** to be awarded XP and see my skill progress update when I finish a lesson
**So that** my effort counts toward my daily goal and unlocks new content

## Acceptance Criteria

- [ ] **Given** a lesson attempt that didn't run out of beans, **When** the user completes the final exercise, **Then** XP is awarded exactly once for that attempt, added to today's running total against `users.daily_xp_target`
- [ ] **Given** a lesson-attempt completion is retried or re-submitted (e.g. duplicate request, client retry after a network blip), **When** the backend processes it, **Then** XP is not awarded a second time for the same attempt
- [ ] **Given** a user completes every lesson in a skill for the first time, **When** the last one completes, **Then** the next skill node's `locked` state becomes `active`
- [ ] **Given** a user replays all lessons in an already-completed skill, **When** they finish the replay, **Then** that skill's crown level increases by 1, capped at 5
- [ ] **Given** a lesson attempt that was interrupted by running out of beans, **When** completion is attempted, **Then** it is rejected — an interrupted attempt cannot be completed

## Technical Notes

- Idempotency on `lesson_attempt_id` is the mechanism for the "exactly once" requirement — completing an already-completed attempt is a no-op that returns the original result, not an error and not a re-award.
- Crown-level increment logic (FR-6) is `Should` priority — if Technical Design finds it adds significant complexity beyond the `Must` items, it can be scoped down to "unlock next skill only" with crown levels deferred, per requirements.md's priority definitions.
- Skill unlock and crown-level updates happen in the same transaction as the XP award, to avoid partial-completion states.

## Dependencies

### Requires
- 002-answer-exercises-and-manage-beans (a lesson attempt must not be beans-interrupted to be completable)

### Enables
- 004-daily-streak-and-freeze (streak update is triggered by lesson completion)
- Frontend story 004-lesson-complete-streak-and-levelup-modals

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Two completion requests for the same attempt arrive concurrently | Only one XP award happens; both requests get the same (correct) result |
| User's `daily_xp_target` changes after some XP was already earned today | Today's running total is unaffected retroactively; only future awards compare against the new target |
| Last skill in the curriculum is completed (no "next skill" to unlock) | Completion still succeeds; there's simply no unlock to perform |

## Out of Scope

- Streak update itself (story 004, though triggered by this story's completion event)
- Any UI (owned by `002-core-lesson-loop-ui`)
