---
id: 002-picture-questions-in-lessons-and-practice
unit: 003-image-choice-ui
intent: 019-image-choice-exercise-types
status: draft
priority: must
created: '2026-09-25T06:15:00Z'
assigned_bolt: 053-picture-tile-and-lesson
implemented: false
---

# Story: 002-picture-questions-in-lessons-and-practice

## User Story

**As a** Buna learner
**I want** to read or hear a word and tap the picture that matches it
**So that** I learn what words mean, not only how to translate them

## Acceptance Criteria

- [ ] **Given** an `image_choice` question, **When** it appears, **Then** `QuestionPrompt` shows the prompt, split as other prompts are, above the picture grid
- [ ] **Given** an `audio_image_choice` question, **When** it appears, **Then** only the instruction and the large play button show above the grid, with no written word, and the clip plays once by itself
- [ ] **Given** the audio question, **When** answered or rebuilt, **Then** the clip does not play again; the button replays it
- [ ] **Given** a tap on a picture, **When** graded, **Then** only that tile shows correct or incorrect, an incorrect tile shakes, and no tile takes another tap
- [ ] **Given** a wrong answer, **When** graded, **Then** a bean is lost and the question comes back later, as for multiple choice
- [ ] **Given** a lesson with all seven types, **When** each appears, **Then** the frame test finds the same top bar, prompt place, action bar and answer edge for each
- [ ] **Given** practice, **When** a due word's question is a picture question, **Then** it shows and grades there, and updates the word's review progress
- [ ] **Given** a picture reference that is a `/media/...` path, **When** parsed, **Then** it resolves against the API base, as audio does
- [ ] **Given** an app without these types (FR-9), **When** a lesson holds them, **Then** they are skipped and counted in `unrenderableCount`, and the lesson completes; a test with an unknown type proves it
- [ ] **Given** 320 and 360 px at 1.0× and 1.3× text, **When** either type is shown before and after answering, **Then** nothing overflows

## Technical Notes

- `ImageChoiceExercise` and `AudioImageChoiceExercise` in `exercise.dart`, `http_lesson_api.dart` parsing, `fake_lesson_api.dart` samples, and the `_promptFor`, `_answersFor` and `_clipOf` arms in `lesson_screen.dart`.
- The pack store's two halves are story 003's, but the type must not crash the store before then: unknown types there are checked in Plan.

## Dependencies

### Requires
- 001-picture-tile-in-the-kit
- 001-picture-question-content-types (unit 001)

### Enables
- 003-offline-packs-with-pictures
- 004-pictures-ready-before-their-question

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| The browser blocks the first play on the web | Ignored; the button still plays |
| Every picture fails to load | Alt texts show; the question is answered normally |

## Out of Scope

- Offline packs (story 003)
