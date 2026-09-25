---
id: 004-pictures-ready-before-their-question
unit: 003-image-choice-ui
intent: 019-image-choice-exercise-types
status: complete
priority: should
created: '2026-09-25T06:15:00Z'
assigned_bolt: 054-picture-offline-and-credits
implemented: true
---

# Story: 004-pictures-ready-before-their-question

## User Story

**As a** Buna learner
**I want** a lesson's pictures to be loading before I reach their question
**So that** I rarely see a picture still appearing

## Acceptance Criteria

- [x] **Given** a lesson starting online, **When** it loads, **Then** every picture it uses is requested for caching
- [x] **Given** a request that fails, **When** the lesson runs, **Then** nothing is blocked and the tile loads the picture again when shown
- [x] **Given** a downloaded pack, **When** it starts, **Then** its local pictures are warmed from the device, with no network request
- [x] **Given** a lesson with no pictures, **When** it starts, **Then** nothing extra happens

## Technical Notes

- Flutter's `precacheImage`, at the tile's decode size.

## Dependencies

### Requires
- 002-picture-questions-in-lessons-and-practice

### Enables
- None

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| The learner leaves before loading ends | Nothing errors |

## Out of Scope

- Loading the next lesson's pictures
