---
id: 004-connectivity-and-sync-status-indicator
unit: 002-offline-caching-and-sync-ui
intent: 003-offline-caching-and-sync
status: done
priority: should
created: '2026-09-16T20:45:00Z'
assigned_bolt: 010-offline-caching-and-sync-ui
implemented: true
---

# Story: 004-connectivity-and-sync-status-indicator

## User Story

**As a** Buna user
**I want** to always see whether I'm offline, syncing, or fully synced
**So that** I'm never confused about whether my progress has actually reached the server

## Acceptance Criteria

- [x] **Given** the device is online with nothing pending, **When** viewing any main screen, **Then** the indicator shows a "synced" state (or is unobtrusively absent/minimal, per Technical Design)
- [x] **Given** the device is offline, **When** downloaded packs are available, **Then** the indicator shows "offline, lessons available" distinctly from "offline, nothing downloaded"
- [x] **Given** the sync queue is actively draining, **When** viewing the app, **Then** the indicator shows a "syncing" state
- [x] **Given** a sync attempt is failing and retrying, **When** viewing the app, **Then** the indicator shows a distinguishable "sync failed, retrying" state
- [x] **Given** any of the above states, **When** the user interacts with already-downloaded content, **Then** the indicator never blocks or intercepts that interaction (satisfied by construction -- the indicator isn't reachable from the lesson screen at all)

## Technical Notes

- Purely additive UI, driven by the connectivity monitor + sync queue state already built for story 003 — no new state model, just a presentation layer over it.
- Exact visual treatment (banner vs. small badge vs. icon in the app bar) matches the Highland Pulse design system per `stich-screens/.../highland_pulse/DESIGN.md`; specific placement is a Technical Design/implementation decision, not fixed here.

## Dependencies

### Requires
- 003-pending-sync-queue-and-auto-sync (the state this story surfaces)

### Enables
- None

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Connectivity flaps rapidly | **Partially met**: the underlying `SyncEngine` is tested to never spam retries or spawn overlapping sync attempts on rapid flaps, but the indicator itself doesn't literally debounce its re-renders -- a cosmetic flicker risk, not a functional one. Not implemented; flagged in bolt 010's test-walkthrough.md rather than silently claimed as done. |
| User is mid-lesson when state changes | Indicator update never interrupts or overlays the active exercise screen |

## Out of Scope

- Any change to sync behavior itself (owned by story 003)
- Push notifications about sync state (out of scope for this intent entirely)
