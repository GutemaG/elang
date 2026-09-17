---
bolt: 017-amole-service
created: '2026-09-17T18:15:00Z'
status: accepted
supersedes: null
superseded_by: null
---

# ADR-9: Bean-refill retry double-spend gap is knowingly preserved, not fixed, by this bolt

## Context

This bolt's own requirements.md states a Reliability NFR: "a retried award **or spend** request must never double-post." For awards (lesson completion, perfect lesson, streak milestones), this is satisfied by `(source, reference_id=attempt_id)` uniqueness in `amole_transactions` (ADR-8), backed by `complete_lesson`'s pre-existing attempt-level idempotency.

For the Bean-refill spend, there is no equivalent natural reference: the existing refill endpoint accepts no client-supplied idempotency key, so a retried refill request (e.g. a network timeout followed by a client retry) looks like a brand-new event with no way to correlate it to the original attempt. Generating a fresh server-side reference per request — the only option that doesn't change the request contract — would satisfy the ledger's uniqueness constraint syntactically while providing zero actual retry protection: two calls, two distinct references, two postings, a real double-spend.

Critically, **this is not a regression introduced by this bolt** — today's plain column mutation (`amole_balance -= REFILL_COST_AMOLE`) has exactly the same gap; a retried request already double-spends today, before this bolt touches anything. The ledger retrofit was scoped (FR-3) as internally-transparent, contract-unchanged, and this gap is a pre-existing condition the retrofit was never asked to fix.

## Decision

Accept the pre-existing gap as-is. `bean_refill` transactions get a fresh, non-correlatable reference per request; a retried refill can double-spend, identical to today's actual behavior. The Reliability NFR in requirements.md is narrowed in scope to awards only — spend idempotency for `bean_refill` is explicitly out of scope for this bolt, not silently unmet.

No request contract change is made. Adding a client-supplied idempotency key to the refill request (and updating the Flutter client to generate and send one) is left as a candidate for a future, separately-scoped story if retry-driven double-spends are ever observed to be a real problem in practice.

## Rationale

Fixing this now would mean widening the refill request contract — a genuine (if small) scope expansion beyond what this bolt's requirements.md and unit-brief describe ("Request/response contracts unchanged"), touching both the FastAPI endpoint and the Flutter `HttpLessonApi`/refill call site for a problem that: (a) already exists today, unrelated to this bolt, and (b) has no evidence of being a real-world issue (a genuine double-spend requires a specific race — client sends request, server commits, response is lost in transit, client retries — that's possible but not the common case for a foreground, user-initiated tap). Recording this explicitly as an ADR, rather than letting it hide inside a Technical Design paragraph, makes it a discoverable, revisitable decision instead of a silently-inherited gap.

### Alternatives Considered

| Alternative | Pros | Cons | Why Rejected |
|-------------|------|------|--------------|
| Add a client-supplied idempotency key to the refill request | Fixes the gap properly, matches the award side's protection | Real contract change (backend + Flutter), scope creep beyond FR-3, fixes a problem with no observed real-world instances | Rejected — user's explicit Stage 3 choice; disproportionate to demonstrated risk |
| Generate a reference from request-adjacent data that's stable across a retry (e.g. hash of user_id + current second) | No contract change | Two refills genuinely 1 second apart would collide and silently fail one of them — worse than the status quo (a false rejection where none should occur) | Rejected — trades a rare double-spend for a more common false-rejection |
| Leave the NFR wording as originally written ("award or spend") and just don't fully satisfy it | Avoids explicitly weakening a stated requirement | Silently ships against a documented requirement it doesn't meet, no record of why | Rejected — this project's convention is to record and narrow scope explicitly, not leave a requirement quietly unmet |

## Consequences

### Positive
- No contract change; zero risk to the already-shipped Flutter refill flow.
- The limitation is now documented and discoverable (this ADR, plus requirements.md's NFR should be read alongside it), not an implicit gap a future reader would have to rediscover by testing.

### Negative
- The stated Reliability NFR is not, in fact, fully met by this bolt as shipped — narrowed explicitly here, but still a real gap between "documented requirement" and "actual behavior" that a careless future reader of requirements.md alone (without this ADR) could miss.

### Risks
- If retry-driven double-spends are ever observed in production telemetry, revisit this decision — the fix (client-supplied idempotency key) is well-understood and small; it just isn't justified preemptively.

## Related

- **Stories**: 001-ledger-backed-amole-balance
- **Standards**: none currently document idempotency-key conventions for client-mutation requests generally
- **Previous ADRs**: depends on ADR-8 (the ledger's uniqueness mechanism is what this ADR explains the limits of)
