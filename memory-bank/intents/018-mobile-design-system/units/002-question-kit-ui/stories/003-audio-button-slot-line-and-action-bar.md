---
id: 003-audio-button-slot-line-and-action-bar
unit: 002-question-kit-ui
intent: 018-mobile-design-system
status: complete
priority: must
created: '2026-09-24T12:55:00Z'
assigned_bolt: 044-question-kit
implemented: true
---

# Story: 003-audio-button-slot-line-and-action-bar

## User Story

**As a** Buna learner
**I want** the play button, the line my sentence builds on and the Check/Continue bar to look the same in every question
**So that** after answering I immediately see whether I was right, in the same place every time

## Acceptance Criteria

- [x] **Given** `AudioPlayButton`, **When** built, **Then** it is a big round tactile button with a shelf and press effect and a playing state; the tap calls the same `LessonAudioPlayer.play` as today
- [x] **Given** `AnswerSlotLine`, **When** used for a built sentence or a gap, **Then** it shows the ruled line and the placed chips or gap word, matching today's `WordBankBuilder` and `GapSentence` behaviour
- [x] **Given** `AnswerActionBar` before grading, **When** the question needs Check, **Then** Check is shown (disabled until there is an answer); otherwise its space is held so nothing jumps
- [x] **Given** `AnswerActionBar` after grading, **When** shown, **Then** a tinted panel reads "Correct!" (mint, green) or "Not quite" (blush, terracotta) above a Continue button in the matching variant
- [x] **Given** the grade, **When** the panel shows, **Then** it comes only from `LessonController.feedback`; no new controller state is added

## Reference Design (FR-11)

- Fetched in Plan: Duolingo's bottom feedback banner and check button; at least one other app's listening button

## Technical Notes

- The feedback panel is the one visible addition this intent allows (requirements, Constraints).

## Dependencies

### Requires
- 002-one-answer-tile-for-every-question-type

### Enables
- 004-lesson-screen-on-the-kit

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Continue tapped twice quickly | Advances once, as today |

## Out of Scope

- Showing the correct answer text (not in the controller today)
