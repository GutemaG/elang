---
bolt: 008-offline-sync-service
created: 2026-09-16T22:00:00Z
status: accepted
supersedes: null
superseded_by: null
---

# ADR-6: Offline sync replays the existing per-completion endpoint; no batch-sync endpoint

## Context

`003-offline-caching-and-sync`'s UI unit needs to push a queue of offline-completed lessons to the server once connectivity returns (FR-3). The open question, deferred explicitly from Inception (story `003-idempotent-offline-replay`) to this bolt's Technical Design: should the server expose a new batch-sync endpoint that accepts N queued completions in one call, or should the client simply replay the existing `POST /lessons/{lesson_id}/complete` endpoint once per queued entry?

This bolt already makes that endpoint safe to call this way: idempotent on `attempt_id` (unchanged from ADR-5), and now timestamped via `client_completed_at` so delayed calls attribute streak/XP-day correctly (see `ddd-02-technical-design.md`).

## Decision

No batch-sync endpoint. The mobile client's sync engine (`002-offline-caching-and-sync-ui`) replays the existing per-completion endpoint sequentially, once per queued entry, in completion order.

## Rationale

Once the per-completion endpoint is idempotent and correctly timestamped, calling it N times is *correct* — a batch endpoint would only improve network efficiency (fewer round trips), not correctness or safety. The offline queue this intent is designed around is a handful of lessons between reconnects (requirements.md frames long unsynced gaps — 30+ days — as a supported-but-unusual case surfaced via a UI warning, not the common path this needs to be optimized for). Building a second endpoint that has to replicate the same idempotency/validation/bounded-ledger logic as the existing one, just batched, is real added surface area for a performance win that doesn't matter yet at the expected queue sizes.

### Alternatives Considered

| Alternative | Pros | Cons | Why Rejected |
|-------------|------|------|--------------|
| New batch-sync endpoint accepting N completions in one call | Fewer round trips; one client request regardless of queue size | Duplicates the idempotency/validation/bounded-ledger logic in a second code path; partial-failure semantics (some items in the batch succeed, others don't) add real design complexity for a case not yet shown to matter | Rejected for now — the correctness problem is already solved per-item; this would only be a performance optimization, and a premature one |
| Client batches completions into fewer, larger sequential calls (e.g. group by day) | Some round-trip reduction without a new endpoint | Adds client-side grouping logic and edge cases (which "day" wins if a group spans a validator boundary) for a benefit that's marginal at expected queue sizes | Rejected — complexity not justified at this scale |

## Consequences

### Positive
- Zero new endpoint surface; the correctness properties this bolt already built (idempotency, timestamp validation, bounded ledger) cover the sync case for free.
- Simpler client sync engine: one call shape, reused for both the "just completed one lesson online" and "replaying ten queued offline completions" cases.

### Negative
- N queued completions cost N round trips on reconnect, not one. For a small queue (the expected common case) this is negligible; for an unusually large queue it's a real, if bounded, cost.

### Risks
- If real-world usage shows offline queues routinely growing large (e.g. users going offline for weeks as a common pattern, not an edge case), the round-trip cost could become noticeable on slow reconnect networks. Flagged, not silently dismissed: revisit this decision with real usage data before assuming it holds indefinitely.

## Related

- **Builds on**: ADR-5 (`005-lesson-engagement-service`) — this decision only holds because ADR-5's idempotent, bounded-ledger completion endpoint already exists; a batch endpoint would have needed the same properties built twice.
- **Stories**: `003-idempotent-offline-replay` (001-offline-sync-service), `003-pending-sync-queue-and-auto-sync` (002-offline-caching-and-sync-ui)
