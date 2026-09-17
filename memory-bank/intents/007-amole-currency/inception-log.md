---
intent: 007-amole-currency
created: '2026-09-17T16:00:00Z'
completed: '2026-09-17T16:35:00Z'
status: complete
---

# Inception Log: amole-currency

## Overview

**Intent**: Give Amole a real earn side (it currently only depletes from a one-time grant), plus a proper ledger and a dashboard display.
**Type**: brown-field — amends bolt `005-lesson-engagement-service`'s shipped `UserBeans`/`complete_lesson`/refill code, does not build it from scratch.
**Created**: 2026-09-17

## Artifacts Created

| Artifact | Status | File |
|----------|--------|------|
| Requirements | ✅ | requirements.md |
| System Context | ✅ | system-context.md |
| Units | ✅ | units/{unit-name}/unit-brief.md |
| Stories | ✅ | units/{unit-name}/stories/*.md |
| Bolt Plan | ✅ | memory-bank/bolts/017-amole-service/bolt.md, memory-bank/bolts/018-amole-ui/bolt.md |

## Summary

| Metric | Count |
|--------|-------|
| Functional Requirements | 5 |
| Non-Functional Requirements | 3 (Consistency, Reliability, Migration Safety) |
| Units | 2 |
| Stories | 3 |
| Bolts Planned | 2 |

## Units Breakdown

| Unit | Stories | Bolts | Priority |
|------|---------|-------|----------|
| 001-amole-service | 2 | 1 (017-amole-service) | Must |
| 002-amole-ui | 1 | 1 (018-amole-ui) | Must |

## Decision Log

| Date | Decision | Rationale | Approved |
|------|----------|-----------|----------|
| 2026-09-17 | Corrected scope after reading real source: most of the original build prompt's "001-amole-service" (spend endpoint, insufficient-balance rejection) and all of "002-amole-ui" (modal retrofit) were already shipped in bolt `005-lesson-engagement-service`/`007-core-lesson-loop-ui`. Real gap is narrower: award triggers, a ledger, and a dashboard display. | Verified by reading `backend/app/domain/lesson/entities.py`, `lesson_use_cases.py`, `lib/features/lesson/widgets/out_of_beans_sheet.dart`, `beans_status.dart` directly before writing requirements | Yes |
| 2026-09-17 | Introduce a proper `amole_transactions` ledger table, replacing the existing mutable `amole_balance` column, rather than just adding award logic onto the column | User's explicit Checkpoint 1 choice — also corrected the original prompt's assumption that an `xp_transactions` ledger pattern already exists to mirror (it doesn't; XP is `SUM(lesson_attempts.xp_awarded)`) | Yes |
| 2026-09-17 | Proceed with intent `008-srs-and-practice` next despite its larger-than-assumed true scope | User's explicit Checkpoint 1 choice | Yes |
| 2026-09-17 | 2 units, backend (`001-amole-service`, ddd, amends shipped aggregate) / frontend (`002-amole-ui`, simple, dashboard-only) | Mirrors this project's established backend/frontend split pattern; frontend unit is much smaller than the original prompt assumed since the modal work is already done | Yes |

## Scope Changes

| Date | Change | Reason | Impact |
|------|--------|--------|--------|
| 2026-09-17 | Reduced `002-amole-ui`'s scope from "retrofit the out-of-Beans modal" to "add a dashboard balance display only" | The modal already correctly implements the spend option and disabled/insufficient state (verified by reading `out_of_beans_sheet.dart`) | Smaller bolt, no modal changes needed |
| 2026-09-17 | Expanded `001-amole-service`'s scope from "add an amole_transactions table if not already migrated" to "replace the existing balance column with one, including a data-preserving migration and a retrofit of shipped spend/balance code" | No ledger table existed at all; the existing balance is a plain column on `user_beans` | Bolt `017` is a shipped-code amendment, not additive-only — treated with DDD rigor accordingly |

## Ready for Construction

**Checklist**:
- [x] All requirements documented
- [x] System context defined
- [x] Units decomposed
- [x] Stories created for all units
- [x] Bolts planned
- [x] Human review complete

No external precondition blocks this intent (unlike `006`) — both bolts (`017-amole-service`, `018-amole-ui`) are ready to start Construction whenever the user says so.

## Next Steps

1. Start Construction on `017-amole-service` (no blocker) when the user is ready.
2. Then `018-amole-ui`.
3. Do not auto-start either bolt on a generic "continue" — confirm which bolt the user wants started next.

## Dependencies

Amends `005-lesson-engagement-service` and `006-core-lesson-loop-ui`/`007-core-lesson-loop-ui`. Sequenced before `008-srs-and-practice` by user preference.
