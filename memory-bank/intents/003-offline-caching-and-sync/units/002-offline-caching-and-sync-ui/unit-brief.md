---
unit: 002-offline-caching-and-sync-ui
intent: 003-offline-caching-and-sync
phase: construction
status: complete
created: '2026-09-16T20:30:00Z'
updated: '2026-09-17T03:30:00Z'
unit_type: frontend
default_bolt_type: simple-construction-bolt
---

# Unit Brief: Offline Caching & Sync UI

## Purpose

Flutter client work that makes offline lesson-taking real: a download manager for lesson packs (content + audio), local storage for cached packs and a pending-sync queue, an offline-capable path through the existing exercise engine, a connectivity monitor + sync engine that drains the queue automatically on reconnect, a connectivity/sync status indicator, and a download-management screen.

## Scope

### In Scope
- Download manager UI + local pack storage (sqflite/drift), including the 14-day staleness re-check
- Offline path through `002-core-lesson-loop`'s existing `LessonController`/exercise screens
- Pending-sync queue (local storage, no size/time cap) + connectivity-aware sync engine
- Connectivity/sync status indicator (online/synced, offline w/ packs, offline w/ nothing downloaded, syncing, sync-failed)
- Download-management screen (list, size, delete)

### Out of Scope
- Any backend business logic (owned by `001-offline-sync-service`)
- A new/second grading implementation — reuses `002-core-lesson-loop`'s existing client-side grading exactly as-is
- Multi-device conflict resolution (explicit non-goal)
- Skill-tree *unlock* discovery while offline — offline shows only the last-synced unlock state plus already-downloaded content (see requirements.md FR-1)

---

## Assigned Requirements

| FR | Requirement | Priority |
|----|-------------|----------|
| FR-1 | Downloadable Lesson Packs | Must |
| FR-2 | Offline Lesson-Taking | Must |
| FR-3 | Beans/Streak/XP Sync on Reconnect (client queue + engine) | Must |
| FR-5 | Connectivity / Sync Status Indicator | Should |
| FR-6 | Pack Storage Management | Could |

---

## Domain Concepts

### Key Entities
| Entity | Description | Attributes |
|--------|-------------|------------|
| DownloadedPack (local model) | A cached lesson pack | skill_id, lesson_ids, content_version, downloaded_at, audio_file_paths |
| PendingSyncEntry (local model) | One offline completion awaiting sync | attemptId, lesson_id, client_completed_at, beans_delta, xp_delta, answers |
| ConnectivityState (client-only) | Current network/sync status | is_online, queue_length, sync_status (idle/syncing/failed) |

### Key Operations
| Operation | Description | Inputs | Outputs |
|-----------|-------------|--------|---------|
| DownloadPack | Fetch and cache a skill's lesson content + audio | skill_id | Stored `DownloadedPack`, progress events |
| StartLessonOffline | Start a cached lesson with zero network calls | lesson_id | Rendered first exercise, same as online path |
| EnqueuePendingSync | Record a completed offline lesson attempt locally | lesson_attempt | Stored `PendingSyncEntry` |
| DrainSyncQueue | On reconnect, replay each `PendingSyncEntry` through `001-offline-sync-service`'s endpoints in completion order | queue | Per-entry success/failure, queue shrinks on success |
| CheckPackStaleness | Compare a cached pack's `content_version` against the server's on next online contact | skill_id | Re-download flag (only enforced online, per FR-1) |

---

## Story Summary

| Metric | Count |
|--------|-------|
| Total Stories | 5 |
| Must Have | 3 |
| Should Have | 1 |
| Could Have | 1 |

### Stories

| Story ID | Title | Priority | Status |
|----------|-------|----------|--------|
| 001-download-lesson-packs | Download and cache lesson packs (content + audio) | Must | Done (bolt 009) |
| 002-offline-lesson-taking | Take a downloaded lesson with zero connectivity | Must | Done (bolt 009) |
| 003-pending-sync-queue-and-auto-sync | Queue and auto-sync offline completions on reconnect | Must | Done (bolt 010) |
| 004-connectivity-and-sync-status-indicator | Connectivity/sync status indicator | Should | Done (bolt 010) |
| 005-download-management-screen | Manage downloaded packs (list/size/delete) | Could | Done (bolt 010) |

---

## Dependencies

### Depends On
| Unit | Reason |
|------|--------|
| `001-offline-sync-service` | Needs the amended API contract (client-completion timestamp field, content-version signal) to sync against |

### Depended By
| Unit | Reason |
|------|--------|
| None | Terminal unit for this intent |

### External Dependencies
| System | Purpose | Risk |
|--------|---------|------|
| Cloudflare R2 | Audio download source for packs | Low — same static hosting `002` already uses, now fetched up front instead of streamed |

---

## Technical Context

### Suggested Technology
Flutter/Dart, extending `lib/features/lesson/` from `002-core-lesson-loop-ui` rather than a parallel feature tree. Local storage via `sqflite`/`drift` per `memory-bank/standards/tech-stack.md`. Connectivity detection via a standard Flutter connectivity plugin (choice deferred to Technical Design).

### Integration Points
| Integration | Type | Protocol |
|-------------|------|----------|
| `001-offline-sync-service` | API | REST over HTTPS, authenticated via existing session token |
| Cloudflare R2 | External asset host | HTTPS (direct download into local storage) |

### Data Storage
| Data | Type | Volume | Retention |
|------|------|--------|-----------|
| Downloaded lesson packs (content + audio) | Local device storage (sqflite/drift + files) | Bounded by how much the user downloads | Until user deletes (FR-6) or a version mismatch triggers re-download |
| Pending-sync queue | Local device storage | Small per-entry; unbounded count (no cap, see FR-3) | Until successfully synced |

---

## Constraints

- Reuses `002-core-lesson-loop`'s exercise engine/grading logic exactly — no parallel implementation.
- Zero network calls while taking an already-downloaded lesson (matches `002`'s existing online performance NFR).
- Pack staleness (14 days) is only ever checked/enforced when online — never blocks offline use of an already-cached pack.

---

## Success Criteria

### Functional
- [x] A downloaded lesson pack plays fully offline (all 3 exercise types, correct grading, Beans/XP bookkeeping) -- verified in tests and on a real physical device
- [x] Every offline completion syncs automatically and correctly on reconnect, in completion order
- [x] The connectivity/sync indicator accurately reflects state at all times

### Non-Functional
- [x] No network call while taking a cached lesson
- [x] No lost/duplicated sync entries across app restart while offline

### Quality
- [x] Widget test coverage for download manager, offline lesson flow, and sync queue draining
- [x] All acceptance criteria met
- [x] Code reviewed and approved

---

## Bolt Suggestions

| Bolt | Type | Stories | Objective |
|------|------|---------|-----------|
| 009-offline-caching-and-sync-ui | Simple | 001, 002 | Download manager + local storage + offline lesson-taking path |
| 010-offline-caching-and-sync-ui | Simple | 003, 004, 005 | Pending-sync queue, auto-sync engine, connectivity indicator, download-management screen |

---

## Notes

Split mirrors `002-core-lesson-loop-ui`'s two-bolt pattern: "make the core thing work" first (download + play offline), then "make it robust and visible" second (sync engine, indicator, management screen) — the second bolt genuinely depends on the first (nothing to sync until offline-taking exists).
