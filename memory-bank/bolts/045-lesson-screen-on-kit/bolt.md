---
id: 045-lesson-screen-on-kit
unit: 002-question-kit-ui
intent: 018-mobile-design-system
type: simple-construction-bolt
status: complete
stories:
  - 004-lesson-screen-on-the-kit
created: '2026-09-24T12:55:00Z'
started: '2026-09-24T20:31:26Z'
completed: '2026-09-24T21:20:20Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-09-24T20:52:00Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-09-24T21:02:05Z'
    artifact: implementation-walkthrough.md
  - name: test
    completed: '2026-09-24T21:20:19Z'
    artifact: test-walkthrough.md
requires_bolts:
  - 044-question-kit
enables_bolts:
  - 049-settings-downloads-and-sweep
requires_units: []
blocks: false
complexity:
  avg_complexity: 3
  avg_uncertainty: 1
  max_dependencies: 1
  testing_scope: 3
---

# Bolt: 045-lesson-screen-on-kit

## Objective

Rebuild the lesson screen and its five question types on the kit, delete the old tile and prompt widgets, and keep every lesson behaviour test green.

## Stories Included

- [x] **004-lesson-screen-on-the-kit** (Must)

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [x] **1. Plan**: includes choosing and recording each story's reference design (FR-11): the Stitch mockup, or fetched external designs
- [x] **2. Implement**
- [x] **3. Test**

## Expected Outputs

- `lesson_screen.dart`, `word_bank_builder.dart`, `gap_sentence.dart`, `match_pairs_builder.dart` on the kit
- `choice_tile.dart`, `exercise_prompt_header.dart` removed
- Lesson files off the rules allow-list

## Dependencies

### Requires
- `044-question-kit`

### Enables
- `049-settings-downloads-and-sweep`

## Success Criteria

- Every story's acceptance criteria met
- Gallery shows every new component and state
- Rules test passes; its allow-list is no longer than before
- `flutter analyze` clean; full Flutter test suite passes
