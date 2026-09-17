---
intent: 005-profile-and-settings
created: '2026-09-17T04:00:00Z'
completed: '2026-09-17T08:00:00Z'
status: complete
---

# Inception Log: profile-and-settings

## Overview

**Intent**: Build the Profile & Settings screen (language preference, daily goal, notification toggle, sound toggle, logout) — explicit original scope, never built.
**Type**: green-field UI (new `lib/features/settings/`) + brown-field backend (amends `001-auth-service`)
**Created**: 2026-09-17

## Artifacts Created

| Artifact | Status | File |
|----------|--------|------|
| Requirements | ✅ | requirements.md |
| System Context | ✅ | system-context.md |
| Units | ✅ | units/{unit-name}/unit-brief.md |
| Stories | ✅ | units/{unit-name}/stories/*.md |
| Bolt Plan | ✅ | memory-bank/bolts/013-user-preferences-service/bolt.md, memory-bank/bolts/014-profile-and-settings-ui/bolt.md |

## Summary

| Metric | Count |
|--------|-------|
| Functional Requirements | 6 |
| Non-Functional Requirements | 1 (security: existing session-token auth reused) |
| Units | 2 |
| Stories | 4 |
| Bolts Planned | 2 |

## Units Breakdown

| Unit | Stories | Bolts | Priority |
|------|---------|-------|----------|
| 001-user-preferences-service | 2 | 1 (013-user-preferences-service) | Must |
| 002-profile-and-settings-ui | 2 | 1 (014-profile-and-settings-ui) | Must |

## Decision Log

| Date | Decision | Rationale | Approved |
|------|----------|-----------|----------|
| 2026-09-17 | Sequenced second of 3 gap-closing intents, after 004-match-pairs-exercise-type and before 006-speak-check-exercise-type | User's stated build order; unrelated to either exercise-type intent so has no hard dependency on either | Yes |
| 2026-09-17 | Editing language/daily-goal IS in scope for v1 (not read-only), requiring a new backend endpoint and a deliberate amendment of `User`'s "written exactly once" invariant | User's explicit choice at Checkpoint 1, after Construction verified the invariant/gap by reading `entities.py` directly | Yes |
| 2026-09-17 | No profile/name/avatar UI — Settings-only, since the domain model has no such fields | User's explicit choice at Checkpoint 1 | Yes |
| 2026-09-17 | Notification toggle: stored server-side now, functionally inert until a real notification system exists; sound toggle: client-local and fully functional immediately (gates the existing `AnswerFeedbackPlayer`) | User's explicit choice (notification) + Construction's technical reasoning (sound needs no server/cross-device sync and can be fully real today) | Yes |
| 2026-09-17 | Decomposed into 2 units mirroring the existing backend-service + frontend-UI split | Consistency with every prior multi-unit intent in this project | Yes |

## Scope Changes

| Date | Change | Reason | Impact |
|------|--------|--------|--------|

## Ready for Construction

**Checklist**:
- [x] All requirements documented
- [x] System context defined
- [x] Units decomposed
- [x] Stories created for all units
- [x] Bolts planned
- [x] Human review complete

## Next Steps

1. Begin Construction Phase
2. Start with Unit: `001-user-preferences-service`
3. Execute: `/specsmd-construction-agent --unit="001-user-preferences-service"`

## Dependencies

Depends on `001-auth-onboarding` (logout, session; daily-goal/language values originally set during onboarding). No hard dependency on `004-match-pairs-exercise-type` or `006-speak-check-exercise-type`; sequenced between them per user preference, not technical necessity.
