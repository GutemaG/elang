---
id: 053-picture-tile-and-lesson
unit: 003-image-choice-ui
intent: 019-image-choice-exercise-types
type: simple-construction-bolt
status: complete
stories:
  - 001-picture-tile-in-the-kit
  - 002-picture-questions-in-lessons-and-practice
created: '2026-09-25T06:15:00Z'
started: '2026-09-25T15:04:32Z'
completed: '2026-09-25T20:00:46Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-09-25T18:35:00Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-09-25T19:33:41Z'
    artifact: implementation-walkthrough.md
  - name: test
    completed: '2026-09-25T20:00:45Z'
    artifact: test-walkthrough.md
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

- [x] **001-picture-tile-in-the-kit** (Must)
- [x] **002-picture-questions-in-lessons-and-practice** (Must)

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [x] **1. Plan**: includes deciding the reference designs (FR-11 of intent 018) and how the tile shares `AnswerTile`'s states
- [x] **2. Implement**
- [x] **3. Test**

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
