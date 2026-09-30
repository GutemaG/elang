---
id: 071-settings-store-backend
unit: 003-settings-store
intent: 022-light-and-dark-themes
type: simple-construction-bolt
status: complete
stories: []
created: '2026-09-30T13:52:00Z'
started: '2026-09-30T20:18:05Z'
completed: '2026-09-30T20:50:31Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-09-30T20:18:34Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-09-30T20:38:32Z'
    artifact: implementation-plan.md
  - name: test
    completed: '2026-09-30T20:50:31Z'
    artifact: implementation-plan.md
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

- [x] **007-account-settings-json**
- [x] **008-app-config**

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [x] **1. Plan**
- [x] **2. Implement**
- [x] **3. Test**

## Expected Outputs

- The migration (`users.settings`, `app_config`)
- Registries, `PATCH /api/v1/users/me/settings`, `GET /api/v1/config`, `settings` on the session check
- Tests; API notes

## Dependencies

### Requires
- None

### Enables
- `072-settings-in-app`
