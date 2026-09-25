---
id: 054-picture-offline-and-credits
unit: 003-image-choice-ui
intent: 019-image-choice-exercise-types
type: simple-construction-bolt
status: complete
stories:
  - 003-offline-packs-with-pictures
  - 004-pictures-ready-before-their-question
  - 005-picture-credits-in-the-app
created: '2026-09-25T06:15:00Z'
started: '2026-09-25T20:02:39Z'
completed: '2026-09-25T20:38:36Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-09-25T20:06:25Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-09-25T20:18:07Z'
    artifact: implementation-walkthrough.md
  - name: test
    completed: '2026-09-25T20:38:36Z'
    artifact: test-walkthrough.md
requires_bolts:
  - 053-picture-tile-and-lesson
  - 051-image-choice-samples
enables_bolts: []
requires_units: []
blocks: false
complexity:
  avg_complexity: 2
  avg_uncertainty: 1
  max_dependencies: 2
  testing_scope: 3
---

# Bolt: 054-picture-offline-and-credits

## Objective

Make downloaded lessons carry their pictures and clips, load a lesson's pictures early, and credit the sample pictures in a new Licences entry.

## Stories Included

- [x] **003-offline-packs-with-pictures** (Must)
- [x] **004-pictures-ready-before-their-question** (Should)
- [x] **005-picture-credits-in-the-app** (Must)

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [x] **1. Plan**: includes deciding where the credits file is bundled, and how the pack names local picture files
- [x] **2. Implement**
- [x] **3. Test**

## Expected Outputs

- Pack download, save, load, delete and size handling for pictures and the new audio
- The cached-copy offline rule covering both types
- Early loading of a lesson's pictures
- A "Licences" entry in settings with the picture credits

## Dependencies

### Requires
- `053-picture-tile-and-lesson`
- `051-image-choice-samples`

### Enables
- None

## Success Criteria

- Every story's acceptance criteria met
- Tests passing; no existing test changed except where a new type is added to a list
- No Neon, production R2 or R2 CORS change without the owner's go-ahead
