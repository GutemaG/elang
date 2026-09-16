---
stage: plan
bolt: 010-offline-caching-and-sync-ui
created: '2026-09-17T01:00:00Z'
---

## Implementation Plan: Offline Caching & Sync UI (part 2)

### Objective

Deliver stories 003 (pending-sync queue + auto-sync), 004 (connectivity/sync status indicator), and 005 (download-management screen) — the terminal bolt for `002-offline-caching-and-sync-ui` and for the whole `003-offline-caching-and-sync` intent. Story 005 is `Could`-priority; flagged for possible descoping if Implement reveals it doesn't fit, per this bolt's own `bolt.md` Notes, but planned in for now.

### Deliverables

**New model** (`lib/shared/models/pending_sync_entry.dart`):
- `PendingSyncEntry` — exactly the fields `LessonApi.completeLesson` needs (`attemptId`, `lessonId`, `correctCount`, `totalCount`, `timeSpent`, `beansRemainingAtEnd`, `clientCompletedAt`), matching the unit-brief's `PendingSyncEntry` domain concept. `clientCompletedAt` doubles as "when this was queued" — no separate `queuedAt` field needed, since a lesson offline-completion is queued at the exact instant it's completed.

**New services** (plugin-boundary interface + real impl + `Fake*`, same established pattern):
- `PendingSyncQueueStore` (`pending_sync_queue_store.dart`): `enqueue`, `listPending` (FIFO/completion order), `remove(attemptId)`, `count`. Real impl (`SqflitePendingSyncQueueStore`) uses its own `sqflite` table/file (`pending_sync_queue.db`) — kept separate from `LessonPackStore`'s `lesson_packs.db` since the two stores have no schema relationship.
- `SyncEngine` (`sync_engine.dart`, a `ChangeNotifier`): owns a `PendingSyncQueueStore` internally (callers never touch the store directly). Public surface:
  - `Future<void> enqueueOfflineCompletion(PendingSyncEntry entry)` — the only way anything enqueues; immediately attempts a sync afterward if online.
  - `Future<void> refresh()` — call once at app/dashboard start-up: loads `pendingCount`, and if online, attempts to drain. Covers "entries queued from a previous session survive app restart and still sync."
  - `Future<void> syncNow()` — drains the queue in FIFO order, one entry at a time (never reordered, never parallel). Stops at the first failure (leaves the rest queued — draining out of order would violate FR-3's ordering requirement) and schedules an exponential-backoff retry (`5s, 10s, 20s, ... capped at 60s`, reset to `5s` on the next success or connectivity transition). Skips attempting entirely (no call, no backoff churn) whenever `connectivityMonitor.isOnline()` is false at retry time.
  - `bool get isOnline`, `int get pendingCount`, `SyncStatus get status` (`idle | syncing | failed`), `Duration? get oldestPendingAge` (age of the head-of-queue entry, for FR-3's 30-day escalation) — all cached/synchronous, kept fresh by subscribing to `connectivityMonitor.onConnectivityChanged` once at construction (mirrors `LessonPackDownloader`'s existing lazy-refresh pattern).

**Threaded through existing code**:
- `LessonController` gains `required SyncEngine syncEngine` and `required bool startedOffline` (the online/offline decision `LessonScreen` already made once at lesson start via `ConnectivityMonitor.isOnline()` in `_loadLessonContent`). `_finishLesson()` branches on `startedOffline`, **not** a fresh connectivity check at completion time — this is deliberate: FR-2's edge case says a lesson "does not switch modes mid-attempt" even if connectivity returns while it's in progress, so the mode is fixed once, at load time.
  - `startedOffline == false` (today's path, unchanged): calls `lessonApi.completeLesson(...)` directly.
  - `startedOffline == true`: builds a `PendingSyncEntry` from the same values that call would have sent, calls `syncEngine.enqueueOfflineCompletion(entry)`, and sets a **pending-sync** completion result instead of a server-confirmed one (see below) — never calls the network endpoint at all.
- `LessonScreen`: passes `syncEngine` through and threads the `startedOffline` bool (the same `online` local variable `_loadLessonContent` already computes) into `LessonController`'s constructor.
- `LessonCompletionResult` gains `pendingSync = false` (default). When `true`: `xpEarned` is still shown (computed locally as `correctCount * kXpPerCorrectAnswer` — a small new public constant documented as mirroring the backend's `XP_PER_CORRECT_ANSWER`, the one piece of server business logic simple and stable enough to duplicate; see Checkpoint Decisions) and `accuracyPercent`/`correctCount`/`totalCount`/`timeSpent` are exact (client-known). `dailyXpTotal`, `dailyXpTarget`, `streakCount`, `streakIncreasedToday`, and any crown/unlock fields are **not** knowable client-side without duplicating the server's streak/crown-progression rules, so they're left at safe defaults and `LessonCompleteScreen` hides/relabels those specific cards when `pendingSync` — see next bullet.
- `LessonCompleteScreen`: when `result.pendingSync`, the streak and daily-goal-progress cards render "Syncs when back online" in place of a specific number (no `+1 Today` badge, no level-up sheet — that flourish is deferred to whenever the entry actually syncs, which this bolt doesn't surface a moment for). XP-earned and accuracy cards render normally since those are exact.
- `SkillTreeDashboardScreen`: gains a `SyncStatusBanner` (new small widget, `lib/features/lesson/widgets/sync_status_banner.dart`) shown once near the top (next to `LessonHud`), and a plain icon button opening the new `DownloadManagementScreen`. `initState` calls `syncEngine.refresh()` (mirrors the existing `refreshDownloadedStatuses()` call added in bolt 009).
- `LessonPackStore` gains two members needed by story 005, without any schema change (still one JSON-blob table from bolt 009):
  - `Future<List<DownloadedPackSummary>> listDownloadedPacks()` — a new small model (`lessonId`, `title`, `approximateSizeBytes`), built by loading each downloaded pack's already-small JSON (title) and summing its listening exercises' local audio file sizes (`File(audioUrl).length()`) plus the JSON blob's own byte length. No directory scan, no new schema.
  - **Bug fix**: `SqfliteLessonPackStore.delete()` currently only removes the DB row — it never deletes the downloaded audio files from disk, so today every deletion silently leaks storage. Fixed to delete each `ListeningExercise.audioUrl` file (read from the pack before deleting the row) — this is exactly what story 005's "deleting frees the reported storage" acceptance criterion requires, so it can't ship without this fix regardless.
- `DownloadManagementScreen` (new): lists `listDownloadedPacks()`, shows title + approximate size, per-item delete with a confirmation dialog. If `syncEngine`'s queue has any entry whose `lessonId` matches the pack being deleted, the confirmation dialog's copy changes to the explicit pending-sync warning from story 005's AC (still allows deletion — the warning is informational, not blocking, per that story's own resolution: "deleting the pack doesn't touch the sync queue").
- `LessonDependencies`: wires `pendingSyncQueueStore`/`syncEngine` defaults, same optional-override pattern as the existing services.
- `main.dart`: threads `syncEngine` to `SkillTreeDashboardScreen` and wires the new `DownloadManagementScreen` route.

### Dependencies

- `009-offline-caching-and-sync-ui` (complete): `ConnectivityMonitor`, `LessonPackStore`, `LessonController`/`LessonScreen`'s offline-loading branch — extended, not replaced.
- `001-offline-sync-service` (bolt 008, complete): the same `completeLesson` endpoint (idempotent on `attemptId`, timestamp-validated) is replayed once per queued entry — no batch endpoint, per that unit's ADR-6.

### Technical Approach

- **No new dependencies** — `sqflite`/`connectivity_plus`/`path_provider` from bolt 009 cover everything this bolt needs.
- **One queue, drained strictly in order, one entry at a time.** Parallel or reordered draining would break FR-3's "sync in completion order" requirement outright, so `syncNow()` is intentionally simple: loop, await each call, stop on first failure.
- **Backoff is exponential with a cap, not unbounded** — prevents "connectivity flaps rapidly" (an explicit edge case) from turning into a retry storm, per FR-3/NFR wording ("automatic... exact retry/backoff schedule is a technical-design decision").
- **The lesson-complete screen's pending-sync numbers are a deliberate, narrow duplication of one constant** (`XP_PER_CORRECT_ANSWER`), not a second grading/business-logic implementation — streak, daily total, and crown progression are explicitly *not* recomputed client-side; they stay whatever the last-synced dashboard fetch showed until the real sync happens. This keeps the "no second grading implementation" constraint intact while still giving the user *something* concrete instead of a blank screen.
- **The 30-day escalation (FR-3's last AC) is recomputed whenever `SyncEngine` notifies listeners or the dashboard reloads** — not literally live-ticking on a running clock. At month-scale granularity this is indistinguishable to the user and avoids adding a periodic timer purely to re-render a warning banner.
- **The connectivity/sync indicator only appears on the skill-tree dashboard**, not on `LessonScreen` — satisfies story 004's "never interrupts the active exercise screen" edge case by construction (it's simply not present there) rather than needing suppression logic.

### Acceptance Criteria

- [ ] Offline-completed lessons queue locally and sync automatically, in completion order, once connectivity returns
- [ ] A synced entry is removed from the queue; a retried/duplicate send never double-applies (relies on the existing `attemptId` idempotency)
- [ ] A sync failure (server error, not just no connectivity) retries with capped exponential backoff, entry stays queued
- [ ] The queue survives app restart while offline and drains correctly once back online
- [ ] The dashboard shows one of: online/synced, offline (packs available), offline (nothing downloaded), syncing, sync-failed-retrying — and escalates visibly once unsynced for 30+ days
- [ ] The download-management screen lists downloaded packs with approximate size and deletes them (freeing real disk space, including audio files), with a pending-sync warning where relevant

### Checkpoint Decisions (flagged for visibility)

- **`startedOffline` fixed at lesson start, not re-checked at completion** — see Deliverables above; directly satisfies FR-2's "does not switch modes mid-attempt" edge case.
- **Pending-sync completion screen shows exact XP/accuracy but "syncs when back online" for streak/daily-goal** — a real UX call, not a slam-dunk default; flagging explicitly rather than silently picking numbers that might be wrong once the real sync lands.
- **`SqfliteLessonPackStore.delete()`'s audio-file-leak bug (from bolt 009) is fixed here**, as a required part of story 005's own acceptance criteria, not a separate unplanned fix.
- **No schema change to `LessonPackStore`'s table** — story 005's listing need is met by loading each small pack's existing JSON, not by adding a `title` column.
