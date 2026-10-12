---
id: 095-voices-page-try-and-credit
unit: 004-voices-admin-page
intent: 027-generated-voice-audio
type: simple-construction-bolt
status: complete
stories: []
created: '2026-10-12T09:55:00Z'
started: '2026-10-12T14:50:00Z'
completed: '2026-10-12T14:13:48Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-10-12T14:55:00Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-10-12T15:15:00Z'
    artifact: implementation-plan.md
requires_bolts:
  - 094-voices-page
  - 093-voice-generate-api
enables_bolts: []
requires_units: []
blocks: false
complexity:
  avg_complexity: 2
  avg_uncertainty: 1
  max_dependencies: 2
  testing_scope: 2
---

# Bolt: 095-voices-page-try-and-credit

## Objective

Hear voices on the Voices page (previews and Try it with unsaved choices), flag voices that are gone, show the credit.

## Stories Included

Written in the unit brief (`intents/027-generated-voice-audio/units/004-voices-admin-page/unit-brief.md`), not
as separate files, so `stories:` above is empty.

- [ ] **014-try-voices**
- [ ] **015-missing-voices-and-credit**

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [x] **1. Plan**
- [x] **2. Implement**
- [ ] **3. Test**

## Expected Outputs

- Preview buttons and one-at-a-time playback
- Sample text and Try male / Try female
- Missing-voice warning and credit line
- Tests

## Dependencies

### Requires
- `094-voices-page`
- `093-voice-generate-api`

### Enables
- None
