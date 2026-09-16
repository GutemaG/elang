---
stage: implement
bolt: 010-offline-caching-and-sync-ui
created: '2026-09-17T02:00:00Z'
---

## Implementation Walkthrough: Offline Caching & Sync UI (part 2)

### Summary

Offline-completed lessons now queue locally and sync automatically, in completion order, once connectivity returns -- with capped exponential backoff on failure. The skill-tree dashboard shows a connectivity/sync indicator and a download-management screen for deleting cached packs. Also fixed a real leak from bolt 009: deleting a downloaded pack never actually freed its audio files from disk.

### Structure Overview

New model `PendingSyncEntry` + `DownloadedPackSummary`. New services `PendingSyncQueueStore` (interface + `SqflitePendingSyncQueueStore`, own db file) and `SyncEngine` (`ChangeNotifier`, owns the queue store internally, drains it strictly in order). Everything else is threading these through the existing dependency chain plus targeted extensions to `LessonController`/`LessonCompleteScreen`/`LessonPackStore`, and two new small screens/widgets (`SyncStatusBanner`, `DownloadManagementScreen`).

### Completed Work

- [x] `lib/shared/models/pending_sync_entry.dart`, `downloaded_pack_summary.dart` (new)
- [x] `lib/shared/services/pending_sync_queue_store.dart` (new) -- `PendingSyncQueueStore` + `SqflitePendingSyncQueueStore`
- [x] `lib/shared/services/sync_engine.dart` (new) -- `SyncEngine`, `SyncStatus` enum
- [x] `lib/shared/models/lesson_completion_result.dart` -- `pendingSync` field + `kXpPerCorrectAnswer` constant
- [x] `lib/features/lesson/state/lesson_controller.dart` -- `syncEngine`/`startedOffline` params; `_finishLesson()` branches on `startedOffline` (fixed at construction, never re-checked)
- [x] `lib/features/lesson/screens/lesson_screen.dart` -- captures `_startedOffline` in `_loadLessonContent()`, threads it + `syncEngine` into `LessonController`
- [x] `lib/features/lesson/screens/lesson_complete_screen.dart` -- pending-sync variant: exact XP/accuracy, "syncs when back online" for streak/daily-goal, no level-up modal
- [x] `lib/shared/services/lesson_pack_store.dart` -- `listDownloadedPacks()`; `delete()` now also deletes each downloaded audio file (bug fix)
- [x] `lib/features/lesson/widgets/sync_status_banner.dart` (new) -- dashboard-only indicator, 5 states + 30-day escalation
- [x] `lib/features/lesson/screens/download_management_screen.dart` (new) -- list/delete with pending-sync-aware confirmation
- [x] `lib/features/lesson/screens/skill_tree_dashboard_screen.dart` -- banner + manage-downloads button; `syncEngine.refresh()` on load
- [x] `lib/features/lesson/lesson_dependencies.dart`, `lib/main.dart` -- wire `syncEngine`
- [x] Test helpers: `fake_pending_sync_queue_store.dart` (new); `FakeLessonPackStore` gained `listDownloadedPacks()`; `controllable_lesson_api.dart` unchanged (already had what was needed)
- [x] Fixed a pre-existing test-viewport regression this bolt's dashboard layout change exposed: `skill_tree_dashboard_screen_test.dart`'s "tapping the active node" test now scrolls the target node into view before tapping (the new banner/button row pushes lower nodes further down)

### Key Decisions

- **`startedOffline` fixed once at lesson load, never re-checked at completion** -- directly satisfies FR-2's "doesn't switch modes mid-attempt" edge case. Verified with a test that flips connectivity online mid-lesson and confirms the completion still queues rather than calling the network directly.
- **Pending-sync completion shows exact XP/accuracy, "syncs when back online" for streak/daily-goal** -- avoids duplicating server streak/crown-progression logic client-side; only `XP_PER_CORRECT_ANSWER` (a stable domain constant) is mirrored.
- **`SyncEngine` owns its `PendingSyncQueueStore` internally** -- nothing else touches the store directly, so queue mutation and sync-triggering stay in one place.
- **Draining is strictly sequential, one entry at a time, stopping at the first failure** -- required by FR-3's completion-order guarantee; a parallel or skip-ahead drain would violate it.
- **Backoff base/cap are constructor-injectable** (defaults 5s/60s) specifically so tests can use millisecond-scale delays instead of waiting on real 5-60s timers.
- **The indicator lives only on the dashboard**, never on `LessonScreen` -- satisfies "never interrupts an active lesson" by construction.

### Deviations from Plan

None. Both plan-flagged UX calls (pending-sync screen treatment, dashboard-only indicator placement) were implemented exactly as proposed and confirmed.

### Bug Fixes (found during this bolt, not pre-planned)

- `SqfliteLessonPackStore.delete()` (from bolt 009) never deleted downloaded audio files, only the DB row -- required for story 005's "delete frees the reported storage" criterion, fixed here.
- A pre-existing dashboard test (`skill_tree_dashboard_screen_test.dart`) assumed no scrolling was needed to tap a node -- broke once this bolt's banner/button row reduced the visible viewport in the fixed-size test window. Fixed by scrolling the target into view first.

### Developer Notes

- `SyncEngine`'s `isOnline`/`pendingCount`/`status`/`oldestPendingAge` are all cached and synchronous -- kept fresh by subscribing to `ConnectivityMonitor.onConnectivityChanged` once at construction, so `SyncStatusBanner` never needs its own connectivity subscription.
- `flutter analyze`: clean except pre-existing `prefer_initializing_formals` info-lints (1 pre-existing + 3 new, same style already tolerated in this codebase for constructor params that can't use an initializing formal because the field is private but the param must stay public).
- Full suite re-run after every change: 118/119 passing (the 1 failure is the pre-existing `e2e`-tagged backend-integration test, unrelated to and unchanged by this bolt).
