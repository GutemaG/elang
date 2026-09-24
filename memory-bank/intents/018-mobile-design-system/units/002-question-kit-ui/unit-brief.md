---
unit: 002-question-kit-ui
intent: 018-mobile-design-system
unit_type: frontend
default_bolt_type: simple-construction-bolt
phase: inception
status: stories-defined
created: '2026-09-24T12:55:00Z'
updated: '2026-09-24T12:55:00Z'
---

# Unit Brief: Question Kit UI

## Purpose

One frame, prompt, answer tile, audio button, slot line and action bar for every question type, and the lesson screen rebuilt on them so all five question types look identical in structure.

## Scope

### In Scope
- `lib/features/lesson/widgets/exercise/`: `ExerciseLayout`, `QuestionPrompt`, `AnswerTile`, `AudioPlayButton`, `AnswerSlotLine`, `AnswerActionBar`
- `lesson_screen.dart`, `WordBankBuilder`, `GapSentence`, `MatchPairsBuilder` rebuilt on the kit
- Deleting `ChoiceTile`, `_MatchPairsTileChip`, `_WordChip`, `ExercisePromptHeader`
- The mistake review and the lesson's loading, error and offline states
- Gallery entries for the kit

### Out of Scope
- `LessonController`, grading, sounds, sync
- Lesson-complete screen and lesson sheets (unit 003)
- The spell-from-tiles screen (bolt 033)

---

## Assigned Requirements

| FR | Requirement | Priority |
|----|-------------|----------|
| FR-7 | Question-type kit | Must |
| FR-8 | Every screen moves onto the shared components: the lesson screen part | Must |

NFR-1 to NFR-5 apply to every story.

---

## Story Summary

| Metric | Count |
|--------|-------|
| Total Stories | 4 |
| Must Have | 4 |
| Should Have | 0 |
| Could Have | 0 |

### Stories

| Story ID | Title | Priority | Status |
|----------|-------|----------|--------|
| 001-exercise-layout-and-question-prompt | ExerciseLayout frame and one QuestionPrompt style | Must | Planned |
| 002-one-answer-tile-for-every-question-type | AnswerTile with every state and shape | Must | Planned |
| 003-audio-button-slot-line-and-action-bar | AudioPlayButton, AnswerSlotLine and AnswerActionBar with feedback panel | Must | Planned |
| 004-lesson-screen-on-the-kit | The lesson screen and its five question types built on the kit | Must | Planned |

---

## Dependencies

### Depends On
`001-design-foundation-ui`

### Depended By
`003-screen-migration-ui` (story 005 sweep); bolt 033

### External Dependencies
| System | Purpose | Risk |
|--------|---------|------|
| Plus Jakarta Sans, Noto Sans Ethiopic (SIL OFL) | Bundled fonts | Low |
| External reference designs | Studied in Plan only (FR-11) | Low: patterns only, nothing copied |

---

## Constraints

- Every story's Plan stage names its reference design (Stitch mockup, or a fetched external design) and what is taken from it, before code.
- Highland Pulse tokens only; a new value becomes a token first.
- No behaviour change; existing tests change only where a replaced widget type was found.
- The rules test allow-list only ever shrinks.
- No overflow at 360×640 and 430×932 with 1.3× text; tap targets at least 48dp; semantics kept.

## Bolt Suggestions

| Bolt | Type | Stories | Objective |
|------|------|---------|-----------|
| 044-question-kit | simple-construction-bolt | 001, 002, 003 | The kit, in the gallery, before the lesson screen changes |
| 045-lesson-screen-on-kit | simple-construction-bolt | 004 | The lesson screen and five question types on the kit |
