---
id: 004-lesson-complete-streak-and-levelup-modals
unit: 002-core-lesson-loop-ui
intent: 002-core-lesson-loop
status: complete
priority: should
created: '2026-09-15T18:00:00Z'
assigned_bolt: 006-core-lesson-loop-ui
implemented: true
---

# Story: 004-lesson-complete-streak-and-levelup-modals

## User Story

**As a** Buna user who just finished a lesson
**I want** to see what I earned and how my streak/skill progress changed
**So that** I feel rewarded and know what happened

## Acceptance Criteria

- [ ] **Given** a lesson is completed successfully, **When** the completion response returns, **Then** the lesson-complete summary shows (XP earned, progress toward today's `daily_xp_target`), matching `lesson_complete_summary_1/2` designs
- [ ] **Given** the completion also updated the streak, **When** the summary is shown, **Then** the updated streak count is visible
- [ ] **Given** the completion unlocked a new skill or increased a crown level, **When** the summary is shown, **Then** that's reflected (either inline or via the `level_up_streak_freeze_modal`)
- [ ] **Given** the user dismisses the summary, **When** they return, **Then** they land back on the skill-tree dashboard with updated node state

## Technical Notes

- Can be built against a fake completion-response shape first; real integration is story 005.
- Priority is `Should` (matching backend story 003's crown-level piece and story 004's streak piece) — the core XP/completion summary itself is effectively `Must` since FR-5 is Must; if scope needs trimming, trim the level-up/crown visual flourish first, not the base summary.

## Dependencies

### Requires
- 002-lesson-exercise-screens (triggered when the last exercise is answered successfully)
- `001-lesson-service` stories 003 & 004 (API contract) for the real completion/streak response shape

### Enables
- None (returns to the dashboard, story 001)

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Lesson completed but no skill/crown change occurred | Summary still shows XP/streak; no empty or broken level-up section |
| Streak was reset (missed day, no freeze available) | Summary reflects the new (reset) streak count honestly, not the old one |

## Out of Scope

- Any backend award/progress logic (owned by `001-lesson-service`)
