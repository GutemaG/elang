---
intent: 003-offline-caching-and-sync
created: 2026-09-16T19:00:00Z
completed: 2026-09-16T21:15:00Z
status: complete
---

# Inception Log: 003-offline-caching-and-sync

## Overview

**Intent**: Downloadable lesson packs for full offline lesson-taking, plus reliable sync of Beans/streak/XP changes made offline back to the server ledger once connectivity returns. Chosen as intent 003 after confirming 001-auth-onboarding and 002-core-lesson-loop are both fully complete (18/18 stories) with nothing left unfinished — this is genuinely new scope, not resumed work, addressing the "offline-first from the start" risk `docs/PLANNING.md` calls out and the streak/beans sync gap neither prior intent covered.
**Type**: green-field
**Created**: 2026-09-16

## Artifacts Created

| Artifact | Status | File |
|----------|--------|------|
| Requirements | ✅ | requirements.md |
| System Context | ✅ | system-context.md |
| Units | ✅ | units.md, units/001-offline-sync-service/unit-brief.md, units/002-offline-caching-and-sync-ui/unit-brief.md |
| Stories | ✅ | units/001-offline-sync-service/stories/*.md (3), units/002-offline-caching-and-sync-ui/stories/*.md (5) |
| Bolt Plan | ✅ | memory-bank/bolts/008-offline-sync-service/bolt.md, memory-bank/bolts/009-offline-caching-and-sync-ui/bolt.md, memory-bank/bolts/010-offline-caching-and-sync-ui/bolt.md |

## Summary

| Metric | Count |
|--------|-------|
| Functional Requirements | 6 |
| Non-Functional Requirements | 2 (Performance, Reliability) + Data |
| Units | 2 |
| Stories | 8 |
| Bolts Planned | 3 |

## Units Breakdown

| Unit | Stories | Bolts | Priority |
|------|---------|-------|----------|
| 001-offline-sync-service | 3 | 1 (008-offline-sync-service) | Must |
| 002-offline-caching-and-sync-ui | 5 | 2 (009-offline-caching-and-sync-ui, 010-offline-caching-and-sync-ui) | Must |

## Decision Log

| Date | Decision | Rationale | Approved |
|------|----------|-----------|----------|
| 2026-09-16 | Scoped "offline caching" and "Beans/streak sync" as one combined intent rather than two separate ones | A downloadable pack with nothing to sync back, or a sync mechanism with nothing cached to sync offline, has no standalone value — they're two halves of the same capability | Yes |
| 2026-09-16 | Selected "full offline mode" (downloadable packs + true offline lesson-taking + sync) over a narrower "resilience only" scope (robustness to flaky connectivity, no true offline mode) | Explicit user choice when presented both options; matches `docs/PLANNING.md`'s "offline-first from the start, not retrofitted later" call-out and is the higher-value piece of work | Yes |
| 2026-09-16 | Reuses `002-core-lesson-loop`'s ADR-5 (client-side grading + `attemptId` idempotency) for offline completions instead of a new grading/sync path | Avoids a second grading implementation; the online completion endpoint is already idempotent, which is exactly what deferred/retried offline sync needs | Yes |
| 2026-09-16 | Multi-device concurrent offline conflict resolution declared an explicit non-goal | Neither `001-auth-onboarding` nor `002-core-lesson-loop` support concurrent multi-device sessions; adding that here would be new cross-cutting scope, not an offline-specific concern | Yes |
| 2026-09-16 | Resolved all 3 requirements Open Questions: (1) lesson pack staleness window = 14 days, re-checked opportunistically only when online; (2) pending-sync queue has no size/time cap (entries are lightweight metadata, not full content); (3) skill-tree unlock state shown offline is limited to what was already downloaded/loaded before going offline | User picked "2 weeks to a month" for (1) — settled on the lower bound to keep content fresher; delegated (2) to engineering judgment — chose "never drop, no cap" since correctness (never lose progress) matters more than the negligible storage cost of small queue entries, consistent with FR-3's "never silently drops" AC; user explicitly chose the conservative option for (3) | Yes |

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
- [x] Human review complete (Checkpoint 3 approved 2026-09-16)

## Next Steps

**Approved.** Proceeding to Construction.

1. Begin Construction Phase
2. Start with Unit: `001-offline-sync-service`
3. Execute: `/specsmd-construction-agent --unit="001-offline-sync-service"`

## Dependencies

Depends on `002-core-lesson-loop` (needs the lesson content/exercise engine, Beans/streak/XP tables, and ADR-5's client-side-grading + `attemptId` idempotency model already in place) — complete.
