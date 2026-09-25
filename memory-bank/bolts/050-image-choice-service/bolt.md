---
id: 050-image-choice-service
unit: 001-image-choice-service
intent: 019-image-choice-exercise-types
type: simple-construction-bolt
status: complete
stories:
  - 001-picture-question-content-types
  - 002-picture-upload-links
created: '2026-09-25T06:15:00Z'
started: '2026-09-25T07:45:54Z'
completed: '2026-09-25T09:45:33Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-09-25T07:56:32Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-09-25T08:28:03Z'
    artifact: implementation-walkthrough.md
  - name: test
    completed: '2026-09-25T09:45:32Z'
    artifact: test-walkthrough.md
requires_bolts: []
enables_bolts:
  - 051-image-choice-samples
  - 052-image-choice-admin
  - 053-picture-tile-and-lesson
requires_units: []
blocks: false
complexity:
  avg_complexity: 2
  avg_uncertainty: 1
  max_dependencies: 2
  testing_scope: 2
---

# Bolt: 050-image-choice-service

## Objective

Add both picture question types to the backend, with field-level validation, the migration, the lesson and practice responses, and a safe picture upload link with local storage. This is the contract the admin site and the app build against.

## Stories Included

- [x] **001-picture-question-content-types** (Must)
- [x] **002-picture-upload-links** (Must)

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [x] **1. Plan**: includes deciding the picture-choice JSON shape and the upload route's name
- [x] **2. Implement**
- [x] **3. Test**

## Expected Outputs

- `ExerciseType.IMAGE_CHOICE` and `AUDIO_IMAGE_CHOICE`, content value objects and picture-choice checks
- A migration widening `ck_exercises_type` (SQLite locally; Neon waits for the owner)
- Repository, response schema and mapping for both types; `database-schema.md` updated
- `POST /admin/images/uploads` and local storage at `/media/images`
- The R2 CORS check recorded

## Dependencies

### Requires
- None

### Enables
- `051-image-choice-samples`
- `052-image-choice-admin`
- `053-picture-tile-and-lesson`

## Success Criteria

- Every story's acceptance criteria met
- Tests passing; no existing test changed except where a new type is added to a list
- No Neon, production R2 or R2 CORS change without the owner's go-ahead
