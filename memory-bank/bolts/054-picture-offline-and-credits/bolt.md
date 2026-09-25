---
id: 054-picture-offline-and-credits
unit: 003-image-choice-ui
intent: 019-image-choice-exercise-types
type: simple-construction-bolt
status: planned
stories:
  - 003-offline-packs-with-pictures
  - 004-pictures-ready-before-their-question
  - 005-picture-credits-in-the-app
created: '2026-09-25T06:15:00Z'
started: null
completed: null
current_stage: null
stages_completed: []
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

- [ ] **003-offline-packs-with-pictures** (Must)
- [ ] **004-pictures-ready-before-their-question** (Should)
- [ ] **005-picture-credits-in-the-app** (Must)

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [ ] **1. Plan**: includes deciding where the credits file is bundled, and how the pack names local picture files
- [ ] **2. Implement**
- [ ] **3. Test**

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
