---
stage: design
bolt: 017-amole-service
created: '2026-09-17T17:50:00Z'
---

## Technical Design: amole-service

### Architecture Pattern

Same layered architecture as every prior backend bolt (domain → application → infrastructure → presentation, no framework imports below application). No new pattern at the architecture level — the only genuine novelty is that `AmoleTransaction` is this codebase's first true append-only ledger table (XP is a computed sum over an unrelated table, `lesson_attempts`; Beans is a plain mutable column). This is flagged for Stage 3 as a candidate "establishes a reusable pattern" ADR, not decided here.

### Layer Structure

```text
┌─────────────────────────────┐
│      Presentation           │  lesson_routers.py (unchanged endpoints, retrofitted internals)
├─────────────────────────────┤
│      Application            │  complete_lesson (amended), refill_beans_with_amole (retrofit),
│                              │  get_beans_status (retrofit)
├─────────────────────────────┤
│        Domain                │  AmoleTransaction (new), AmoleLedger (new), AmoleAwardPolicy (new),
│                              │  UserBeans (amended — loses amole_balance)
├─────────────────────────────┤
│     Infrastructure          │  AmoleTransactionRepository (new, SQLAlchemy), migration
└─────────────────────────────┘
```

### Lazy Wallet-Creation Semantics (the one genuinely tricky part of this design)

Today, `_default_beans(user_id, now)` returns an **in-memory** default (`amole_balance=STARTING_AMOLE_BALANCE`) with no DB write — the row is only ever persisted later, via `beans_repo.upsert`, at the point of a real state change (a completion that consumes a bean, or a refill). This laziness must be preserved for Amole, but a ledger can't fake a default balance purely at read time the way an in-memory dataclass default can: if a user's first-ever mutation is an award (say `+50 lesson_completion`) and no `wallet_created` row is ever actually inserted, `SUM(amount)` would wrongly total `50`, silently dropping the promised starting `500`.

**Design**: `AmoleLedger` gets an internal `_ensure_wallet(user_id)` — an idempotent `post(user_id, STARTING_AMOLE_BALANCE, 'wallet_created', reference_id=user_id)` — called from exactly two places:
1. `balance_for(user_id)`, before summing (so any balance read, including the beans-status endpoint, is correct even for a user who has never triggered any other mutation).
2. Inside `spend(user_id, amount, source, reference_id)` (used by the refill retrofit), before validating sufficiency (so a spend check is never computed against an incomplete ledger).

Award posting (`post` called from `complete_lesson`) does **not** need to call `_ensure_wallet` itself — correctness only depends on the grant existing by the time someone *reads* the total, and `_ensure_wallet` is idempotent and cheap to call liberally from the two read/validate paths above. This mirrors the existing "absence is meaningful, lazily materialized" pattern already used for `UserBeans`/`UserSkillProgress`.

### API Design

No endpoint request/response shape changes. Two existing endpoints are internally retrofitted:

- **Beans-status endpoint** (existing): `amole_balance` in the response now comes from `AmoleLedger.balance_for(user_id)` instead of a column read. Same shape, same value semantics (a brand-new user still sees `500`, via the lazy-wallet-creation logic above).
- **Refill endpoint** (existing): internally calls `AmoleLedger.spend(user_id, REFILL_COST_AMOLE, source='bean_refill', reference_id=<see Stage 3>)` instead of mutating a column. Same 422 `InsufficientAmoleError` on insufficient balance, same response shape.

No new endpoints are added by this bolt (due-items/due-count etc. belong to intent `008`, not this one).

### Data Model

