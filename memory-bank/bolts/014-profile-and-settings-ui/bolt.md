---
id: 014-profile-and-settings-ui
unit: 002-profile-and-settings-ui
intent: 005-profile-and-settings
type: simple-construction-bolt
status: complete
stories:
  - 001-settings-screen
  - 002-logout
created: '2026-09-17T08:00:00Z'
started: '2026-09-17T11:30:00Z'
completed: '2026-09-17T08:31:57Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-09-17T11:30:00Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-09-17T13:00:00Z'
    artifact: implementation-walkthrough.md
requires_bolts:
  - 013-user-preferences-service
enables_bolts: []
requires_units:
  - 001-user-preferences-service
blocks: true
complexity:
  avg_complexity: 1
  avg_uncertainty: 1
  max_dependencies: 1
  testing_scope: 2
---

# Bolt: 014-profile-and-settings-ui

## Overview

Only bolt for the `002-profile-and-settings-ui` unit. The first Settings screen in this app: view/edit language, daily goal, notification (via `013-user-preferences-service`'s endpoint), toggle sound (client-local, gates the existing `AnswerFeedbackPlayer`), and log out (reuses the existing `SessionRepository.clearSession()`).

## Objective

Deliver a working Settings screen end-to-end, closing the "update their settings" gap from the original product scope, with zero regression to any existing screen.

## Stories Included

- **001-settings-screen**: View and edit language/daily-goal/notification/sound from one screen (Must)
- **002-logout**: Log out from Settings (Must)

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [ ] **1. Plan**: Pending → implementation-plan.md
- [ ] **2. Implement**: Pending → implementation-walkthrough.md
- [ ] **3. Test**: Pending → test-walkthrough.md

## Dependencies

### Requires
- `013-user-preferences-service` (needs the real endpoint contract — currently blocked)

### Enables
- None (terminal bolt for this intent)

## Success Criteria

- [ ] All 4 settings viewable/editable from one screen
- [ ] Logout clears session and returns to sign-in, unreachable afterward without re-signing-in
- [ ] No regression to any existing screen

## Notes

Blocked on `013-user-preferences-service` completing first — same discipline as `012-match-pairs-ui` waiting on `011-match-pairs-service`: build against the real contract, not a guessed one.
