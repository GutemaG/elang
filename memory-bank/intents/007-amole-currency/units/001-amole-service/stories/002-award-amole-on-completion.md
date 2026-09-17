---
id: 002-award-amole-on-completion
unit: 001-amole-service
intent: 007-amole-currency
status: ready
priority: must
created: '2026-09-17T16:20:00Z'
assigned_bolt: null
implemented: false
---

# Story: 002-award-amole-on-completion

## User Story

**As a** Buna learner
**I want** to earn Amole by playing lessons and hitting streak milestones
**So that** I can eventually afford another Bean refill instead of only ever spending down a one-time grant

## Acceptance Criteria

- [ ] **Given** a genuinely completed lesson attempt, **When** `complete_lesson` runs, **Then** a flat-amount award row posts, `source='lesson_completion'`, `reference_id=attempt_id`
- [ ] **Given** a completed lesson with `correct_count == total_count`, **When** `complete_lesson` runs, **Then** an additional bonus row posts in the same transaction, `source='perfect_lesson'`, `reference_id=attempt_id`
- [ ] **Given** a user's streak reaches 7 or 30 days **for the first time**, **When** `complete_lesson` updates the streak, **Then** a one-time milestone bonus row posts (`source='streak_milestone_7'` or `'streak_milestone_30'`)
- [ ] **Given** a retried completion request for an already-processed `attempt_id`, **When** `complete_lesson`'s existing idempotency check short-circuits, **Then** zero additional ledger rows post — and even if that short-circuit were ever bypassed, the ledger's own uniqueness constraint (story `001`) would still prevent a duplicate
- [ ] **Given** a user's streak has already passed a milestone (e.g. day 10, milestone was day 7), **When** they complete further lessons, **Then** no repeat milestone bonus posts

## Technical Notes

- Read `complete_lesson`'s real current implementation (`backend/app/application/lesson_use_cases.py`) at Stage 4 before finalizing exactly where the award calls slot into its existing Beans/XP/streak/progress orchestration — don't assume the insertion point without reading it.
- "First time reaching a milestone" needs a real check — the natural one is "does a ledger row with this `source` already exist for this user," which is why `reference_id` for streak milestones is a synthesized per-user-per-milestone value, not an `attempt_id` (there's no natural attempt tied to the day the streak count itself increments) — confirm this against `UserStreak`'s real fields at Technical Design.
- Flat/bonus amounts are named constants (Technical Design decision), not fixed here.

## Dependencies

### Requires
- `001-ledger-backed-amole-balance` (needs the ledger and its uniqueness constraint to exist)

### Enables
- `002-amole-ui`'s dashboard display (needs a balance that actually changes after a lesson)

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| A lesson with a single exercise, answered correctly (trivially "perfect") | Still gets the perfect-lesson bonus — no minimum-exercise-count exclusion unless Technical Design decides one is needed |
| Streak milestone and lesson completion happen in the exact same `complete_lesson` call (the completion that pushes the streak to day 7) | Both award rows post in that same call/transaction — not deferred to a separate process |

## Out of Scope

- Any spend category beyond Bean refill (Phase 2)
- Any XP or Beans behavior change — this story only adds Amole side-effects alongside the existing ones
