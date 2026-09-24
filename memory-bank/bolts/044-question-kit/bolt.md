---
id: 044-question-kit
unit: 002-question-kit-ui
intent: 018-mobile-design-system
type: simple-construction-bolt
status: planned
stories:
  - 001-exercise-layout-and-question-prompt
  - 002-one-answer-tile-for-every-question-type
  - 003-audio-button-slot-line-and-action-bar
created: '2026-09-24T12:55:00Z'
started: null
completed: null
current_stage: null
stages_completed: []
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

- [ ] **001-exercise-layout-and-question-prompt** (Must)
- [ ] **002-one-answer-tile-for-every-question-type** (Must)
- [ ] **003-audio-button-slot-line-and-action-bar** (Must)

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [ ] **1. Plan**: includes choosing and recording each story's reference design (FR-11): the Stitch mockup, or fetched external designs
- [ ] **2. Implement**
- [ ] **3. Test**

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
