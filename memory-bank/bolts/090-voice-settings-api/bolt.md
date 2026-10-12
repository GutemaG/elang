---
id: 090-voice-settings-api
unit: 001-voice-settings-service
intent: 027-generated-voice-audio
type: simple-construction-bolt
status: complete
stories: []
created: '2026-10-12T09:55:00Z'
started: '2026-10-12T10:50:00Z'
completed: '2026-10-12T11:58:08Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-10-12T10:55:00Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-10-12T11:10:00Z'
    artifact: implementation-plan.md
requires_bolts:
  - 089-voice-settings-store
enables_bolts:
  - 091-addis-voice-client
  - 094-voices-page
requires_units: []
blocks: false
complexity:
  avg_complexity: 2
  avg_uncertainty: 1
  max_dependencies: 1
  testing_scope: 2
---

# Bolt: 090-voice-settings-api

## Objective

Admin routes to read and change the voice settings, with the speed range and voice-prefix rules.

## Stories Included

Written in the unit brief (`intents/027-generated-voice-audio/units/001-voice-settings-service/unit-brief.md`), not
as separate files, so `stories:` above is empty.

- [ ] **002-read-voice-settings**
- [ ] **003-change-voice-settings**

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [x] **1. Plan**
- [x] **2. Implement**
- [ ] **3. Test**

## Expected Outputs

- `GET /api/v1/admin/voice/settings`
- `PUT /api/v1/admin/voice/settings/{language}` with field errors and the admin_write log
- Route tests incl. 401/403/404/422

## Dependencies

### Requires
- `089-voice-settings-store`

### Enables
- `091-addis-voice-client`
- `094-voices-page`
