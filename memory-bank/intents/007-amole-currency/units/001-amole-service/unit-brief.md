---
unit: 001-amole-service
intent: 007-amole-currency
phase: inception
status: complete
created: '2026-09-17T16:15:00Z'
updated: '2026-09-17T16:15:00Z'
---

# Unit Brief: Amole Service

## Purpose

Replace `user_beans.amole_balance` (a mutable column) with an append-only `amole_transactions` ledger, add the missing award side of the Amole economy to `complete_lesson`, and retrofit the already-shipped spend/balance code to read and write through the ledger instead of the column.

## Scope

### In Scope
- New `amole_transactions` table + migration, including a backfill of every existing user's current `amole_balance` into one `source='migration_backfill'` row
- Removal of `user_beans.amole_balance` column (same migration or a follow-up one)
- Award side-effects inside `complete_lesson`: flat lesson-completion amount, perfect-lesson bonus, 7-day/30-day streak-milestone bonus (first time only)
- Retrofit `refill_beans_with_amole` to post a negative ledger row instead of mutating a column
- Retrofit the beans-status endpoint's `amole_balance` field to `SUM(amole_transactions.amount)`
- Idempotency via a uniqueness constraint on the ledger (not application-logic-only)

### Out of Scope
- Any UI (owned by `002-amole-ui`)
- Any spend category beyond Bean refill (streak-freeze, cosmetics — explicitly Phase 2)
- Changes to `BeanLedger`'s regen logic itself

---

## Assigned Requirements

| FR | Requirement | Priority |
|----|-------------|----------|
| FR-1 | Amole Ledger (replaces the mutable balance column) | Must |
| FR-2 | Award Amole | Must |
| FR-3 | Spend Amole (retrofit) | Must |
| FR-4 | Balance Endpoint (retrofit) | Must |

---

## Domain Concepts

### Key Entities
| Entity | Description | Attributes |
|--------|-------------|------------|
| `AmoleTransaction` (new) | One ledger row, immutable once written | `id`, `user_id`, `amount` (signed), `source`, `reference_id`, `created_at` |
| `UserBeans` (existing, amended) | Loses `amole_balance` field — Amole balance is no longer part of this aggregate's state, only Beans regen state remains | `user_id`, `current_count`, `last_regen_at` |

### Key Operations
| Operation | Description | Inputs | Outputs |
|-----------|-------------|--------|---------|
| `AwardAmole` (new, called from `complete_lesson`) | Posts one or more positive ledger rows for a completion | user_id, attempt_id, correct_count, total_count, current_streak | ledger rows posted |
| `SpendAmoleOnRefill` (retrofit of existing use case) | Validates ledger-sum balance, posts a negative row, credits Beans | user_id | new beans count, new balance |
| `GetAmoleBalance` (retrofit) | `SUM(amount)` for a user | user_id | balance |

---

## Technical Context

### Suggested Technology
Python/FastAPI/SQLAlchemy, extending `backend/app/domain/lesson/entities.py` (drop `amole_balance` from `UserBeans`), `backend/app/domain/lesson/value_objects.py` (existing `REFILL_COST_AMOLE`/`STARTING_AMOLE_BALANCE` — `STARTING_AMOLE_BALANCE` becomes the backfill/new-user seed row amount, not a field default), a new `AmoleTransactionRepository`, and an Alembic migration doing both the new table and the column drop plus data backfill (verify actual migration ordering/safety at Technical Design — do not assume drop-and-backfill can be one step without reading how `e02dd0a9ae54` and `c726efa81972` sequenced their own multi-step changes).

### External Dependencies
None — purely internal.

---

## Constraints

- Zero regression to `backend/tests/unit/test_bean_ledger.py`, `test_lesson_engagement_use_cases.py`, `test_lesson_engagement_endpoints.py`, `test_lesson_engagement_repositories.py` (all bolt `005`) — these currently assert against the column; they will need updating for the ledger, but the *behavior* they assert (refill cost, insufficient-balance rejection, starting balance) must not regress.
- The uniqueness constraint enforcing idempotency (FR-1) needs a real design decision on what `reference_id` actually is per `source` (e.g. `attempt_id` for lesson/perfect awards, a synthesized value for streak milestones since there's no natural per-event id) — read `complete_lesson`'s real signature before fixing this at Technical Design.

---

## Bolt Suggestions

| Bolt | Type | Stories | Objective |
|------|------|---------|-----------|
| 017-amole-service | ddd-construction-bolt | 001, 002 | Ledger migration + award triggers + spend/balance retrofit |

---

## Notes

This unit amends shipped code from bolt `005`. Treat Stage 1-2 (Domain Model, Technical Design) with the same rigor as a greenfield bolt — reading `complete_lesson`'s and `refill_beans_with_amole`'s actual current signatures at Stage 4 (per this bolt type's rules) will likely surface details not anticipated here, same as bolt `013`'s "Corrected during Stage 4" pattern.
