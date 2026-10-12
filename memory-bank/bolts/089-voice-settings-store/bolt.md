---
id: 089-voice-settings-store
unit: 001-voice-settings-service
intent: 027-generated-voice-audio
type: simple-construction-bolt
status: complete
stories: []
created: '2026-10-12T09:55:00Z'
started: '2026-10-12T10:05:00Z'
completed: '2026-10-12T11:33:39Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-10-12T10:08:00Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-10-12T10:20:00Z'
    artifact: implementation-plan.md
requires_bolts: []
enables_bolts:
  - 090-voice-settings-api
  - 093-voice-generate-api
requires_units: []
blocks: false
complexity:
  avg_complexity: 1
  avg_uncertainty: 1
  max_dependencies: 1
  testing_scope: 1
---

# Bolt: 089-voice-settings-store

## Objective

Store each supported language's male voice, female voice and speed, with defaults when nothing is saved.

## Stories Included

Written in the unit brief (`intents/027-generated-voice-audio/units/001-voice-settings-service/unit-brief.md`), not
as separate files, so `stories:` above is empty.

- [ ] **001-voice-settings-defaults**

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [x] **1. Plan**
- [x] **2. Implement**
- [ ] **3. Test**

## Expected Outputs

- Domain constants: supported languages and default voices
- `voice_settings` model and Alembic migration (SQLite + Postgres)
- Repository `get` / `list` / `save` with tests

## Dependencies

### Requires
- None

### Enables
- `090-voice-settings-api`
- `093-voice-generate-api`
