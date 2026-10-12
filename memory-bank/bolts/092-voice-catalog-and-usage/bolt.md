---
id: 092-voice-catalog-and-usage
unit: 002-addis-voice-client
intent: 027-generated-voice-audio
type: simple-construction-bolt
status: complete
stories: []
created: '2026-10-12T09:55:00Z'
started: '2026-10-12T12:30:00Z'
completed: '2026-10-12T12:48:55Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-10-12T12:35:00Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-10-12T12:50:00Z'
    artifact: implementation-plan.md
requires_bolts:
  - 091-addis-voice-client
enables_bolts:
  - 094-voices-page
requires_units: []
blocks: false
complexity:
  avg_complexity: 2
  avg_uncertainty: 1
  max_dependencies: 2
  testing_scope: 2
---

# Bolt: 092-voice-catalog-and-usage

## Objective

Admin routes for the available voices (cached 10 min) and the credit, and the catalog check on saving settings.

## Stories Included

Written in the unit brief (`intents/027-generated-voice-audio/units/002-addis-voice-client/unit-brief.md`), not
as separate files, so `stories:` above is empty.

- [ ] **006-voice-catalog**
- [ ] **007-addis-credit**

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [x] **1. Plan**
- [x] **2. Implement**
- [ ] **3. Test**

## Expected Outputs

- `GET /api/v1/admin/voice/voices?language=`
- `GET /api/v1/admin/voice/usage`
- Catalog check on PUT settings, with the unchecked fallback
- Tests with a fake client

## Dependencies

### Requires
- `091-addis-voice-client`

### Enables
- `094-voices-page`
