---
id: 002-practice-session-assembly-and-completion
unit: 002-practice-ui
intent: 008-srs-and-practice
status: complete
priority: must
created: '2026-09-17T17:05:00Z'
assigned_bolt: null
implemented: true
---

# Story: 002-practice-session-assembly-and-completion

## User Story

**As a** Buna learner
**I want** a practice session built from the words I'm due to review, using the exercises I already know how to answer
**So that** review feels identical to normal lessons, not a new interaction pattern to learn

## Acceptance Criteria

- [ ] **Given** the user starts Practice, **When** the session assembles, **Then** it includes only exercises linked to currently-due vocab items, up to the backend's returned limit
- [ ] **Given** a practice exercise, **When** rendered, **Then** it uses the exact same widget as a regular lesson of that exercise type — no new rendering code
- [ ] **Given** the session completes, **When** it submits, **Then** it writes through the same grading/XP path as a regular lesson where applicable, and any Amole triggers (intent `007`, if landed) apply consistently
- [ ] **Given** the session completes, **When** vocab progress updates, **Then** the due-count shown at the next entry-point visit reflects the change (items just reviewed correctly are no longer due)

## Technical Notes

- Read `001-srs-tracking-service`'s real, final endpoint contracts (due-items shape, whatever completion endpoint it defines) at Plan stage — do not guess the response shape.
- Whether this reuses `LessonController`'s exact class or a sibling controller with the same shape is a Plan-stage decision, following whichever pattern the real due-items/completion contract makes more natural.

## Dependencies

### Requires
- `001-practice-entry-point-and-due-count`
- `001-srs-tracking-service`'s stories (needs the real due-items and completion contracts)

### Enables
- None (terminal story for this intent)

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| A due vocab item's linked exercise belongs to a lesson the user hasn't unlocked/reached yet | Still includable in Practice — Practice review is independent of skill-tree unlock progression (the word was already learned once; review isn't gated by forward progress) |

## Out of Scope

- Any new exercise-rendering widget
