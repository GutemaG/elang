---
id: 093-voice-generate-api
unit: 003-voice-generation-api
intent: 027-generated-voice-audio
type: simple-construction-bolt
status: complete
stories: []
created: '2026-10-12T09:55:00Z'
started: '2026-10-12T13:15:00Z'
completed: '2026-10-12T13:41:27Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-10-12T13:20:00Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-10-12T13:40:00Z'
    artifact: implementation-plan.md
requires_bolts:
  - 089-voice-settings-store
  - 091-addis-voice-client
enables_bolts:
  - 095-voices-page-try-and-credit
  - 096-generate-tab-controls
requires_units: []
blocks: false
complexity:
  avg_complexity: 2
  avg_uncertainty: 1
  max_dependencies: 2
  testing_scope: 2
---

# Bolt: 093-voice-generate-api

## Objective

`POST /api/v1/admin/voice/generate`: text, gender and speed in, mp3 bytes out, nothing stored.

## Stories Included

Written in the unit brief (`intents/027-generated-voice-audio/units/003-voice-generation-api/unit-brief.md`), not
as separate files, so `stories:` above is empty.

- [ ] **008-generate-a-clip**
- [ ] **009-text-rules**
- [ ] **010-plain-generation-errors**
- [ ] **011-generation-audit-log**

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [x] **1. Plan**
- [x] **2. Implement**
- [ ] **3. Test**

## Expected Outputs

- `generate_voice` use case (language or lesson, voice and speed resolution)
- The route with `X-` headers exposed by CORS
- Text rules, FR-10 error table, audit log
- Tests with fake client and storage

## Dependencies

### Requires
- `089-voice-settings-store`
- `091-addis-voice-client`

### Enables
- `095-voices-page-try-and-credit`
- `096-generate-tab-controls`
