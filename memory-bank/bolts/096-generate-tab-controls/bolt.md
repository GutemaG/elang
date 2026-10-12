---
id: 096-generate-tab-controls
unit: 005-generate-tab
intent: 027-generated-voice-audio
type: simple-construction-bolt
status: complete
stories: []
created: '2026-10-12T09:55:00Z'
started: '2026-10-12T15:40:00Z'
completed: '2026-10-12T15:08:53Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-10-12T15:45:00Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-10-12T16:10:00Z'
    artifact: implementation-plan.md
requires_bolts:
  - 093-voice-generate-api
enables_bolts:
  - 097-generate-tab-editor-and-use
requires_units: []
blocks: false
complexity:
  avg_complexity: 2
  avg_uncertainty: 1
  max_dependencies: 2
  testing_scope: 2
---

# Bolt: 096-generate-tab-controls

## Objective

A Generate tab in `AudioField` with text, voice, speed and Generate, ending in a playable take.

## Stories Included

Written in the unit brief (`intents/027-generated-voice-audio/units/005-generate-tab/unit-brief.md`), not
as separate files, so `stories:` above is empty.

- [ ] **016-generate-tab**
- [ ] **017-generate-controls**

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [x] **1. Plan**
- [x] **2. Implement**
- [ ] **3. Test**

## Expected Outputs

- `voice` prop on `AudioField`; fourth tab only when given
- `GeneratePanel` controls; shared settings hook; remembered gender
- `generateClip` helper
- Tests (existing AudioField tests unchanged)

## Dependencies

### Requires
- `093-voice-generate-api`

### Enables
- `097-generate-tab-editor-and-use`
