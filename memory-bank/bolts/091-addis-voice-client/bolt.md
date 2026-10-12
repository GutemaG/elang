---
id: 091-addis-voice-client
unit: 002-addis-voice-client
intent: 027-generated-voice-audio
type: simple-construction-bolt
status: complete
stories: []
created: '2026-10-12T09:55:00Z'
started: '2026-10-12T11:40:00Z'
completed: '2026-10-12T12:31:23Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-10-12T11:45:00Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-10-12T12:00:00Z'
    artifact: implementation-plan.md
requires_bolts:
  - 090-voice-settings-api
enables_bolts:
  - 092-voice-catalog-and-usage
  - 093-voice-generate-api
requires_units: []
blocks: false
complexity:
  avg_complexity: 2
  avg_uncertainty: 2
  max_dependencies: 1
  testing_scope: 2
---

# Bolt: 091-addis-voice-client

## Objective

Addis AI settings and a typed client for voices, usage and generation, with retries and domain errors.

## Stories Included

Written in the unit brief (`intents/027-generated-voice-audio/units/002-addis-voice-client/unit-brief.md`), not
as separate files, so `stories:` above is empty.

- [ ] **004-addis-connection-settings**
- [ ] **005-addis-voice-client**

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [x] **1. Plan**
- [x] **2. Implement**
- [ ] **3. Test**

## Expected Outputs

- `addis_*` settings; `ADDIS_API_KEY=` in the env example
- `AddisVoiceClient` (httpx, injectable transport)
- Voice exceptions in the domain
- Fake-transport tests for every mapping; key-leak test
- `configured` in GET settings reads the key

## Dependencies

### Requires
- `090-voice-settings-api`

### Enables
- `092-voice-catalog-and-usage`
- `093-voice-generate-api`
