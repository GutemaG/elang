---
stage: test
bolt: 017-amole-service
created: '2026-09-17T19:30:00Z'
---

## Test Report: amole-service

### Summary

- **Unit tests**: all passing, 100% line coverage on `app/domain/lesson/*`, `app/application/lesson_use_cases.py`
- **Integration tests**: all passing, 100% line coverage on `app/infrastructure/db/lesson_repositories.py`
- **Full backend suite**: 282/282 passed (up from 270 pre-bolt), `uv run ruff check app tests` clean
- **Migration**: verified manually via `alembic upgrade head` / `downgrade -1` / `upgrade head` — clean round-trip. No automated pytest migration test was added; this codebase's existing convention (`tests/conftest.py`'s `db_path` fixture) builds test schemas directly from current model metadata (`Base.metadata.create_all`), bypassing Alembic entirely for every prior bolt too — this bolt follows that same convention rather than introducing new test infrastructure unilaterally.

### Regression Fixed (32 pre-existing tests)

Removing `UserBeans.amole_balance` and widening `get_beans_status`/`refill_beans`/`complete_lesson`'s signatures broke 32 tests across `test_bean_ledger.py`, `test_lesson_engagement_use_cases.py`, `test_lesson_engagement_endpoints.py`, `test_lesson_engagement_repositories.py` — all fixed by updating direct `UserBeans(...)` construction sites and threading the new `amole_repo` parameter through, exactly the same category of fallout as bolt `013`'s `User` field addition.

### A Real Bug Found and Fixed During This Stage

`SqlAlchemyAmoleTransactionRepository.add_if_new` initially did not flush after `session.add(...)`. The shared session factory (`db/session.py`) sets `autoflush=False`, so `get_beans_status`'s/`refill_beans`'s pattern of posting a transaction and immediately reading `sum_by_user` back in the same request undercounted the balance by exactly the just-posted amount — caught by `test_lesson_engagement_endpoints.py`'s real HTTP-level tests (`TestGetBeansStatus::test_new_user_gets_full_beans_and_starting_amole` returned `amole_balance: 0` instead of `500`; `TestRefillBeans::test_success_returns_maxed_beans_and_deducted_amole` got a 422 instead of 200). Fixed by adding an explicit `await self._session.flush()` after the insert. This is exactly the kind of gap unit tests against fakes cannot catch (the fakes don't model session flush timing) — the real-DB integration tests earned their keep here.

### New Tests Added

- `test_lesson_engagement_use_cases.py`: `TestCompleteLessonAmoleAwards` (flat award, perfect bonus, 7-day and 30-day streak-milestone crossing, no repeat milestone once past threshold, no double-award on a retried `attempt_id`), plus 3 new `TestGetBeansStatus`/`TestRefillBeans` cases (lazy-grant idempotency, ledger-backed refill, ledger row posted).
- `test_lesson_engagement_repositories.py`: `TestSqlAlchemyAmoleTransactionRepository` (empty sum, add-then-sum, idempotent `add_if_new` on `(source, reference_id)`, per-user isolation).
- `tests/fakes.py`: new `FakeAmoleTransactionRepository`, enforcing the same uniqueness the real DB constraint would.

### Acceptance Criteria Validation

**Story 001-ledger-backed-amole-balance**:
- ✅ Migration backfill preserves existing balances (verified manually; new users get `wallet_created` lazily, verified by `test_repeated_reads_grant_the_starting_balance_exactly_once`)
- ✅ Beans-status/refill API contracts unchanged in shape (existing endpoint tests pass unmodified in structure, only fixture setup changed)
- ✅ Insufficient-balance rejection unchanged (`test_raises_insufficient_amole_when_balance_too_low`, `test_insufficient_amole_returns_422`)

**Story 002-award-amole-on-completion**:
- ✅ Flat completion award (`test_no_perfect_bonus_for_an_imperfect_lesson`)
- ✅ Perfect-lesson bonus (`test_awards_flat_amount_and_perfect_bonus_for_a_perfect_lesson`)
- ✅ 7-day and 30-day streak milestones, transition-based (`test_awards_streak_milestone_bonus_exactly_on_the_crossing_completion`, `test_awards_both_milestone_bonuses_when_crossing_30_from_29`, `test_no_repeat_milestone_bonus_once_past_the_threshold`)
- ✅ No double-award on a retried `attempt_id` (`test_retried_completion_does_not_double_award`)

### Known, Deliberately Accepted Gaps (ADR-9)

`bean_refill`'s ledger reference is not retry-protected — a retried refill can still double-spend, identical to pre-bolt behavior. Not tested as a "passing" case since it is a knowingly accepted limitation, not a guarantee; see ADR-9.

### Recommendations

None outstanding. Both stories' acceptance criteria are met; zero regression to bolt `005`'s or `006`'s test suites.
