---
id: 094-voices-page
unit: 004-voices-admin-page
intent: 027-generated-voice-audio
type: simple-construction-bolt
status: complete
stories: []
created: '2026-10-12T09:55:00Z'
started: '2026-10-12T14:10:00Z'
completed: '2026-10-12T13:55:36Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-10-12T14:15:00Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-10-12T14:35:00Z'
    artifact: implementation-plan.md
requires_bolts:
  - 090-voice-settings-api
  - 092-voice-catalog-and-usage
enables_bolts:
  - 095-voices-page-try-and-credit
requires_units: []
blocks: false
complexity:
  avg_complexity: 2
  avg_uncertainty: 1
  max_dependencies: 2
  testing_scope: 2
---

# Bolt: 094-voices-page

## Objective

The Voices page: nav item, one card per language with voice selects, speed slider, Save and Discard.

## Stories Included

Written in the unit brief (`intents/027-generated-voice-audio/units/004-voices-admin-page/unit-brief.md`), not
as separate files, so `stories:` above is empty.

- [ ] **012-voices-page-and-nav**
- [ ] **013-language-voice-card**

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [x] **1. Plan**
- [x] **2. Implement**
- [ ] **3. Test**

## Expected Outputs

- `admin/src/voices/` page, card and `api.ts`
- Route `/voices` and nav item after Sounds
- Not-configured state
- Tests

## Dependencies

### Requires
- `090-voice-settings-api`
- `092-voice-catalog-and-usage`

### Enables
- `095-voices-page-try-and-credit`
