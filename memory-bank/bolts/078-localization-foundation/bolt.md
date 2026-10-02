---
id: 078-localization-foundation
unit: 002-localization-foundation
intent: 024-app-localization
type: simple-construction-bolt
status: complete
stories: []
created: '2026-10-02T19:12:33Z'
started: '2026-10-02T19:32:18Z'
completed: '2026-10-02T19:54:29Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-10-02T19:34:45Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-10-02T19:45:01Z'
    artifact: implementation-plan.md
  - name: test
    completed: '2026-10-02T19:54:29Z'
    artifact: implementation-plan.md
requires_bolts:
  - 077-app-language-service
enables_bolts:
  - 079-translate-onboarding-and-settings
requires_units: []
blocks: false
complexity:
  avg_complexity: 3
  avg_uncertainty: 2
  max_dependencies: 1
  testing_scope: 3
---

# Bolt: 078-localization-foundation

## Objective

Flutter localization set-up with English, Amharic and Afaan Oromo ARB files, the app language on the phone and the account, the Settings picker, the sign-up default, and the tests that keep every string translated.

## Stories Included

Written in the unit brief (`intents/024-app-localization/units/002-localization-foundation/unit-brief.md`), not
as separate files, so `stories:` above is empty.

- [x] **002-arb-files-and-fallback**
- [x] **003-app-language-on-the-phone**
- [x] **004-app-language-in-settings**
- [x] **005-sign-up-sets-the-language**
- [x] **006-app-language-follows-the-account**
- [x] **007-translation-guards**

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [x] **1. Plan**
- [x] **2. Implement**
- [x] **3. Test**

## Expected Outputs

- `l10n.yaml`, ARB files, generated `AppLocalizations`, English fallback
- App language repository and start-up wiring
- Settings picker; sign-up default; account sync
- Key-parity test; literal scan with allow-list

## Dependencies

### Requires
- `077-app-language-service`

### Enables
- `079-translate-onboarding-and-settings`
