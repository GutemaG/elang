---
unit: 002-offline-caching-and-sync-ui
intent: 003-offline-caching-and-sync
created: '2026-09-16T21:00:00Z'
last_updated: '2026-09-17T03:30:00Z'
---

# Construction Log: Offline Caching & Sync UI

## Original Plan

**From Inception**: 2 bolts planned
**Planned Date**: 2026-09-16

| Bolt ID | Stories | Type |
|---------|---------|------|
| 009-offline-caching-and-sync-ui | 001, 002 | simple-construction-bolt |
| 010-offline-caching-and-sync-ui | 003, 004, 005 | simple-construction-bolt |

## Replanning History

| Date | Action | Change | Reason | Approved |
|------|--------|--------|--------|----------|

## Current Bolt Structure

| Bolt ID | Stories | Status | Changed |
|---------|---------|--------|---------|
| 009-offline-caching-and-sync-ui | 001, 002 | ✅ complete | - |
| 010-offline-caching-and-sync-ui | 003, 004, 005 | ✅ complete | - |

## Execution History

| Date | Bolt | Event | Details |
|------|------|-------|---------|
| 2026-09-16T23:30:00Z | 009-offline-caching-and-sync-ui | stage-complete | Plan → Implement (`sqflite`/`path_provider`/`connectivity_plus` chosen; 14-day staleness check and offline-completion queueing explicitly deferred to bolt 010) |
| 2026-09-16T23:50:00Z | 009-offline-caching-and-sync-ui | stage-complete | Implement → Test (89/89 Flutter tests passing, `flutter analyze` clean) |
| 2026-09-17T00:20:00Z | 009-offline-caching-and-sync-ui | stage-complete | Test → complete (99/100 Flutter tests passing -- the 1 failure is a pre-existing `e2e`-tagged test needing a live backend, unrelated to this bolt) |
| 2026-09-17T00:30:00Z | 009-offline-caching-and-sync-ui | completed | Both stories done; bolt marked complete; bolt 010's `blocks` flag cleared |
| 2026-09-17T01:00:00Z | 010-offline-caching-and-sync-ui | stage-complete | Plan → Implement (`SyncEngine`/`PendingSyncQueueStore` design; `startedOffline` fixed at lesson-load time, not re-checked at completion; pending-sync summary shows exact XP/accuracy but "syncs when back online" for streak/daily-goal) |
| 2026-09-17T02:00:00Z | 010-offline-caching-and-sync-ui | stage-complete | Implement → Test (118/119 Flutter tests passing; fixed a bolt-009 audio-file-leak bug in `LessonPackStore.delete()` along the way) |
| 2026-09-17T02:45:00Z | 010-offline-caching-and-sync-ui | stage-complete | Test → complete (123/123 Flutter tests passing; 24 new tests added covering every story's acceptance criteria) |
| 2026-09-17T03:30:00Z | 010-offline-caching-and-sync-ui | physical-device-verification | Verified end-to-end on a real Android device (download → offline-take → pending-sync summary → reconnect → auto-sync → download management). Surfaced and fixed a real pre-existing bug: bolt 004's seeded listening-exercise `audio_url` used a non-resolving placeholder host, so every download failed on-device until fixed (see errata in unit `001-lesson-service`'s construction-log.md, intent `002-core-lesson-loop`) |
| 2026-09-17T03:30:00Z | 010-offline-caching-and-sync-ui | completed | All 3 stories done; bolt and unit marked complete |

## Execution Summary

| Metric | Value |
|--------|-------|
| Original bolts planned | 2 |
| Current bolt count | 2 |
| Bolts completed | 2 |
| Bolts in progress | 0 |
| Bolts remaining | 0 |
| Replanning events | 0 |

## Notes

Bolt 009 delivered "download a skill, take its lessons offline" end-to-end: 3 new plugin-boundary services (`ConnectivityMonitor`, `LessonPackStore`, `LessonPackDownloader`), each following this codebase's existing interface + real-impl + `Fake*` test-double pattern, plus a download affordance on the skill-tree dashboard and an offline branch on the lesson screen. Also fixed a real, otherwise-breaking gap discovered during Implement: `HttpLessonApi.completeLesson` wasn't sending `client_completed_at`, which bolt 008 had made required backend-side -- the app would have been broken against the real backend without this fix.

Two things were deliberately scoped out of this bolt, per its implementation-plan.md, and remain open for bolt 010 (or a follow-up):
- The 14-day pack-staleness re-check (FR-1) -- `content_version` is stored and threaded through, but nothing compares it yet.
- Completing a lesson while genuinely offline still calls the network endpoint directly (and fails) rather than queuing -- there's no local queue to feed until story 003 exists. Only the *online* completion path (with the now-required `client_completed_at`) was wired correctly in this bolt.

While migrating for this bolt's work, discovered bolt 008's Alembic migration (`e3cea3ee5c84`) was actually broken against real SQLite despite that bolt's test report claiming otherwise -- `server_default=sa.func.now()` compiles to `CURRENT_TIMESTAMP`, which SQLite's `ALTER TABLE ADD COLUMN` rejects when combined with `NOT NULL`. Fixed by switching to a fixed constant default; see the errata entry in unit 001's construction-log.md and the corrected `ddd-03-test-report.md` for bolt 008.

Test stage also caught a self-inflicted test bug: two new dashboard tests deadlocked because they awaited `FakeLessonApi.startLesson()` before `pumpWidget` -- under `testWidgets`, `Future.delayed` never fires until something pumps the fake clock. Fixed by building the test fixture directly instead of routing it through the api.