**New table** `amole_transactions`:

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | `UUID`/`TEXT` | `PRIMARY KEY`, server-generated `uuid4` | Surrogate key — this is a runtime-created row, not seeded content, so `uuid4` (same convention as `auth_sessions`/`user_skill_progress`), not a deterministic id. |
| `user_id` | `UUID`/`TEXT` | `NOT NULL`, `FOREIGN KEY REFERENCES users(id)` | Plain reference, same independence pattern as `auth_sessions.user_id`. |
| `amount` | `INTEGER` | `NOT NULL` | Signed — positive award, negative spend. No `CHECK` forcing a sign per source at the DB level; that's a domain-logic invariant (`AmoleAwardPolicy` only ever proposes positive amounts, `spend` only ever proposes negative ones), not a schema one — mirrors how `lesson_attempts.xp_awarded`'s sign isn't DB-enforced either. |
| `source` | `VARCHAR(32)` | `NOT NULL`, `CHECK (source IN ('wallet_created', 'migration_backfill', 'lesson_completion', 'perfect_lesson', 'streak_milestone_7', 'streak_milestone_30', 'bean_refill'))` | Closed vocabulary, same `CHECK`-constraint-as-enum pattern as `exercises.type`/`users.auth_provider` (ADR-3's precedent, applied to a new closed set). |
| `reference_id` | `VARCHAR(64)` | `NOT NULL` | `attempt_id` for completion-triggered sources; `user_id` for `wallet_created`/`migration_backfill`; see Stage 3 for `bean_refill`. |
| `created_at` | `TIMESTAMPTZ`/`TIMESTAMP` | `NOT NULL`, `DEFAULT now()` | |

**Constraints**: `UNIQUE (source, reference_id)` — the idempotency mechanism; `CHECK` on `source`.

**Indexes**: Primary key on `id`; implicit unique index from `UNIQUE (source, reference_id)`; `ix_amole_transactions_user_id` on `user_id` (the sole query pattern `sum_by_user` needs).

**Amended table** `user_beans`: drop `amole_balance` (and its `CHECK (amole_balance >= 0)` constraint).

**Migration** (one Alembic revision, three ordered steps — verify exact SQLAlchemy/Alembic version's `batch_alter_table` requirements for the column drop at Stage 4, following `c726efa81972`'s precedent for portable schema changes):
1. `op.create_table("amole_transactions", ...)` with the `UNIQUE`/`CHECK` constraints above.
2. Data backfill: for every existing `user_beans` row, `INSERT INTO amole_transactions (source, reference_id, amount, user_id, ...) VALUES ('migration_backfill', user_id, <that row's current amole_balance>, user_id, ...)`. Users with **no** `user_beans` row at all get no backfill row — they are still "never granted a wallet," correctly handled by the lazy-creation logic above on their first real access.
3. `op.batch_alter_table("user_beans")` → drop `amole_balance` column.

### Security Design

No new auth surface — every retrofitted endpoint keeps its existing session-token authentication (`get_current_user`), unchanged. No new PII in the ledger (`user_id`, `amount`, `source`, `reference_id` — no free text, no audio/voice data, nothing beyond what already flows through `lesson_attempts`).

### NFR Implementation

- **Consistency** (ledger is the sole source of truth): `balance_for`/`sum_by_user` is the only balance computation anywhere post-retrofit; no cached column survives.
- **Reliability** (retried request must never double-post): satisfied for all completion-triggered sources (lesson_completion, perfect_lesson, streak_milestone_7/30) via `(source, reference_id=attempt_id)` uniqueness, itself backed up by `complete_lesson`'s pre-existing attempt-level idempotency check. **Not fully satisfied for `bean_refill`** — flagged explicitly for Stage 3, not silently resolved here (see the Domain Model's flagged tension).
- **Migration Safety** (existing balances preserved exactly): satisfied by the backfill step; verified by a migration test comparing a fixture user's pre/post balance.

### Integration Points

- `complete_lesson`: after its existing Beans/XP/progress/streak orchestration (which already computes `previous_streak`/`new_streak` and has `correct_count`/`total_count`/`attempt_id` in scope), call `AmoleAwardPolicy.awards_for_completion(...)`, then `AmoleLedger.post(...)` for each result, inside the same transaction/idempotency boundary.
- `refill_beans_with_amole`: replace the column read/write with `AmoleLedger.balance_for`/`spend`.
- Beans-status use case: replace the column read with `AmoleLedger.balance_for`.
