---
id: 003-leitner-box-algorithm
unit: 001-srs-tracking-service
intent: 008-srs-and-practice
status: ready
priority: must
created: '2026-09-17T17:00:00Z'
assigned_bolt: null
implemented: false
---

# Story: 003-leitner-box-algorithm

## User Story

**As a** Buna learner
**I want** words I get right to appear less often over time, and words I get wrong to come back soon
**So that** review time is spent where I actually need it

## Acceptance Criteria

- [ ] **Given** a vocab item at box N (1-4) answered correctly, **When** progress updates, **Then** it moves to box N+1 and `next_review_at = now + box[N+1].interval`
- [ ] **Given** a vocab item at box 5 answered correctly, **When** progress updates, **Then** it stays at box 5 (no box 6) and `next_review_at = now + 30 days`
- [ ] **Given** a vocab item at any box answered incorrectly, **When** progress updates, **Then** it resets to box 1 and `next_review_at = tomorrow` (a fixed 1-day offset, stated independently of box 1's own interval)
- [ ] **Given** the box intervals 1/3/7/14/30 days, **When** any transition occurs, **Then** the interval used matches the *destination* box, never the source box

## Technical Notes

- Implement as a small, pure, independently-testable policy (mirrors this codebase's `BeanLedger`/`StreakPolicy` convention: `LeitnerBoxPolicy` or similar), not inlined into `complete_lesson`.
- "Tomorrow" for a reset should be computed the same way `UserStreak`'s day-boundary logic already does (UTC calendar date arithmetic per Technical Design Decision 5 in `005-lesson-engagement-service`), for consistency — verify against `StreakPolicy`'s real implementation rather than reinventing date-boundary handling.

## Dependencies

### Requires
- `002-vocab-progress-retrofit` (this is the transition math that story's writes apply)

### Enables
- `004-due-items-and-count-endpoints`

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Box level somehow already out of the valid 1-5 range (shouldn't happen, but verify DB constraint) | `CHECK` constraint on `box_level` at the schema level, same defensive pattern as `crown_level`'s range check on `user_skill_progress` |

## Out of Scope

- Due-item querying (see the due-endpoints story)
