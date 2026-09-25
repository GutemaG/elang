---
id: 051-image-choice-samples
unit: 001-image-choice-service
intent: 019-image-choice-exercise-types
type: simple-construction-bolt
status: complete
stories:
  - 003-sample-picture-questions
created: '2026-09-25T06:15:00Z'
started: '2026-09-25T11:37:52Z'
completed: '2026-09-25T13:43:28Z'
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
enables_bolts:
  - 054-picture-offline-and-credits
requires_units: []
blocks: false
complexity:
  avg_complexity: 2
  avg_uncertainty: 2
  max_dependencies: 2
  testing_scope: 2
---

# Bolt: 051-image-choice-samples

## Objective

Choose and download free-licensed pictures, shrink them, commit them with a credits file, and seed at least 3 image choice and 2 audio image choice questions in a local-only section of the English to Amharic course.

## Stories Included

- [x] **003-sample-picture-questions** (Must)

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [x] **1. Plan**: includes deciding the picture set (OpenMoji, Twemoji or Wikimedia Commons), the sample words, and the credits file's format
- [x] **2. Implement**
- [x] **3. Test**

## Expected Outputs

- Committed sample pictures (≤ 512 px, ≤ 300 KB, WebP or JPEG)
- A credits file with each picture's source URL, author and licence
- A local-only, insert-only seed, each question linked to its own vocabulary word
- Nothing uploaded to production R2 or written to Neon

## Dependencies

### Requires
- `050-image-choice-service`

### Enables
- `054-picture-offline-and-credits`

## Success Criteria

- Every story's acceptance criteria met
- Tests passing; no existing test changed except where a new type is added to a list
- No Neon, production R2 or R2 CORS change without the owner's go-ahead
