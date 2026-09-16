---
unit: 001-offline-sync-service
intent: 003-offline-caching-and-sync
created: '2026-09-16T21:00:00Z'
last_updated: '2026-09-17T00:30:00Z'
---

# Construction Log: Offline Sync Service

## Original Plan

**From Inception**: 1 bolt planned
**Planned Date**: 2026-09-16

| Bolt ID | Stories | Type |
|---------|---------|------|
| 008-offline-sync-service | 001, 002, 003 | ddd-construction-bolt |

## Replanning History

| Date | Action | Change | Reason | Approved |
|------|--------|--------|--------|----------|

## Current Bolt Structure

| Bolt ID | Stories | Status | Changed |
|---------|---------|--------|---------|
| 008-offline-sync-service | 001, 002, 003 | ✅ complete | - |

## Execution History

| Date | Bolt | Event | Details |
|------|------|-------|---------|
| 2026-09-16T21:30:00Z | 008-offline-sync-service | stage-complete | Domain Model → Technical Design |
| 2026-09-16T21:45:00Z | 008-offline-sync-service | stage-complete | Technical Design → ADR Analysis |
| 2026-09-16T22:00:00Z | 008-offline-sync-service | stage-complete | ADR Analysis → Implement (ADR-6: no batch-sync endpoint) |
| 2026-09-16T22:30:00Z | 008-offline-sync-service | stage-complete | Implement → Test (242/242 backend tests passing, `ruff` clean) |
| 2026-09-16T23:15:00Z | 008-offline-sync-service | completed | All 5 stages done; unit and bolt marked complete |
| 2026-09-17T00:30:00Z | 008-offline-sync-service | errata-fix | Migration `e3cea3ee5c84`'s "verified against real SQLite" claim was wrong -- `alembic upgrade head` actually failed (`sa.func.now()` compiles to a non-constant `CURRENT_TIMESTAMP` default, which SQLite's `ALTER TABLE ADD COLUMN` rejects when combined with `NOT NULL`). Found while migrating for bolt 009. Fixed by switching to a fixed constant default; re-verified upgrade/downgrade/upgrade against real `dev.db` and the full 242-test backend suite. |

## Execution Summary

| Metric | Value |
|--------|-------|
| Original bolts planned | 1 |
| Current bolt count | 1 |
| Bolts completed | 1 |
| Bolts in progress | 0 |
| Bolts remaining | 0 |
| Replanning events | 0 |

## Notes

Amended `002-core-lesson-loop`'s existing `001-lesson-service` endpoints (bolts 004/005) rather than building a new service, per this unit's own framing. One notable deviation from Technical Design, discovered during Implement (source code is off-limits until that stage in this project's DDD process): no new `client_completed_at` column was needed on `lesson_attempts` -- the existing `completed_at` column was already exactly that field, so the amendment just changed what value populates it (the client-supplied timestamp instead of server-arrival time) rather than adding a column. Content-version signal derived from `updated_at` columns added to `lessons`/`exercises` (not `skills` -- version is scoped to lesson/exercise content per the Technical Design's own wording), via 2 grouped aggregate queries (no N+1; the existing skill-tree query-count performance test's budget was explicitly raised 6→8 with the reasoning documented in the test itself). ADR-6 records the "no batch-sync endpoint" decision. Full suite (242/242) and `ruff check` re-run clean; `mypy`'s one reported error is pre-existing (confirmed via `git stash` diff), not introduced here.
