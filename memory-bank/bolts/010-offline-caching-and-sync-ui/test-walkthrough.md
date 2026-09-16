---
stage: test
bolt: 010-offline-caching-and-sync-ui
created: '2026-09-17T02:45:00Z'
---

## Test Walkthrough: Offline Caching & Sync UI (part 2)

### Summary

Full suite: **123/123 passing** (a live backend happened to be reachable this run, so the pre-existing `e2e`-tagged test passed too; that test is environment-dependent, not something this bolt controls). `flutter analyze`: clean except the same style of pre-existing `prefer_initializing_formals` info-lint already tolerated elsewhere in this codebase (1 pre-existing + 3 new, all for constructor params that can't use an initializing formal because the field is private but the param must stay public for cross-file construction).

### New/Extended Test Coverage

- [x] `test/shared/services/sync_engine_test.dart` (new, 10 tests): offline queuing defers sync; online enqueue syncs immediately; strict FIFO drain order; a failure stops draining and retries with backoff until success; `refresh()` drains leftovers from a previous session; `oldestPendingAge`; a failure partway through a drain (not the first entry) leaves only that entry and later ones queued, resuming with no duplication; rapid connectivity flapping doesn't spawn overlapping attempts (`_isSyncing` guard); a 30+ day-old entry still syncs normally, never silently dropped; `hasPendingEntriesForLesson`.
- [x] `test/features/lesson/widgets/sync_status_banner_test.dart` (new, 6 tests): online+synced renders nothing; offline distinguishes packs-available vs. nothing-downloaded; an actively-draining sync shows "syncing" (using a controllable in-flight call); a failure shows "retrying"; 30+ day escalation copy.
- [x] `test/features/lesson/screens/download_management_screen_test.dart` (new, 4 tests): empty state; lists title + approximate size; deleting with no pending sync shows the generic warning and removes the pack; deleting with a pending sync entry shows the distinct warning, and canceling leaves it in place.
- [x] `test/features/lesson/screens/lesson_screen_test.dart` (+2 tests): an offline completion queues instead of calling the network, showing the pending-sync summary; a lesson started offline still queues at completion even if connectivity returns mid-lesson (the "doesn't switch modes" edge case, verified against a failing api to prove the call went through the queue/engine, not a bypassing direct call).
- [x] `test/features/lesson/screens/lesson_complete_screen_test.dart` (+2 tests): pending-sync result shows exact XP/accuracy but "syncs when back online" copy for streak/daily-goal; never shows a level-up modal even with crown fields set.
- [x] `test/helpers/controllable_lesson_api.dart`: added `completeLessonGate` (hold a call in flight, for the "syncing" transient-state test) and `completeLessonFailingAttemptIds` (fail one specific queued entry without a single global flag affecting every call).

### Acceptance Criteria Validation

| Story | Criteria | Status |
|-------|----------|--------|
| 003 | Queued entries sync automatically, in completion order, on reconnect | ✅ `sync_engine_test.dart` |
| 003 | A synced entry is removed; a retried send of the same entry reuses the same `attemptId` (idempotency relies on this + `001-offline-sync-service`'s server-side guarantee) | ✅ "a failure stops draining..." asserts the same `attemptId` sent twice |
| 003 | A server-error failure retries with backoff, entry stays queued | ✅ |
| 003 | Connectivity dropping mid-drain resumes correctly, no lost/duplicated entry | ✅ "a failure partway through a drain..." |
| 003 | 30+ day escalation without ever auto-dropping | ✅ `sync_engine_test.dart` (never dropped) + `sync_status_banner_test.dart` (escalation copy) |
| 004 | online/synced, offline (packs/nothing), syncing, sync-failed states | ✅ all 5 covered in `sync_status_banner_test.dart` |
| 004 | Indicator never blocks interaction with downloaded content | ✅ by construction -- the banner isn't reachable from `LessonScreen` at all (not imported there) |
| 005 | Lists downloaded packs with approximate size; delete frees storage; pending-sync warning | ✅ `download_management_screen_test.dart` |

### Known, Accepted Gaps

- **`SqflitePendingSyncQueueStore` and the new `SqfliteLessonPackStore` methods (`listDownloadedPacks`, the `delete()` audio-cleanup fix) have no dedicated real-sqflite test** -- same deliberate scope decision bolt 009 made for `SqfliteLessonPackStore`'s original methods (testing against real `sqflite` needs `sqflite_common_ffi`, purely test infrastructure this project hasn't added). `SyncEngine`'s orchestration logic (the part that actually matters) is fully tested against `FakePendingSyncQueueStore`; `DownloadManagementScreen`'s logic is fully tested against `FakeLessonPackStore`. The real DB-backed SQL itself is unverified by tests, same risk profile as everything else built on that pattern so far.
- **The indicator doesn't literally debounce rapid connectivity flaps** -- story 004's edge case asks for this, but it wasn't in the implementation plan's scope and the underlying `SyncEngine` already prevents a retry storm (tested); a flapping *indicator* is a cosmetic flicker risk, not a functional one. Flagging rather than silently claiming full coverage.
- **Deleting a pack mid-lesson isn't explicitly handled or tested** -- the story itself leaves this as a Technical Design choice ("either disallowed or let it finish, must not crash"). Since `LessonController` holds its `LessonContent` by reference (never re-reads the store mid-attempt), an in-progress lesson is unaffected by a concurrent delete by construction -- safe, just not exercised by a dedicated test.

### Physical Device Verification

Verified on a real Android device (USB debugging + `adb reverse tcp:8000 tcp:8000`, per `README.md`'s documented pattern): download a skill's pack while online, go offline, take the downloaded lesson with zero network calls, complete it and see the pending-sync summary, reconnect and watch the dashboard banner sync and clear, open the download-management screen.

This surfaced one real, pre-existing bug (not introduced by this bolt): bolt 004's seeded listening-exercise `audio_url` used a non-resolving placeholder host (`r2-placeholder.buna.dev`), so every pack download failed outright on the real device the moment it tried to fetch audio -- `LessonPackDownloader`'s catch block was also silently swallowing the exception with no logging, so this took a debug-logging addition to actually diagnose. Fixed at the content layer (`seed_lesson_content.py` now points at a small, genuinely resolvable public placeholder MP3; re-ran the idempotent seed script) -- errata logged against bolt 004 / unit `001-lesson-service`'s construction-log, not this bolt's own scope. The debug-logging addition to `LessonPackDownloader`'s catch block is kept permanently (a silently-swallowed exception was a real diagnosability gap on its own).

### Verification

- `flutter analyze`: clean (info-lints only, pre-existing style)
- `flutter test`: 123/123 passing
- Physical device: download → offline-take → pending-sync summary → reconnect → auto-sync → download management, all confirmed working end-to-end
