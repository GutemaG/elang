---
intent: 007-amole-currency
phase: inception
status: complete
created: '2026-09-17T16:00:00Z'
updated: '2026-09-17T16:35:00Z'
---

# Requirements: Amole Currency

## Intent Overview

Give Amole an earn side. **Corrected during requirements-gathering by reading real source** (the build prompt that kicked this intent off assumed a greenfield build, but most of it already shipped as part of bolt `005-lesson-engagement-service`):

- `user_beans.amole_balance` (column, not a ledger), `STARTING_AMOLE_BALANCE = 500` (one-time grant on wallet creation), `REFILL_COST_AMOLE = 350` already exist (`backend/app/domain/lesson/value_objects.py`).
- A spend/refill endpoint already exists with server-side balance validation and a 422 `InsufficientAmoleError` (`backend/app/application/lesson_use_cases.py`'s `refill_beans_with_amole`).
- The Flutter `OutOfBeansSheet` (`lib/features/lesson/widgets/out_of_beans_sheet.dart`) already renders "Refill with X Amole" and the disabled "Not enough Amole" state.
- There is no `xp_transactions` table anywhere in this codebase — XP is `SUM(lesson_attempts.xp_awarded)`, computed on read. The "follow the xp_transactions ledger pattern" instruction in the original build prompt refers to a table that doesn't exist; there is no existing ledger pattern to mirror.

The real gap: **nothing ever increases `amole_balance`.** A user spends down their one-time 500-Amole grant and can never earn more. There is also no dashboard display of the balance (only inside the out-of-beans modal).

**Explicit architecture decision (Checkpoint 1)**: rather than bolt award logic onto the existing mutable `amole_balance` column, this intent introduces a proper append-only `amole_transactions` ledger (`SUM(amount)` = balance) as the source of truth, and retrofits the already-shipped spend/balance code to read/write through it. This is a deliberate amendment to bolt `005`'s shipped design, not a new-code-only addition — same category of change as ADR-7's amendment to `users` in intent `005`.

## Business Goals

| Goal | Success Metric | Priority |
|------|----------------|----------|
| Amole becomes a real earn-and-spend loop, not a one-time grant that only depletes | A user who plays normally can always eventually afford a refill again | Must |
| Give the ledger an audit trail from day one, since it's real account balance | Every balance change traceable to a `source` + `reference_id` | Must |
| Surface the balance outside the out-of-beans modal | Balance visible on the home dashboard | Must |

---

## Functional Requirements

### FR-1: Amole Ledger (replaces the mutable balance column)
- **Description**: New `amole_transactions` table (`id`, `user_id`, `amount`, `source`, `reference_id`, `created_at`). Balance is always `SUM(amount) WHERE user_id = ?`, never a stored running total — mirrors how `lesson_attempts.xp_awarded` is summed for XP, the closest existing precedent in this codebase (even though it isn't literally the same table shape the original build prompt assumed existed).
- **Acceptance Criteria**:
  - `user_beans.amole_balance` column is removed; nothing reads or writes it after this bolt
  - A migration backfills each existing user's current `amole_balance` as one `source='migration_backfill'` ledger row, so no one's balance silently changes at cutover
  - `UNIQUE (source, reference_id)` (or equivalent) prevents the same logical event from ever posting two ledger rows — this is the idempotency mechanism for FR-2 and FR-3
- **Priority**: Must

### FR-2: Award Amole
- **Description**: Positive ledger entries on: lesson completion (flat amount), a perfect lesson — zero missed questions, i.e. `correct_count == total_count` (bonus, additive to the flat amount), and streak milestones (7-day, 30-day — larger, one-time-per-milestone bonus).
- **Acceptance Criteria**:
  - Every genuine lesson completion posts a flat-amount award row, `reference_id = attempt_id`
  - A perfect lesson posts an additional bonus row in the same transaction, same `attempt_id`, distinct `source`
  - Reaching a 7-day or 30-day streak (for the first time — not every day past it) posts a milestone bonus row
  - A retried completion request for the same `attempt_id` (already handled as a no-op by `complete_lesson`'s existing idempotency check) posts **zero** additional ledger rows — verified by FR-1's uniqueness constraint, not just by the existing early-return
- **Priority**: Must
- **Open question carried to Technical Design**: exact flat/bonus amounts are tuning values, not fixed here (mirrors how `REFILL_COST_AMOLE`/`STARTING_AMOLE_BALANCE` are named constants, not requirements-level numbers).

### FR-3: Spend Amole (retrofit, not new — Bean refill only)
- **Description**: The already-shipped Bean-refill flow now posts a negative ledger row instead of mutating a column. External behavior (request/response shape, 422 on insufficient balance) is unchanged — this is an internal retrofit. Per the original build prompt, no other spend category (streak-freeze, cosmetics) is in scope; that is explicitly Phase 2.
- **Acceptance Criteria**:
  - Refilling posts a `source='bean_refill'` negative row for `REFILL_COST_AMOLE`
  - Balance is validated server-side via the same `SUM(amount)` read the balance endpoint uses — never trusts a client-submitted balance (unchanged constraint from the original shipped behavior)
  - Zero regression to bolt `005`'s existing `test_bean_ledger.py` / lesson-engagement endpoint/repository tests
- **Priority**: Must

### FR-4: Balance Endpoint (retrofit)
- **Description**: The existing beans-status endpoint's `amole_balance` field is now computed via the ledger sum instead of a column read. No response-shape change.
- **Acceptance Criteria**: Existing `BeansStatus`/`RefillResponse` API contracts unchanged; value now sourced from `SUM(amole_transactions.amount)`.
- **Priority**: Must

### FR-5: Amole Balance on the Home Dashboard
- **Description**: Display the current Amole balance on `SkillTreeDashboardScreen`, next to the existing XP/streak display — today it is only visible inside the out-of-beans modal.
- **Acceptance Criteria**: The dashboard shows the current balance and updates after any lesson completion or refill without requiring a manual refresh/navigation round-trip.
- **Priority**: Must

---

## Non-Functional Requirements

### Consistency
| Requirement | Standard | Notes |
|-------------|----------|-------|
| Ledger sum is always the single source of truth for balance | New, but mirrors the XP-sum pattern | No cached/denormalized balance column anywhere after this bolt |

### Reliability
| Requirement | Standard | Notes |
|-------------|----------|-------|
| A retried award or spend request must never double-post | New | Enforced by FR-1's uniqueness constraint, not application-logic-only |

### Migration Safety
| Requirement | Standard | Notes |
|-------------|----------|-------|
| Existing users' balances are preserved exactly across the column-to-ledger cutover | New | Backfill migration per FR-1; verified by a migration test comparing pre/post balances for existing fixture users |

---

## Constraints

### Technical Constraints
- Zero regression to bolt `005-lesson-engagement-service`'s and bolt `006-core-lesson-loop-ui`'s existing test suites (Beans regen/refill, streak, XP, dashboard).
- No change to Beans regen logic (`BeanLedger`) itself — only how the Amole side of `UserBeans`/`RefillResult` is sourced.
- Streak-freeze and cosmetic spending are explicitly out of scope (Phase 2, per the original build prompt).

### Business Constraints
- None identified beyond normal project pacing.

---

## Assumptions

| Assumption | Risk if Invalid | Mitigation |
|------------|-----------------|------------|
| Flat/bonus Amole amounts don't need to be user-configurable or A/B-testable in Phase 1 | Would need a config/experimentation layer instead of named constants | Named constants, same pattern as `REFILL_COST_AMOLE` — trivially promotable later |
| The 7-day/30-day streak milestones are evaluated against `user_streaks.current_streak` (already tracked by bolt `005`) with no new streak-history table needed | If "milestone reached before" needs its own durable record beyond the ledger itself, a small addition is needed | The ledger itself is the record: "has a `source='streak_milestone_7'` row ever posted for this user" is the check, no separate flag needed |

---

## Open Questions

| Question | Owner | Due Date | Resolution |
|----------|-------|----------|------------|
| Ledger table vs. keep the existing mutable balance column | User | Checkpoint 1 | **Resolved**: ledger table (`amole_transactions`), replacing the column entirely, with a backfill migration |
| Proceed with intent `008-srs-and-practice` given it needs new foundational schema (`vocab_items`, `exercises.vocab_item_id`) that doesn't exist yet | User | Checkpoint 1 | **Resolved**: proceed with both, `007` then `008` |

---

## Dependencies

- Amends bolt `005-lesson-engagement-service`'s shipped `UserBeans` domain model and its `refill_beans_with_amole`/beans-status use cases and endpoints — not additive-only.
- Amends the Flutter dashboard (`006-core-lesson-loop-ui`) and reads (but does not change) the already-correct `OutOfBeansSheet` (`007-core-lesson-loop-ui`).
- Sequenced before `008-srs-and-practice` by user preference.
