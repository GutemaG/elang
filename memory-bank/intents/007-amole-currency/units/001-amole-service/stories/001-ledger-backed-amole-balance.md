---
id: 001-ledger-backed-amole-balance
unit: 001-amole-service
intent: 007-amole-currency
status: complete
priority: must
created: '2026-09-17T16:20:00Z'
assigned_bolt: null
implemented: true
---

# Story: 001-ledger-backed-amole-balance

## User Story

**As a** Buna learner
**I want** my Amole balance and Bean-refill spend to work exactly as they do today
**So that** the internal switch to a ledger is invisible to me

## Acceptance Criteria

- [ ] **Given** an existing user with a current `amole_balance`, **When** the migration runs, **Then** their computed ledger balance (`SUM(amount)`) equals their pre-migration balance exactly, verified for at least one fixture user with a non-starting balance
- [ ] **Given** a new user, **When** their wallet is first created, **Then** a `source='wallet_created'` row for `STARTING_AMOLE_BALANCE` is posted (replacing the old default-field behavior)
- [ ] **Given** the beans-status endpoint, **When** called, **Then** `amole_balance` in the response is unchanged in shape and value from before this story, now sourced from the ledger
- [ ] **Given** a user with sufficient balance, **When** they refill Beans, **Then** a `source='bean_refill'` negative row for `REFILL_COST_AMOLE` is posted, Beans are credited, and the response is unchanged in shape from before this story
- [ ] **Given** a user with insufficient balance, **When** they attempt a refill, **Then** the existing 422 `InsufficientAmoleError` behavior is unchanged, validated against the ledger sum

## Technical Notes

- This is a retrofit of shipped code (`UserBeans`, `refill_beans_with_amole`, the beans-status use case) — read their actual current signatures at Stage 4 before assuming the exact touch points; don't guess at this stage.
- The migration must do three things in a safe, real order (verify against how `e02dd0a9ae54`/`c726efa81972` sequenced multi-step migrations): create `amole_transactions`, backfill one row per existing `user_beans` row, drop the `amole_balance` column.

## Dependencies

### Requires
- None (first story in this bolt)

### Enables
- `002-award-amole-on-completion` (same bolt, needs the ledger to exist first)
- `002-amole-ui`'s dashboard display (needs the retrofitted balance endpoint)

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| A user with zero `user_beans` row at all (never touched Beans/Amole) | Still a valid default state — balance computes as 0 rows = 0 sum, consistent with `UserBeans`'s existing "absence is meaningful" pattern; the `STARTING_AMOLE_BALANCE` grant happens on first real access, matching how `_default_beans` already works today |
| Migration run twice (e.g. retried deploy) | Must not double-backfill — same idempotency mechanism as FR-1's uniqueness constraint |

## Out of Scope

- Award triggers (see `002-award-amole-on-completion`)
