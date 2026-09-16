---
id: 004-daily-streak-and-freeze
unit: 001-lesson-service
intent: 002-core-lesson-loop
status: complete
priority: should
created: '2026-09-15T18:00:00Z'
assigned_bolt: 005-lesson-engagement-service
implemented: true
---

# Story: 004-daily-streak-and-freeze

## User Story

**As a** Buna user
**I want** my daily streak to update when I complete a lesson, and to be protected once by a streak freeze if I miss a day
**So that** I stay motivated to return daily without being punished for a single missed day

## Acceptance Criteria

- [ ] **Given** a user completes their first lesson of a new calendar day, **When** the completion is processed, **Then** their streak count increments by exactly 1
- [ ] **Given** a user completes additional lessons on a day they've already completed one, **When** those complete, **Then** the streak count does not increment further that day
- [ ] **Given** a user's `last_completed_date` is more than 1 calendar day in the past and they have no active streak freeze, **When** they complete a lesson, **Then** their streak resets to 1 (starting over) rather than continuing the old count
- [ ] **Given** a user has an active streak freeze and misses exactly one calendar day, **When** they complete a lesson on a later day, **Then** the freeze is consumed and the streak continues uninterrupted rather than resetting

## Technical Notes

- Streak evaluation happens as part of the same completion flow as story 003 (triggered by `CompleteLesson`), not a separate scheduled job.
- "Calendar day" should use a consistent timezone policy (e.g. UTC, or user-local if that data exists) — an explicit Technical Design decision to avoid ambiguity at day boundaries.
- Streak-freeze acquisition mechanic (how a user gets one) is an open question deferred to Technical Design per requirements.md.

## Dependencies

### Requires
- 003-complete-lesson-award-xp-and-progress (streak update is triggered by lesson completion)

### Enables
- Frontend story 004-lesson-complete-streak-and-levelup-modals

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| User completes lessons in two different timezones on the "same" local day (travel) | Use the single consistent timezone policy from Technical Design; don't attempt per-user timezone tracking in this story |
| User misses 2+ consecutive days with only 1 freeze available | Freeze covers exactly 1 missed day; streak still resets since the gap exceeds what one freeze protects |
| Brand-new user's very first lesson completion | Streak starts at 1, not 0 |

## Out of Scope

- How streak freezes are earned/purchased (Technical Design decision, not fixed here)
- Any UI (owned by `002-core-lesson-loop-ui`)
