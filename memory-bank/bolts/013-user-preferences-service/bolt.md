---
id: 013-user-preferences-service
unit: 001-user-preferences-service
intent: 005-profile-and-settings
type: ddd-construction-bolt
status: complete
stories:
  - 001-update-daily-goal-and-language
  - 002-store-notification-preference
created: '2026-09-17T08:00:00Z'
started: '2026-09-17T08:15:00Z'
completed: '2026-09-17T07:51:20Z'
current_stage: null
stages_completed:
  - name: model
    completed: '2026-09-17T08:15:00Z'
    artifact: ddd-01-domain-model.md
  - name: design
    completed: '2026-09-17T08:25:00Z'
    artifact: ddd-02-technical-design.md
  - name: adr
    completed: '2026-09-17T08:35:00Z'
    artifact: adr-7-user-preferences-write-once-exception.md
  - name: implement
    completed: '2026-09-17T10:40:00Z'
    artifact: implementation-walkthrough.md
requires_bolts: []
enables_bolts:
  - 014-profile-and-settings-ui
requires_units: []
blocks: false
complexity:
  avg_complexity: 2
  avg_uncertainty: 2
  max_dependencies: 1
  testing_scope: 2
---

# Bolt: 013-user-preferences-service

## Overview

Only bolt for the `001-user-preferences-service` unit. Amends `001-auth-service`'s `User` aggregate: a new endpoint lets an authenticated user change `selected_language`/`daily_xp_target` after account creation (deliberately amending the existing "written exactly once" invariant), plus a new `notification_enabled` field.

## Objective

Deliver the real preference-update contract that `014-profile-and-settings-ui` builds against, with the invariant amendment properly designed and documented (not a silent bypass), and zero regression to `001-auth-service`'s existing test suite.

## Stories Included

- **001-update-daily-goal-and-language**: Change daily goal and language preference after account creation (Must)
- **002-store-notification-preference**: Persist a notification on/off preference (Must)

## Bolt Type

**Type**: DDD Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/ddd-construction-bolt.md`

## Stages

- [ ] **1. Domain Model**: Pending → ddd-01-domain-model.md
- [ ] **2. Technical Design**: Pending → ddd-02-technical-design.md
- [ ] **3. ADR Analysis**: Pending → adr-*.md (this bolt amends a documented invariant — take this stage seriously, don't skip by pattern-matching to 011's "no ADR needed")
- [ ] **4. Implement**: Pending → backend/ (amended)
- [ ] **5. Test**: Pending → ddd-03-test-report.md

## Dependencies

### Requires
- None to start — amends `001-auth-service` (intent `001-auth-onboarding`), which is already complete

### Enables
- `014-profile-and-settings-ui` (needs the real endpoint contract, not a guessed shape)

## Success Criteria

- [ ] Authenticated user can update language/daily-goal/notification-enabled via the new endpoint
- [ ] Invalid values rejected (422)
- [ ] The "written exactly once" invariant is formally amended and documented, not silently removed
- [ ] `notification_enabled` backfills sensibly for existing users
- [ ] `001-auth-service`'s existing test suite still passes in full

## Notes

Genuinely different risk profile from `011-match-pairs-service` (purely additive) — this one changes a stated invariant on an existing aggregate. Worth real domain-modeling and ADR-analysis effort, not a rubber-stamp pass.
