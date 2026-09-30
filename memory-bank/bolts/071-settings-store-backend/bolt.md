---
id: 071-settings-store-backend
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
requires_bolts: []
enables_bolts:
  - 072-settings-in-app
requires_units: []
blocks: false
complexity:
  avg_complexity: 2
  avg_uncertainty: 2
  max_dependencies: 1
  testing_scope: 2
---

# Bolt: 071-settings-store-backend

## Objective

Account settings as JSON on `users` and app configuration in `app_config`, read through registries with defaults.

## Stories Included

Written in the unit brief (`intents/022-light-and-dark-themes/units/003-settings-store/unit-brief.md`), not
as separate files, so `stories:` above is empty.

- [ ] **007-account-settings-json**
- [ ] **008-app-config**

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [ ] **1. Plan**
- [ ] **2. Implement**
- [ ] **3. Test**

## Expected Outputs

- The migration (`users.settings`, `app_config`)
- Registries, `PATCH /api/v1/users/me/settings`, `GET /api/v1/config`, `settings` on the session check
- Tests; API notes

## Dependencies

### Requires
- None

### Enables
- `072-settings-in-app`
