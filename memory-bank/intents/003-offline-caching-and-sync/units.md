---
intent: 003-offline-caching-and-sync
phase: inception
status: units-decomposed
updated: 2026-09-16T20:30:00Z
---

# Offline Caching & Sync - Unit Decomposition

## Requirement-to-Unit Mapping

- **FR-1** (Downloadable Lesson Packs) → `002-offline-caching-and-sync-ui` (download manager, local cache, staleness check); `001-offline-sync-service` owns exposing a content-version signal for the staleness check to compare against
- **FR-2** (Offline Lesson-Taking) → `002-offline-caching-and-sync-ui` (entirely client-side; reuses `002-core-lesson-loop`'s existing exercise engine/grading)
- **FR-3** (Beans/Streak/XP Sync on Reconnect) → `001-offline-sync-service` owns the idempotency/replay guarantee (confirming or extending bolt 005's `attemptId` endpoint); `002-offline-caching-and-sync-ui` owns the local pending-sync queue and the client-side sync engine that drives it
- **FR-4** (Streak-Day Conflict Resolution) → `001-offline-sync-service` (the streak business rule must accept and trust a client-supplied offline-completion timestamp, within sane bounds, instead of only ever using server-arrival time)
- **FR-5** (Connectivity / Sync Status Indicator) → `002-offline-caching-and-sync-ui`
- **FR-6** (Pack Storage Management) → `002-offline-caching-and-sync-ui`

Note: as with `001-auth-onboarding` and `002-core-lesson-loop`, the UI unit implements the screens/flows for every FR (it's the only client), but the underlying business rule/data-integrity guarantee for FR-3's idempotency and FR-4's day-attribution is owned by `001-offline-sync-service`, since getting those wrong corrupts the shared server ledger, not just one screen.

## Units Overview

This intent decomposes into 2 units of work:

### Unit 1: 001-offline-sync-service

**Description**: Small, targeted backend unit that makes `002-core-lesson-loop`'s existing lesson-content and completion endpoints safe to call late (after a delay) and out of order, and teaches the streak business rule to trust a client-supplied completion timestamp for day attribution. Deliberately not a new service — it's an amendment to `001-lesson-service`'s existing endpoints/logic, scoped separately here because it's new requirements-level behavior, not a UI concern.

**Stories**: TBD (created in the Stories step)

**Deliverables**:
- Confirm bolt 005's `attemptId`-based completion endpoint tolerates an arbitrarily delayed/replayed call with identical results (idempotency re-verification, not a rebuild)
- Accept a client-supplied offline-completion timestamp on the completion/answer calls, and attribute streak-day/XP-day using that timestamp (bounded/validated against abuse — exact bound is a Technical Design decision) instead of only the server's request-arrival time
- Expose a content-version/etag signal on the lesson-content and skill-tree responses for the client's 14-day staleness check to compare against
- Decide (Technical Design) whether a batch-sync endpoint is worth adding for network efficiency, or whether replaying the existing per-completion endpoint N times is sufficient

**Dependencies**:
- Depends on: `001-lesson-service` (existing, from intent `002-core-lesson-loop`) — extends its endpoints/tables, does not replace them
- Depended by: `002-offline-caching-and-sync-ui`

**Estimated Complexity**: S

### Unit 2: 002-offline-caching-and-sync-ui

**Description**: Flutter client work: a download manager for lesson packs (content + audio), local storage for cached packs and a pending-sync queue, an offline-capable path through the existing exercise engine, a connectivity monitor + sync engine that drains the queue automatically on reconnect, a connectivity/sync status indicator, and a download-management screen.

**Stories**: TBD (created in the Stories step)

**Deliverables**:
- Download manager UI (per-skill download affordance + progress) and local pack storage (sqflite/drift)
- Offline path through `002-core-lesson-loop`'s existing `LessonController`/exercise screens — no network call when a pack is already cached
- Pending-sync queue (local storage) + a connectivity-aware sync engine that replays queued completions through `001-lesson-service`'s (now offline-sync-service-amended) endpoints
- Connectivity/sync status indicator (persistent, unobtrusive)
- Download-management screen (list downloaded packs, size, delete)

**Dependencies**:
- Depends on: `001-offline-sync-service` (needs the amended endpoint contract — timestamp attribution, content-version signal — to integrate against); depends transitively on `002-core-lesson-loop-ui`'s existing exercise engine, which it extends rather than replaces
- Depended by: None

**Estimated Complexity**: L

## Unit Dependency Graph

```text
[001-offline-sync-service] ──> [002-offline-caching-and-sync-ui]
```

## Execution Order

Based on dependencies:

1. `001-offline-sync-service` first — small but foundational; defines the amended API contract (timestamp attribution, content-version signal, idempotency re-confirmation) the UI unit integrates against
2. `002-offline-caching-and-sync-ui` second — can scaffold the download manager/local storage/offline exercise path in parallel once the amended contract is documented from Technical Design, same pattern `002-core-lesson-loop` used
