---
id: 053-picture-tile-and-lesson
unit: 003-image-choice-ui
intent: 019-image-choice-exercise-types
type: simple-construction-bolt
status: planned
stories:
  - 001-picture-tile-in-the-kit
  - 002-picture-questions-in-lessons-and-practice
created: '2026-09-25T06:15:00Z'
started: null
completed: null
current_stage: null
stages_completed: []
requires_bolts:
  - 050-image-choice-service
enables_bolts:
  - 054-picture-offline-and-credits
requires_units: []
blocks: false
complexity:
  avg_complexity: 3
  avg_uncertainty: 2
  max_dependencies: 2
  testing_scope: 3
---

# Bolt: 053-picture-tile-and-lesson

## Objective

Add the picture tile and grid to the question kit, then show both types on the lesson screen, and so in practice, in the same frame as the other five.

## Stories Included

- [ ] **001-picture-tile-in-the-kit** (Must)
- [ ] **002-picture-questions-in-lessons-and-practice** (Must)

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [ ] **1. Plan**: includes deciding the reference designs (FR-11 of intent 018) and how the tile shares `AnswerTile`'s states
- [ ] **2. Implement**
- [ ] **3. Test**

## Expected Outputs

- `PictureTile` and its grid in `lib/shared/widgets/exercise/`, in the gallery
- `ImageChoiceExercise` and `AudioImageChoiceExercise`: models, parsing, grading, fake API content
- Lesson-screen prompt, answer and audio arms; autoplay for the audio type
- The frame test extended to seven types; the older-app skip test

## Dependencies

### Requires
- `050-image-choice-service`

### Enables
- `054-picture-offline-and-credits`

## Success Criteria

- Every story's acceptance criteria met
- Tests passing; no existing test changed except where a new type is added to a list
- No Neon, production R2 or R2 CORS change without the owner's go-ahead
