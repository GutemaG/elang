---
intent: 005-profile-and-settings
phase: inception
status: units-decomposed
updated: '2026-09-17T07:45:00Z'
---

# Profile & Settings - Unit Decomposition

## Units Overview

Mirrors the backend-service + frontend-UI split used by every prior multi-unit intent in this project (`002-core-lesson-loop`, `003-offline-caching-and-sync`, `004-match-pairs-exercise-type`).

### Unit 1: 001-user-preferences-service

**Description**: Amends `001-auth-service`'s `User` aggregate with a new, explicit way to change `selected_language`/`daily_xp_target` post-creation, plus a new `notification_enabled` preference field.

**Requirements**: FR-2, FR-3, FR-4

**Deliverables**:
- Deliberate amendment of the "written exactly once" invariant (formally documented — likely ADR-worthy)
- New endpoint accepting preference updates
- `notification_enabled` field (stored, not yet wired to any delivery mechanism)

**Dependencies**:
- Depends on: none (extends existing `001-auth-service` code from `001-auth-onboarding`)
- Depended by: `002-profile-and-settings-ui`

**Estimated Complexity**: M (amending a documented aggregate invariant deserves real design care, unlike `004-match-pairs-exercise-type`'s purely additive backend unit)

### Unit 2: 002-profile-and-settings-ui

**Description**: Flutter Settings screen — view/edit language, daily goal, notification toggle (via Unit 1's endpoint); sound toggle (client-local, gates the existing `AnswerFeedbackPlayer`); logout (reuses existing `SessionRepository.clearSession()`).

**Requirements**: FR-1, FR-5, FR-6

**Deliverables**:
- New `lib/features/settings/` feature tree (first new top-level feature folder since `auth`/`lesson`)
- Settings screen (view + edit goal/language/notification + sound toggle)
- Logout action

**Dependencies**:
- Depends on: `001-user-preferences-service` (needs the real endpoint contract for goal/language/notification edits)
- Depended by: none

**Estimated Complexity**: S

## Unit Dependency Graph

```text
[001-user-preferences-service] ──> [002-profile-and-settings-ui]
```

## Execution Order

1. `001-user-preferences-service` (backend invariant amendment + endpoint)
2. `002-profile-and-settings-ui` (client screen + sound toggle + logout)
