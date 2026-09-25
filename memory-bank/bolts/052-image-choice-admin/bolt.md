---
id: 052-image-choice-admin
unit: 002-image-choice-admin
intent: 019-image-choice-exercise-types
type: simple-construction-bolt
status: complete
stories:
  - 001-picture-upload-with-shrinking
  - 002-picture-question-editors-and-preview
created: '2026-09-25T06:15:00Z'
started: '2026-09-25T11:37:52Z'
completed: '2026-09-25T13:43:29Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-09-25T12:09:24Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-09-25T12:27:15Z'
    artifact: implementation-walkthrough.md
  - name: test
    completed: '2026-09-25T13:43:27Z'
    artifact: test-walkthrough.md
requires_bolts:
  - 050-image-choice-service
enables_bolts: []
requires_units: []
blocks: false
complexity:
  avg_complexity: 2
  avg_uncertainty: 2
  max_dependencies: 2
  testing_scope: 2
---

# Bolt: 052-image-choice-admin

## Objective

Let admins build both picture question types: pick a picture, have it shrunk and uploaded, describe it, mark the right one, and preview the question.

## Stories Included

- [x] **001-picture-upload-with-shrinking** (Must)
- [x] **002-picture-question-editors-and-preview** (Must)

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [x] **1. Plan**: includes deciding how WebP support is detected, and the slot layout
- [x] **2. Implement**
- [x] **3. Test**

## Expected Outputs

- A picture module: file checks, shrinking to 512 px, WebP or JPEG at ≤ 300 KB, upload through the link
- One picture-choices editor, used by both types
- Both types in "add exercise", the form and the preview
- Tests for shrinking, limits, the editors' blocking rules and the round trip

## Dependencies

### Requires
- `050-image-choice-service`

### Enables
- None

## Success Criteria

- Every story's acceptance criteria met
- Tests passing; no existing test changed except where a new type is added to a list
- No Neon, production R2 or R2 CORS change without the owner's go-ahead
