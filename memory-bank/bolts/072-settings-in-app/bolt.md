---
id: 072-settings-in-app
unit: 003-settings-store
intent: 022-light-and-dark-themes
type: simple-construction-bolt
status: planned
stories: []
created: '2026-09-30T13:52:00Z'
started: null
completed: null
current_stage: null
stages_completed: []
requires_bolts:
  - 071-settings-store-backend
enables_bolts: []
requires_units: []
blocks: false
complexity:
  avg_complexity: 1
  avg_uncertainty: 1
  max_dependencies: 1
  testing_scope: 2
---

# Bolt: 072-settings-in-app

## Objective

The app reads account settings and app configuration with its own defaults, and keeps the last copy on the phone.

## Stories Included

Written in the unit brief (`intents/022-light-and-dark-themes/units/003-settings-store/unit-brief.md`), not
as separate files, so `stories:` above is empty.

- [ ] **009-app-reads-settings**

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [ ] **1. Plan**
- [ ] **2. Implement**
- [ ] **3. Test**

## Expected Outputs

- Known keys with defaults in the app
- Reading from the session check and `GET /api/v1/config`, saved for offline
- Tests

## Dependencies

### Requires
- `071-settings-store-backend`

### Enables
- None
