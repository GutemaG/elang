---
id: 099-generated-clip-label
unit: 006-generated-clip-label
intent: 027-generated-voice-audio
type: simple-construction-bolt
status: complete
stories: []
created: '2026-10-12T09:55:00Z'
started: '2026-10-12T17:40:00Z'
completed: '2026-10-12T19:21:13Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-10-12T17:42:00Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-10-12T18:05:00Z'
    artifact: implementation-plan.md
requires_bolts:
  - 098-generate-tab-wiring
enables_bolts: []
requires_units: []
blocks: false
complexity:
  avg_complexity: 1
  avg_uncertainty: 1
  max_dependencies: 2
  testing_scope: 2
---

# Bolt: 099-generated-clip-label

## Objective

Generated clips are stored with a `gen-{voice}` name and show a "Generated · {Name}" pill. (Could)

## Stories Included

Written in the unit brief (`intents/027-generated-voice-audio/units/006-generated-clip-label/unit-brief.md`), not
as separate files, so `stories:` above is empty.

- [ ] **021-generated-clip-label**

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [x] **1. Plan**
- [x] **2. Implement**
- [ ] **3. Test**

## Expected Outputs

- Optional `source` on the three presign routes
- Uploaders pass it from the Generate panel
- `CurrentClip` pill
- Tests both sides

## Dependencies

### Requires
- `098-generate-tab-wiring`

### Enables
- None
