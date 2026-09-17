---
stage: model
bolt: 017-amole-service
created: '2026-09-17T17:30:00Z'
---

## Static Model: amole-service

### Entities

- **AmoleTransaction** (new): `id`, `user_id`, `amount` (signed integer — positive = award, negative = spend), `source` (closed vocabulary, see Value Objects), `reference_id` (ties the row back to the causing event), `created_at`. Business rules: immutable once created — never updated, never deleted; `(source, reference_id)` is unique per row, the mechanism that makes awarding/spending idempotent under a retried request.
- **UserBeans** (existing, amended): `user_id`, `current_count`, `last_regen_at`. Business rules: unchanged from bolt `005` — `0 <= current_count <= BEANS_MAX`, regenerated lazily from `last_regen_at`. **Loses** `amole_balance` — Amole is no longer part of this entity's state at all; it moves entirely to the ledger below.

### Value Objects

- **AmoleSource**: closed set of string values — `wallet_created`, `migration_backfill`, `lesson_completion`, `perfect_lesson`, `streak_milestone_7`, `streak_milestone_30`, `bean_refill`. Not a free-form string; adding a new source is a deliberate code change, not runtime-configurable, mirroring how `ExerciseType` is a closed enum rather than a free string.
- **AmoleReference**: the value that makes a `(source, reference_id)` pair unique for a given real-world event. For `lesson_completion`, `perfect_lesson`, **and** `streak_milestone_7`/`streak_milestone_30`, this is uniformly the completion's `attempt_id` — **not** a synthesized per-user key. A milestone bonus is decided by transition, not by "has this ever happened before": it qualifies exactly when *this* completion's streak update carries the streak from below the threshold to at or above it (`previous_streak < 7 <= new_streak`, similarly for 30), a fact `complete_lesson` already has for free from the `UserStreak` values it reads and writes in the same transaction — no extra repository read is needed, and one completion can only cross a given threshold once by construction, so keying it to that completion's `attempt_id` is both sufficient and consistent with every other completion-triggered source. (An earlier draft of this model keyed milestones to `user_id` and required a separate "has this been awarded before" existence check — rejected on review as a second, redundant dedup mechanism alongside the ledger's own uniqueness constraint.) For `wallet_created`/`migration_backfill`, the reference is `user_id` (each happens at most once per user, ever, with no completion to key off). For `bean_refill`: **see the flagged tension below** — there is no natural per-event id today, since the refill endpoint accepts no client-supplied idempotency key.

**⚠️ Flagged tension, not resolved at this stage**: `requirements.md`'s Reliability NFR states "a retried award **or spend** request must never double-post." A `bean_refill` reference generated fresh per request (the only option without changing the request contract) does **not** satisfy that — a retried refill would post twice, identical to today's pre-existing, unprotected behavior (the current column-mutation has no retry protection either), but now in explicit contradiction of a requirement this bolt itself states. This is not a Domain Model decision to make silently; carrying it forward to Stage 3 (ADR Analysis) for an explicit choice: (a) accept the pre-existing gap and narrow the NFR's wording to awards only, or (b) add a client-supplied idempotency key to the refill request (a real, if small, contract change FR-3 currently rules out).

### Aggregates

- **AmoleTransaction** (aggregate root, trivial boundary): each row is its own aggregate instance with no internal collection — there is no parent "wallet" aggregate holding a list of transactions, because nothing ever needs to load "all of a user's transactions" as one consistency boundary; the only derived value anyone needs is the sum, which is a query, not aggregate state. This deliberately differs from `UserBeans`'s "one row per user" wallet shape — Amole's invariant (uniqueness per event) is enforced per-row, not by loading a parent.
- **UserBeans** (existing aggregate, amended): unchanged invariants (`0 <= current_count <= BEANS_MAX`, at most one row per `user_id`), minus the Amole field.

### Domain Events

- **AmoleAwarded**: Trigger: a genuine lesson completion (`complete_lesson`), specifically the flat completion amount, an additional perfect-lesson bonus when `correct_count == total_count`, or a streak-milestone bonus (7-day/30-day) exactly on the completion whose streak update crosses that threshold. Payload: `user_id`, `amount`, `source`, `reference_id` (= `attempt_id` for all three). One `complete_lesson` call may raise this event multiple times (flat + perfect + milestone are independent, additive) — each is a separate ledger row, same `reference_id`, distinct `source`.
- **AmoleSpent**: Trigger: a Bean refill. Payload: `user_id`, `amount` (negative), `source='bean_refill'`, `reference_id`.

### Domain Services

- **AmoleLedger** (new, naming mirrors the existing `BeanLedger` convention): Operations: `balance_for(user_id) -> int` (sum of all transactions), `post(user_id, amount, source, reference_id) -> AmoleTransaction` (idempotent — if a row for `(source, reference_id)` already exists, returns it unchanged rather than posting a duplicate). Dependencies: `AmoleTransactionRepository`.
- **AmoleAwardPolicy** (new): Operations: `awards_for_completion(attempt_id, correct_count, total_count, previous_streak, new_streak) -> list[(amount, source, reference_id)]` — pure decision logic (no I/O, no repository dependency) for which awards a completion qualifies for, all keyed to `attempt_id`: flat completion amount always; perfect-lesson bonus when `correct_count == total_count`; `streak_milestone_7`/`_30` bonus exactly when `previous_streak < threshold <= new_streak`. `complete_lesson` calls this once (it already has all five inputs from its existing orchestration), then posts each result through `AmoleLedger.post`, which is the sole place idempotency is actually enforced. Dependencies: none.

### Repository Interfaces

- **AmoleTransactionRepository**: Entity: `AmoleTransaction`. Methods: `add(transaction) -> AmoleTransaction` (must respect the `(source, reference_id)` uniqueness invariant — either a DB-level constraint surfaced as a caught conflict, or an existence check; the exact mechanism is a Technical Design decision), `sum_by_user(user_id) -> int`. No `exists()` method is needed by `AmoleAwardPolicy` — see the revised Domain Services entry; `add`'s own idempotency handles every case, including milestones.

### Ubiquitous Language

- **Amole**: the earned, spendable currency (as distinct from Beans, the mistake-tolerance resource, and XP, the progress metric).
- **Ledger**: the append-only set of `AmoleTransaction` rows for a user; the sole source of truth for balance — never a stored running total.
- **Balance**: `SUM(amount)` over a user's ledger rows, always computed, never cached in this domain model.
- **Source**: the closed-vocabulary reason a transaction exists (what caused it).
- **Reference**: the id tying a transaction back to the specific real-world event that caused it, making re-processing that event idempotent.
- **Award**: a positive-amount transaction (Amole earned).
- **Spend**: a negative-amount transaction (Amole spent).
- **Backfill**: the one-time transaction created by the cutover migration, preserving a user's pre-ledger balance exactly.

### Story Coverage

- `001-ledger-backed-amole-balance`: `AmoleTransaction`, `AmoleLedger`, `AmoleTransactionRepository`, the `wallet_created`/`migration_backfill`/`bean_refill` sources.
- `002-award-amole-on-completion`: `AmoleAwardPolicy`, the `AmoleAwarded` event, the `lesson_completion`/`perfect_lesson`/`streak_milestone_*` sources.
