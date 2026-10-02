---
id: 077-app-language-service
unit: 001-app-language-service
intent: 024-app-localization
type: simple-construction-bolt
status: complete
stories: []
created: '2026-10-02T19:12:33Z'
started: '2026-10-02T19:16:50Z'
completed: '2026-10-02T19:32:06Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-10-02T19:17:48Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-10-02T19:19:27Z'
    artifact: implementation-plan.md
  - name: test
    completed: '2026-10-02T19:32:06Z'
    artifact: implementation-plan.md
requires_bolts: []
enables_bolts:
  - 078-localization-foundation
requires_units: []
blocks: false
complexity:
  avg_complexity: 1
  avg_uncertainty: 1
  max_dependencies: 0
  testing_scope: 2
---

# Bolt: 077-app-language-service

## Objective

Store the learner's app language on the account as the account setting `app_language` (`PATCH /api/v1/users/me/settings`, returned by session validation). No migration (revised at the plan stage).

## Stories Included

Written in the unit brief (`intents/024-app-localization/units/001-app-language-service/unit-brief.md`), not
as separate files, so `stories:` above is empty.

- [x] **001-app-language-on-the-account**

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [x] **1. Plan**
- [x] **2. Implement**
- [x] **3. Test**

## Expected Outputs

- `pattern` on `str` settings; `app_language` in `ACCOUNT_SETTINGS`
- No migration
- Tests; API notes

## Dependencies

### Requires
None.

### Enables
- `078-localization-foundation`
