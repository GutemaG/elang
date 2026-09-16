---
id: 002-lesson-exercise-screens
unit: 002-core-lesson-loop-ui
intent: 002-core-lesson-loop
status: complete
priority: must
created: '2026-09-15T18:00:00Z'
assigned_bolt: 006-core-lesson-loop-ui
implemented: true
---

# Story: 002-lesson-exercise-screens

## User Story

**As a** Buna user
**I want** to answer multiple-choice, listening, and sentence-construction exercises with clear feedback
**So that** I can actually take a lesson

## Acceptance Criteria

- [x] **Given** a lesson is started, **When** the first exercise loads, **Then** all of that lesson's exercises were fetched in a single request (no per-exercise loading spinner/round trip)
- [x] **Given** any of the 3 exercise types, **When** rendered, **Then** it matches the "Choice & Match Tiles" component states from the Highland Pulse design (default, selected, correct, incorrect)
- [x] **Given** a correct answer, **When** submitted, **Then** the correct-tile state shows and the lesson advances to the next exercise
- [x] **Given** an incorrect answer, **When** submitted, **Then** the incorrect-tile state (shake animation) shows and the local bean count decrements
- [x] **Given** a listening exercise, **When** rendered, **Then** the user can tap to play/replay the audio before answering
- [x] **Given** an incorrect answer on any exercise, **When** it's graded, **Then** that exercise is requeued to the end of the current lesson attempt and must be answered correctly before the lesson can finish (a miss is never just skipped past)

## Technical Notes

- Local in-lesson state (current exercise index, beans remaining this attempt) is held client-side per the unit brief's `InLessonState` model, not re-fetched per exercise.
- Audio playback needs a Flutter audio-playing package (choice is a Technical Design/implementation detail).
- Can be built against fake lesson-content responses first; real integration is story 005.

## Dependencies

### Requires
- 001-skill-tree-dashboard-screen (entry point into a lesson)
- `001-lesson-service` story 001 & 002 (API contract) for the real content/answer shapes

### Enables
- 003-out-of-beans-and-refill-modal (triggered when local beans hit 0)
- 004-lesson-complete-streak-and-levelup-modals (triggered when the last exercise is answered)

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| App is backgrounded/killed mid-lesson | No crash on resume; lesson can be safely restarted (per requirements.md's Reliability NFR) |
| Local beans hit 0 mid-lesson | Lesson is interrupted, hands off to story 003's modal, rather than continuing to accept answers |
| Listening exercise audio fails to load | Clear inline error, doesn't block the rest of the lesson from being navigable |
| Every remaining exercise in the queue is the same requeued miss (learner keeps getting it wrong) | Requeued indefinitely to the end of the queue each time until answered correctly, or the lesson is interrupted by beans hitting 0 |

## Out of Scope

- Server-side answer grading (owned by `001-lesson-service`)
- Speech/pronunciation exercises (not in scope per requirements.md)

## Post-implementation note (2026-09-16)

Added after bolt 006 was already complete, per explicit user request: missed exercises now loop back into the lesson queue (`LessonController._queue`) instead of being answered once and left behind. A wrong answer appends that exercise's index to the end of the queue; the lesson only finishes once the queue is exhausted, so every exercise must eventually be answered correctly. The progress bar (`_ProgressHeader`) reflects this — its denominator stays the original exercise count while the numerator (queue position) can now trail behind it when misses are queued, matching the same visual behavior as other spaced-retry lesson apps. Verified via a new widget test (`lesson_screen_test.dart`: "a missed exercise loops back and must be answered correctly before the lesson finishes") plus the full existing suite (65/65 passing) and a clean `flutter analyze`.
