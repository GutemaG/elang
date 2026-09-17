---
bolt: 017-amole-service
created: '2026-09-17T18:15:00Z'
status: accepted
supersedes: null
superseded_by: null
---

# ADR-8: Amole balance moves to a real append-only ledger table, not a mutable column — accepting an asymmetry with XP

## Context

`user_beans.amole_balance` (bolt `005-lesson-engagement-service`) is a plain mutable integer column, mutated in place by the refill use case. This intent needs to add an earn side (lesson completion, perfect lesson, streak milestones) on top of the existing spend side, which raised the real question of how balance state should be represented once there are multiple independent writers instead of one.

This codebase's own standards docs (`memory-bank/standards/data-stack.md`, `coding-standards.md`) already name `amole_transactions` as an aspirational append-only ledger table ("ledgers (XP/Amole as append-only transaction tables)", "`amole` (not \"gems\"), `xp_transactions`/`amole_transactions` (ledger tables)") — but neither table actually existed before this bolt. XP itself is `SUM(lesson_attempts.xp_awarded)`, a sum over an unrelated table that happens to serve the same purpose, not a literal ledger table. So this decision isn't inventing a new pattern from nothing — it's the first bolt to actually build what the standards docs already named, but only for Amole, not XP.

## Decision

Introduce `amole_transactions` (`id`, `user_id`, `amount`, `source`, `reference_id`, `created_at`) as the sole source of truth for Amole balance — `SUM(amount)`, always computed, never cached. Remove `user_beans.amole_balance` entirely rather than keeping it as a denormalized cache alongside the ledger. `UNIQUE (source, reference_id)` is the idempotency mechanism for every writer (awards and, to the extent described in ADR-9, spends).

XP is explicitly **not** touched by this decision — it remains `SUM(lesson_attempts.xp_awarded)`, not migrated to an `xp_transactions` table. This creates a real, visible asymmetry (Amole has a real ledger table; XP's "ledger" is really just a byproduct of the attempts table) that this ADR accepts rather than resolves, because building `xp_transactions` was never in this bolt's or intent `007`'s scope.

## Rationale

Amole now has genuinely independent writers (multiple award triggers plus an existing spend path) whose combined effect must never be double-counted under retries — exactly the problem an append-only ledger with a uniqueness constraint solves cleanly, and exactly what the standards docs already anticipated needing. XP, by contrast, has exactly one writer (`complete_lesson`, once per idempotent `attempt_id`) and already gets correct, idempotent accounting for free from `lesson_attempts`'s own existing idempotency check — there is no analogous problem to solve for XP today, so building `xp_transactions` now would be speculative work with no current requirement driving it.

### Alternatives Considered

| Alternative | Pros | Cons | Why Rejected |
|-------------|------|------|--------------|
| Add award logic directly onto the existing `amole_balance` column (no ledger) | Smaller change, no migration | No audit trail; idempotency for multiple independent award sources would need a separate ad-hoc mechanism (e.g. a set of boolean flags per milestone) rather than one uniform one; harder to debug a wrong balance after the fact | Rejected — the user's own explicit Inception-time choice, and the standards docs already anticipated a ledger |
| Build `xp_transactions` in this same bolt, for symmetry with Amole | Removes the asymmetry entirely | Out of scope for intent `007`; XP has no current correctness problem the sum-over-`lesson_attempts` approach doesn't already solve; would touch `complete_lesson`'s XP path with no story requiring it | Rejected — speculative scope expansion with no driving requirement |
| Keep `amole_balance` as a cached column, updated transactionally alongside each ledger insert | Reads stay a single-column lookup, no `SUM` needed | Two sources of truth that must never drift; the exact "stored running total" pattern the user explicitly asked to avoid | Rejected — user's explicit Checkpoint 1 choice during Inception |

## Consequences

### Positive
- Every current and future Amole award/spend source gets the same idempotency mechanism for free (the ledger's own uniqueness constraint), rather than each needing its own ad-hoc guard.
- Matches what this project's own standards docs already described as the intended design.
- Full audit trail: any balance can be explained by replaying its transactions, useful for support/debugging in a real-money-adjacent feature.

### Negative
- Balance is now a `SUM` query instead of a column read on every access — a real, if small, extra cost on the beans-status endpoint's hot path (mitigated by the `ix_amole_transactions_user_id` index; not expected to matter at this codebase's scale).
- XP and Amole now use visibly different accounting mechanisms for conceptually similar "how much does this user have" questions — a future reader could reasonably ask "why not xp_transactions too," and the answer is "no problem currently requires it," not "an oversight."

### Risks
- If XP ever needs multiple independent writers (e.g. a future XP-boost/bonus system), the same ledger reasoning would apply and `xp_transactions` should be revisited then — not retrofitted reactively after a double-counting bug has already shipped.

## Related

- **Stories**: 001-ledger-backed-amole-balance, 002-award-amole-on-completion
- **Standards**: `memory-bank/standards/data-stack.md`, `memory-bank/standards/coding-standards.md` (both already named `amole_transactions`/`xp_transactions` aspirationally; this ADR records that only the former is actually built here, and why)
- **Previous ADRs**: precedent relationship to ADR-7 (both amend a previously-shipped aggregate's persisted shape transparently, via ADR, rather than silently)
