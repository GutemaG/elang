---
id: 044-question-kit
unit: 002-question-kit-ui
intent: 018-mobile-design-system
type: simple-construction-bolt
status: complete
stories:
  - 001-exercise-layout-and-question-prompt
  - 002-one-answer-tile-for-every-question-type
  - 003-audio-button-slot-line-and-action-bar
created: '2026-09-24T12:55:00Z'
started: '2026-09-24T18:51:40Z'
completed: '2026-09-24T20:24:04Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-09-24T19:05:00Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-09-24T19:58:00Z'
    artifact: implementation-walkthrough.md
  - name: test
    completed: '2026-09-24T20:24:03Z'
    artifact: test-walkthrough.md
requires_bolts:
  - 043-design-surfaces
enables_bolts:
  - 045-lesson-screen-on-kit
requires_units: []
blocks: false
complexity:
  avg_complexity: 3
  avg_uncertainty: 2
  max_dependencies: 1
  testing_scope: 2
---

# Bolt: 044-question-kit

## Objective

Build the question-type kit from fetched references and show every piece and state in the gallery, before the lesson screen changes.

## Stories Included

- [x] **001-exercise-layout-and-question-prompt** (Must)
- [x] **002-one-answer-tile-for-every-question-type** (Must)
- [x] **003-audio-button-slot-line-and-action-bar** (Must)

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [x] **1. Plan**: includes choosing and recording each story's reference design (FR-11): the Stitch mockup, or fetched external designs
- [x] **2. Implement**
- [x] **3. Test**

## Expected Outputs

- `lib/features/lesson/widgets/exercise/`: `ExerciseLayout`, `QuestionPrompt`, `AnswerTile`, `AudioPlayButton`, `AnswerSlotLine`, `AnswerActionBar`
- Reference designs recorded in the implementation plan
- Gallery section and component tests

## Dependencies

### Requires
- `043-design-surfaces`

### Enables
- `045-lesson-screen-on-kit`

## Success Criteria

- Every story's acceptance criteria met
- Gallery shows every new component and state
- Rules test passes; its allow-list is no longer than before
- `flutter analyze` clean; full Flutter test suite passes
