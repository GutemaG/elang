---
id: 001-gap-fill-exercise-screen
unit: 002-gap-fill-ui
intent: 015-gap-fill-exercise-type
status: generated
priority: must
created: '2026-09-20T12:45:00Z'
assigned_bolt: 031-gap-fill-ui
implemented: false
---

# Story: 001-gap-fill-exercise-screen

## User Story

**As a** Buna learner
**I want** to fill the missing word in a sentence by tapping one of a few options
**So that** I practise choosing the right word in context, not just recognising it alone

## Acceptance Criteria

- [ ] **Given** a `gap_fill` exercise, **When** it renders, **Then** the sentence shows with a visibly distinct gap where the missing word belongs, with the from-language gloss beneath it
- [ ] **Given** the exercise, **When** the learner taps a word tile, **Then** that word appears **in the gap**, so the completed sentence can be read before checking
- [ ] **Given** a selection, **When** the learner taps a different tile, **Then** the selection moves; no grading happens until Check
- [ ] **Given** no selection, **When** the learner looks at Check, **Then** it is disabled; it enables as soon as a word is chosen
- [ ] **Given** a selection, **When** the learner taps Check, **Then** the exercise is graded locally against `correct_choice_id` with no network call, and `LessonController`'s existing grade/advance/Beans/XP flow runs unchanged
- [ ] **Given** a graded exercise, **When** the result shows, **Then** correct and incorrect states reuse the existing tile colour language rather than new states
- [ ] **Given** a sentence in Fidel and one in Latin script, **When** each renders at a large text scale, **Then** neither overflows

## Technical Notes

- Add `GapFillExercise` to the sealed `Exercise` in `lib/shared/models/exercise.dart` and an arm to `isAnswerCorrect`. The sealed class will refuse to compile until every switch is updated — that is the intended safety net.
- Parse in `http_lesson_api.dart`'s `_toExercise` and add to `fake_lesson_api.dart`.
- New arms in `lesson_screen.dart`'s body switch (currently at line ~543) and its `canSubmit` switch (~751).
- Reuse `choice_tile.dart` for the options. The new rendering is the sentence-with-gap only.
- On text metrics: this codebase has been bitten by predicted heights (see the `011-dashboard-ui-polish` banner follow-ups). Prefer a layout that cannot overflow to one that computes what it needs.

## Dependencies

### Requires
- `001-gap-fill-service`'s `001-serve-gap-fill-exercise-content`

### Enables
- `002-offline-gap-fill-verification`

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| The gap falls at the start or the end of the sentence | Renders correctly, no stray leading or trailing space |
| A long sentence wraps to several lines | The gap wraps with the text; the filled word does not break the line badly |
| A very long option word at a large text scale | The tile and the gap both accommodate it or ellipsise; nothing overflows |
| The learner taps the already-selected tile | Either keeps or clears the selection — pick one, apply it consistently, and cover it with a test |

## Out of Scope

- Typing into the gap
- More than one gap per sentence
- Any change to `LessonController`
