---
id: 098-generate-tab-wiring
unit: 005-generate-tab
intent: 027-generated-voice-audio
type: simple-construction-bolt
status: complete
stories: []
created: '2026-10-12T09:55:00Z'
started: '2026-10-12T17:10:00Z'
completed: '2026-10-12T17:54:13Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-10-12T17:12:00Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-10-12T17:22:00Z'
    artifact: implementation-plan.md
requires_bolts:
  - 097-generate-tab-editor-and-use
enables_bolts:
  - 099-generated-clip-label
requires_units: []
blocks: false
complexity:
  avg_complexity: 1
  avg_uncertainty: 1
  max_dependencies: 2
  testing_scope: 2
---

# Bolt: 098-generate-tab-wiring

## Objective

Workbook items, Sounds letters and example words, and listening exercises offer Generate with their text.

## Stories Included

Written in the unit brief (`intents/027-generated-voice-audio/units/005-generate-tab/unit-brief.md`), not
as separate files, so `stories:` above is empty.

- [ ] **020-generate-in-every-field**

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [x] **1. Plan**
- [x] **2. Implement**
- [ ] **3. Test**

## Expected Outputs

- `voice` passed from LessonPage, LetterPage (x2) and ExerciseForm
- A test per caller

## Dependencies

### Requires
- `097-generate-tab-editor-and-use`

### Enables
- `099-generated-clip-label`
