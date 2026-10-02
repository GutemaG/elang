---
intent: 024-app-localization
created: '2026-10-02T19:06:01Z'
completed: '2026-10-02T19:15:40Z'
status: complete
---

# Inception Log: 024-app-localization

## Overview

**Intent**: Show the app's own words in English, Amharic or Afaan Oromo,
chosen by the learner, with more languages added as translation files.
**Type**: brown-field
**Created**: 2026-10-02T19:06:01Z

## Artifacts Created

| Artifact | Status | File |
|----------|--------|------|
| Requirements | ✅ | requirements.md |
| System Context | ✅ | requirements.md (held there, as in 021-023) |
| Units | ✅ | units.md, units/*/unit-brief.md |
| Stories | ✅ | in each unit brief |
| Bolt Plan | ✅ | memory-bank/bolts/077-081 |

## Summary

| Metric | Count |
|--------|-------|
| Functional Requirements | 10 |
| Non-Functional Requirements | 5 |
| Units | 3 |
| Stories | 16 |
| Bolts Planned | 5 |

## Units Breakdown

| Unit | Stories | Bolts | Priority |
|------|---------|-------|----------|
| 001-app-language-service | 1 | 1 | Must |
| 002-localization-foundation | 6 | 1 | Must |
| 003-screen-translations | 9 | 3 | Must |

## Decision Log

| Date | Decision | Rationale | Approved |
|------|----------|-----------|----------|
| 2026-10-02T19:06:01Z | English default, then the sign-up "I speak" language | A learner who picks "For Amharic speakers" most likely wants Amharic UI | Yes |
| 2026-10-02T19:06:01Z | Keep the choice on the phone and on the account | Works before sign-in, and follows the learner to a new phone | Yes |
| 2026-10-02T19:06:01Z | Claude drafts am/om text, native speaker reviews | Gets every screen translated now; quality checked before release | Yes |
| 2026-10-02T19:06:01Z | Run as an intent with bolts | Size: several hundred strings across every screen | Yes |
| 2026-10-02T19:10:38Z | Switching course never changes the app language | Only sign-up and Settings set it; no surprises | Yes |
| 2026-10-02T19:10:38Z | Translate the daily reminder | It is the app speaking to the learner | Yes |
| 2026-10-02T19:10:38Z | Gregorian dates, Western digits, local month/weekday names | Ethiopian calendar is a much larger piece of work | Yes |
| 2026-10-02T19:10:38Z | Ship am/om drafts with no beta label | User's call; review happens alongside | Yes |
| 2026-10-02T19:12:33Z | Requirements approved (Checkpoint 2) | - | Yes |
| 2026-10-02T19:12:33Z | Three units: backend field, app foundation, screen translations | The foundation and guards land before any screen moves | Yes |
| 2026-10-02T19:12:33Z | Untranslated-literal scan starts with an allow-list that the translation bolts empty | Lets the guard land first without translating every screen at once | Yes |
| 2026-10-02T19:15:40Z | Artifacts approved (Checkpoint 3); inception complete | - | Yes |
| 2026-10-02T19:20:00Z | App language is an account setting, not a column (bolt 077 plan) | `users.settings` and its endpoint already exist; no migration | Yes |

## Scope Changes

| Date | Change | Reason | Impact |
|------|--------|--------|--------|
| 2026-10-02T19:20:00Z | FR-6: account setting `app_language` instead of a `users.app_language` column | The settings registry (bolt 071) is the codebase's home for account preferences | No migration; no Neon step |

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
2. Start with Unit: 001-app-language-service
3. Execute: `/specsmd-construction-agent --unit="001-app-language-service"`

## Dependencies

077 (backend) -> 078 (foundation) -> 079 -> 080 -> 081 (translations)
