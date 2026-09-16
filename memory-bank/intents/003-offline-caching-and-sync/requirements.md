---
intent: 003-offline-caching-and-sync
phase: inception
status: complete
created: 2026-09-16T19:00:00Z
updated: 2026-09-16T21:15:00Z
---

# Requirements: Offline Caching & Sync

## Intent Overview

Let a signed-in Buna user download a skill's lesson content and take lessons with zero connectivity, then have every offline change to Beans, streak, and XP sync back to the server ledger correctly once connectivity returns. This is the full-offline-mode option (not resilience-only): it's the "offline-first from the start" gap `docs/PLANNING.md` flags as a risk to build in early rather than retrofit, and treats caching and sync as one intent rather than two, since a downloadable pack with nothing to sync back (or a sync mechanism with nothing cached to sync) has no real offline value on its own.

## Business Goals

| Goal | Success Metric | Priority |
|------|----------------|----------|
| Lessons can be taken with zero connectivity | A downloaded lesson (all 3 exercise types) completes fully in airplane mode, with correct grading and beans/XP bookkeeping | Must |
| No progress/XP/streak is lost to connectivity gaps | 100% of offline-completed lessons sync to the server exactly once when connectivity returns | Must |
| Streak/beans state after sync matches what it would have been online | Streak day attribution and final bean count are correct regardless of when sync actually runs | Must |
| The user always knows their offline/sync state | A persistent, unobtrusive indicator distinguishes offline / syncing / synced / sync-failed at all times | Should |

---

## Functional Requirements

### FR-1: Downloadable Lesson Packs
- **Description**: A skill's lesson content (exercises, prompts, choices, correct answers per ADR-5's client-side-grading model, and audio for listening exercises) can be downloaded and cached locally ahead of going offline.
- **Acceptance Criteria**:
  - The skill-tree screen offers a download affordance per skill (or a batch "download next lessons" action), with visible download progress.
  - A downloaded pack contains everything needed to render and grade all its exercises with zero network calls, including audio files.
  - Cached packs persist across app restarts (local storage per `tech-stack.md`) and are only re-downloaded if the server-side content version changes.
  - A cached pack is treated as valid for 14 days after download without re-checking its content version; the re-check itself only happens opportunistically the next time the device is online (never enforced while offline, since forcing a re-check offline would break the offline promise — an offline user can keep using a pack past 14 days if they never reconnect).
  - While offline, the skill-tree screen shows the last-synced unlock state plus whatever was already downloaded before going offline — no new skill/lesson unlocks are discovered or displayed until the device reconnects and syncs. Downloaded content stays playable regardless of what the displayed unlock state shows.
- **Priority**: Must
- **Related Stories**: TBD

### FR-2: Offline Lesson-Taking
- **Description**: A downloaded lesson runs identically whether the device is online or offline — same exercise engine, same client-side grading (ADR-5), same Beans/streak/XP bookkeeping — the only difference is that the resulting changes are held locally instead of reaching the server immediately.
- **Acceptance Criteria**:
  - Starting, answering, and completing a downloaded lesson never blocks on network reachability.
  - Beans consumed, XP earned, and lesson-completion state are recorded locally using the same `attemptId` idempotency key already introduced for online completion (bolt 005, ADR-5).
  - Attempting a lesson that was never downloaded, while offline, shows a clear "download required" state rather than a silent failure or crash.
- **Priority**: Must
- **Related Stories**: TBD

### FR-3: Beans/Streak/XP Sync on Reconnect
- **Description**: When connectivity returns, every locally recorded offline lesson completion (and its Beans/XP effects) syncs to the server ledger automatically, with no user action required.
- **Acceptance Criteria**:
  - Sync is idempotent: a retried or duplicated sync attempt (e.g. a flaky reconnect mid-sync) never double-awards XP or double-deducts Beans, reusing the existing `attemptId` mechanism.
  - Multiple offline-completed lessons sync in the order they were actually completed.
  - A sync failure caused by a server error (not just absent connectivity) retries automatically with backoff and never silently drops a locally recorded completion.
  - The pending-sync queue has no size or time cap and never expires an entry — each entry is small metadata (`attemptId`, lesson/skill id, local completion timestamp, Beans/XP delta), not the lesson content itself, so retaining every unsynced completion until it succeeds is cheap and prioritizes never losing progress over storage optimization. If the device has gone unsynced for an unusually long stretch (30+ days), the connectivity indicator (FR-5) escalates to a more visible warning, but nothing is ever dropped automatically.
- **Priority**: Must
- **Related Stories**: TBD

