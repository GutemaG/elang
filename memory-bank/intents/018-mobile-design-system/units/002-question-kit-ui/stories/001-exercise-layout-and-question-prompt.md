---
id: 001-exercise-layout-and-question-prompt
unit: 002-question-kit-ui
intent: 018-mobile-design-system
status: draft
priority: must
created: '2026-09-24T12:55:00Z'
assigned_bolt: 044-question-kit
implemented: false
---

# Story: 001-exercise-layout-and-question-prompt

## User Story

**As a** Buna learner
**I want** every question to have the same top bar, prompt style and button position
**So that** I focus on the language, not on working out a new layout each time

## Acceptance Criteria

- [ ] **Given** `ExerciseLayout`, **When** built, **Then** it has the top bar (close via the lesson's `PopScope`, `AppProgressBar`, beans `StatPill`), the prompt, a scrolling answer area and a bottom-docked `AnswerActionBar` slot, on `AppPage`
- [ ] **Given** `QuestionPrompt`, **When** given an instruction and a question, **Then** the instruction is one muted line and the question large and bold below it; without a question the instruction alone is the headline
- [ ] **Given** an optional translation, speaker chip or pronunciation, **When** set, **Then** each appears in its fixed place; the pronunciation uses muted `body-sm` 500, as DESIGN.md asks for under Fidel
- [ ] **Given** the prompt splitting in `splitPrompt`, **When** `QuestionPrompt` replaces `ExercisePromptHeader`, **Then** `splitPrompt` keeps its behaviour and tests
- [ ] **Given** the gallery, **When** opened, **Then** `ExerciseLayout` and every `QuestionPrompt` variant are shown with Latin and Fidel text

## Reference Design (FR-11)

- Fetched in Plan: Duolingo's lesson screen (top bar with close and progress, prompt, bottom check bar) and at least one other language app (e.g. Busuu, Babbel, Memrise); record what is taken and adapted

## Technical Notes

- No mockup exists for lesson screens; this story's Plan must fetch references before designing.

## Dependencies

### Requires
- 001-design-foundation-ui (bolts 042, 043)

### Enables
- 002-one-answer-tile-for-every-question-type
- 004-lesson-screen-on-the-kit

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| A Fidel question longer than one line | Wraps with Ethiopic line height; nothing clipped |

## Out of Scope

- Changing prompt text or how prompts are split
