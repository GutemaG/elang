---
stage: implement
bolt: 017-amole-service
created: '2026-09-17T19:00:00Z'
---

## Implementation Walkthrough: amole-service

### Files Changed

**Domain** (`backend/app/domain/lesson/`):
- `value_objects.py`: added `AmoleSource` (7-value `StrEnum`), `AmoleAward` (frozen dataclass), and 4 new tuning constants (`AMOLE_LESSON_COMPLETION_AWARD=20`, `AMOLE_PERFECT_LESSON_BONUS=10`, `AMOLE_STREAK_MILESTONE_7_BONUS=150`, `AMOLE_STREAK_MILESTONE_30_BONUS=500`) plus `STREAK_MILESTONE_7_DAYS`/`STREAK_MILESTONE_30_DAYS`.
- `entities.py`: `UserBeans` loses `amole_balance`; new `AmoleTransaction` entity.
- `services.py`: new `AmoleAwardPolicy.awards_for_completion(...)` (pure, no I/O).
- `repositories.py`: new `AmoleTransactionRepository` Protocol (`add_if_new`, `sum_by_user`).

**Application** (`backend/app/application/lesson_use_cases.py`):
- `_default_beans` no longer sets `amole_balance`.
- New `_ensure_amole_wallet`/`get_amole_balance` helpers (lazy, idempotent starting-balance grant).
- `get_beans_status`: gains `amole_repo` param, sources `amole_balance` from the ledger.
- `refill_beans`: gains `amole_repo` param, posts a `bean_refill` ledger row instead of mutating a column (per ADR-9, uses a fresh non-correlatable reference — matches pre-existing, unprotected retry behavior).
- `complete_lesson`: gains `amole_repo` param; after computing `completion` (which has both the pre- and post-completion streak), calls `AmoleAwardPolicy.awards_for_completion(...)` and posts each result via `amole_repo.add_if_new(...)`, keyed to `attempt_id`.

**Infrastructure**:
- `lesson_models.py`: new `AmoleTransactionModel`; `UserBeansModel` loses `amole_balance` column/constraint.
- `lesson_repositories.py`: new `SqlAlchemyAmoleTransactionRepository`; `_beans_model_to_domain`/`upsert` drop the Amole field.
- `lesson_dependencies.py`: new `get_amole_transaction_repository`.
- Migration `f4a8b1c9d3e6`: creates `amole_transactions`, backfills one `migration_backfill` row per existing `user_beans` row (preserving balances exactly), drops `user_beans.amole_balance`. Verified `upgrade` → `downgrade` → `upgrade` round-trips cleanly.

**Presentation** (`lesson_routers.py`): `get_beans_status_endpoint`, `refill_beans_endpoint`, `complete_lesson_endpoint` all gain the `amole_repo` dependency and pass it through. **No response-shape changes** — verified by inspection of `lesson_schemas.py` (untouched).

**Docs**: `database-schema.md` updated (`user_beans` amended, new `amole_transactions` section).

### Corrected During Stage 4

Stages 1-2's Domain Model/Technical Design named a domain service `AmoleLedger` with `balance_for`/`post`/`spend` operations, modeled on `BeanLedger`'s naming. Reading the real `BeanLedger`/`StreakPolicy`/`LessonCompletionService` at this stage showed that isn't actually analogous: every existing domain service in this codebase is a **pure function over an in-memory aggregate already loaded by the application layer** — none of them hold a repository dependency or do I/O. `AmoleLedger` as designed would have been the first domain service in this codebase to hold a repository, breaking that layering convention, and there's no single in-memory `AmoleTransaction` "aggregate" to operate on anyway (each row is independent, per the Domain Model's own "trivial aggregate boundary" note).

**Correction**: dropped `AmoleLedger` entirely. The pure decision logic became `AmoleAwardPolicy` (a real domain service, no I/O — matches the convention). The actual "post + sum + idempotent insert" mechanics moved to the application layer (`lesson_use_cases.py`), calling `AmoleTransactionRepository` directly — exactly mirroring how `complete_lesson` already handles `LessonAttemptRepository`'s idempotency (`get` then `add`, no domain-service wrapper around that pattern either). This is a simpler design than Stage 1-2 proposed, not just a differently-named one.

### Verification

- `uv run alembic upgrade head` / `downgrade -1` / `upgrade head`: clean round-trip, no manual intervention needed.
- `uv run ruff check app`: clean (after fixing 2 line-length violations and one now-unused import surfaced by the refactor).
- `uv run pytest -q`: **32 pre-existing tests fail** — expected fallout from removing `UserBeans.amole_balance` and widening `get_beans_status`/`refill_beans`/`complete_lesson`'s signatures, exactly the same category of breakage bolt `013` saw when `User` gained a required field. None of these are new-code test failures; all 32 are existing bolt-005 tests (`test_bean_ledger.py`, `test_lesson_engagement_use_cases.py`, `test_lesson_engagement_endpoints.py`, `test_lesson_engagement_repositories.py`) that either construct `UserBeans(..., amole_balance=...)` directly or call the retrofitted use cases with their old signatures. Fixing these, plus writing new tests for the award/ledger behavior itself, is Stage 5's job — deliberately not done here, per this bolt type's stage boundary.