### FR-4: Streak-Day Conflict Resolution
- **Description**: `002-core-lesson-loop`'s streak (FR-4) is computed against a calendar day; offline completions need an explicit rule for which day they count toward once they finally sync, since sync time and completion time can differ.
- **Acceptance Criteria**:
  - A lesson counts toward the device's local calendar date at the moment it was completed offline, not the date sync happens to run.
  - If offline completions span a local day boundary before sync (e.g. one lesson at 11:50pm, another at 12:10am, both offline), each is attributed to its own correct day, and the streak increments per distinct day represented, not per lesson.
  - A streak freeze active at sync time still protects a day that would otherwise be missed due to sync-order or sync-delay effects.
- **Priority**: Must
- **Related Stories**: TBD

### FR-5: Connectivity / Sync Status Indicator
- **Description**: The user can always tell whether they're offline, have unsynced progress pending, or are fully synced.
- **Acceptance Criteria**:
  - A persistent, unobtrusive UI element shows one of: online/synced, offline (packs available), offline (nothing downloaded), syncing, sync failed–retrying.
  - The indicator never blocks interaction with already-downloaded content.
- **Priority**: Should
- **Related Stories**: TBD

### FR-6: Pack Storage Management
- **Description**: Downloaded lesson packs (including audio) consume device storage; the user can see and manage what's downloaded.
- **Acceptance Criteria**:
  - A download-management view lists downloaded skills/lessons with an approximate storage size and a per-item delete action.
  - Deleting a downloaded pack never deletes already-synced server-side progress — only the local content cached to replay it offline.
- **Priority**: Could
- **Related Stories**: TBD

---

## Non-Functional Requirements

### Performance
| Requirement | Metric | Target |
|-------------|--------|--------|
| Exercise transition while offline | Time between submitting an answer and the next exercise rendering | Instant — identical to the existing online NFR (no network call), since grading is already client-side |
| Sync turnaround after reconnect | Time from connectivity restored to all pending offline progress synced | Automatic, no user action required; exact retry/backoff schedule is a technical-design decision |

### Reliability
| Requirement | Metric | Target |
|-------------|--------|--------|
| Offline data durability | Locally recorded Beans/XP/streak/completion state survives app kill, restart, or update while still offline | 100% — no loss between offline completion and successful sync |
| Sync idempotency | Duplicate or retried sync of the same offline completion | Never double-awards XP or double-deducts Beans (reuses `attemptId`) |

### Data
| Requirement | Standard | Notes |
|-------------|----------|-------|
| Local storage | Per `memory-bank/standards/tech-stack.md` | Lesson packs (content + audio) and a pending-sync queue both live in local on-device storage |

---

## Constraints

### Technical Constraints

**Project-wide standards**: Loaded from `memory-bank/standards/` by Construction Agent (tech-stack.md, data-stack.md, coding-standards.md).

**Intent-specific constraints**:
- Reuses ADR-5's client-side-grading + `attemptId` idempotency model for offline completions rather than introducing a second grading path.
- No change to the shape of the server-side Beans/XP/streak tables (002's schema) — sync writes through the existing completion/answer endpoints, just deferred until connectivity returns.
- Single-device assumption carries over from `001-auth-onboarding`/`002-core-lesson-loop` (no existing multi-device concurrent-session support). This intent does **not** add multi-device offline conflict resolution (e.g. the same account offline on two phones at once) — explicitly a non-goal, not silently ignored.

### Business Constraints
- Full offline mode covers lesson-taking only (FR-1–4); it does not extend to account creation/auth (001) or discovering skill-tree structure changes made server-side while offline — both still require connectivity.
- Downloaded-pack storage/size budget is not fixed here; it's a technical-design decision.

---

## Assumptions

| Assumption | Risk if Invalid | Mitigation |
|------------|-----------------|------------|
| The existing `attemptId`-based idempotent completion endpoint (bolt 005, ADR-5) is sufficient for offline-sync idempotency without a new endpoint | Sync needs a new/extended endpoint, adding backend scope | Confirm during Technical Design against `memory-bank/bolts/005-lesson-engagement-service/adr-5-client-side-grading-with-bounded-server-ledger.md` |
| Caching full lesson content (including answer keys) on-device for offline grading carries no new risk beyond what ADR-5 already accepted for the online case | If a security requirement contradicts this, the client-side-grading approach itself is in conflict, not just this intent | Already an accepted risk of ADR-5's design; not re-litigated here |

---

## Open Questions

| Question | Owner | Due Date | Resolution |
|----------|-------|----------|------------|
| How long should a downloaded lesson pack stay valid before requiring a content-version re-check? | Product/Eng | Requirements refinement | ✅ Resolved — 14 days, re-checked opportunistically online only (see FR-1) |
| What's the pending-sync queue's retention/size cap if the device stays offline for an extended period (days)? | Eng | Requirements refinement | ✅ Resolved — no cap; entries are lightweight metadata, retained until synced (see FR-3) |
| Should skill-tree *unlock* state (new nodes becoming available) be visible while offline, or only lessons already downloaded before going offline? | Product | Requirements refinement | ✅ Resolved — only content already downloaded/loaded before going offline; new unlocks surface only after reconnect+sync (see FR-1) |
