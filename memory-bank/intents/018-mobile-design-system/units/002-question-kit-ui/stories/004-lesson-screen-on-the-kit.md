---
id: 004-lesson-screen-on-the-kit
unit: 002-question-kit-ui
intent: 018-mobile-design-system
status: complete
priority: must
created: '2026-09-24T12:55:00Z'
assigned_bolt: 045-lesson-screen-on-kit
implemented: true
---

# Story: 004-lesson-screen-on-the-kit

## User Story

**As a** Buna learner
**I want** every question in a lesson to share one layout and style
**So that** a lesson feels like one smooth flow rather than five different screens

## Acceptance Criteria

- [x] **Given** multiple choice, listening, sentence construction, match pairs and gap fill, **When** each is shown, **Then** it is built only from `ExerciseLayout`, `QuestionPrompt`, `AnswerTile`, `AudioPlayButton`, `AnswerSlotLine` and `AnswerActionBar`
- [x] **Given** the five types, **When** compared side by side, **Then** the top bar, prompt style, side margins, tile spacing and action bar position are identical
- [x] **Given** `ChoiceTile`, `_MatchPairsTileChip`, `_WordChip` and `ExercisePromptHeader`, **When** this story is done, **Then** they are deleted and no code refers to them
- [x] **Given** the mistake-review card, the loading state, the "couldn't load" error and the offline "download required" state, **When** shown, **Then** they use `SheetHero`-style layout, `LoadingState`, `ErrorState` and `EmptyState`
- [x] **Given** the full lesson test suite, **When** run, **Then** every behaviour test passes; tests change only where they found a replaced widget type, and still check the same thing
- [x] **Given** the rules test, **When** run, **Then** `lesson_screen.dart` and the lesson exercise widgets are off the allow-list and pass
- [x] **Given** a question with audio, **When** it first appears (including when a missed question comes back), **Then** its clip plays once by itself; tapping the play button replays it, and nothing replays on a rebuild (added at the bolt 045 Plan checkpoint, 2026-09-24)

## Reference Design (FR-11)

- The references chosen in stories 001-003
- No mockup exists for the mistake review; fetch a reference in Plan

## Technical Notes

- Grading on tap, the shake, dimmed used words, match-pair arming and the held space for the action bar must behave exactly as before.

## Dependencies

### Requires
- 001-exercise-layout-and-question-prompt
- 002-one-answer-tile-for-every-question-type
- 003-audio-button-slot-line-and-action-bar

### Enables
- 003-screen-migration-ui story 005 (sweep)
- Bolt 033 (spell tiles, built on the kit afterwards)

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Offline lesson from a pack | Same look as online |
| Out of beans mid-lesson | The out-of-beans sheet opens as today (restyled in unit 003) |

## Out of Scope

- The spell-from-tiles screen (bolt 033)
- Lesson sheets (unit 003 story 003)
