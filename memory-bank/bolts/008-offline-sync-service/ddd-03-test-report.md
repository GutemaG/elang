---
unit: 001-offline-sync-service
bolt: 008-offline-sync-service
stage: test
status: complete
updated: '2026-09-16T23:00:00Z'
---

# Test Report - Offline Sync Service

## Test Summary

Full backend suite: **242 passed, 0 failed** (`uv run pytest -q` from `backend/`). Of these, 221 are the pre-existing `001-auth-service`/`001-lesson-service` suite (8 amended — see "Cross-Bolt Amendments" below), and 21 are new for this bolt.

| Category | New for this bolt |
|----------|--------------------|
| Unit (`CompletionTimestampValidator`, `complete_lesson` timestamp/idempotency behavior) | 12 |
| Integration (`get_content_version`/`list_content_versions_by_skills` repository methods, endpoint-level `content_version`/`invalid_completion_timestamp` checks) | 9 |
| Performance (skill-tree query count, amended) | 0 new, 1 amended |

`ruff check .`: clean across the whole backend. `mypy app`: 1 pre-existing error (line-shifted, confirmed present before this bolt via `git stash`), not introduced by this bolt.

## Acceptance Criteria Validation

| Story | Criteria | Status |
|-------|----------|--------|
| 001-content-version-signal | Response includes a version signal per skill/lesson | ✅ `test_lesson_endpoints.py::test_new_user_sees_first_skill_active_and_rest_locked` (skill-tree), `::test_returns_full_ordered_exercise_list_in_one_request` (lesson-content) |
| 001 | Signal stable across repeated fetches of unchanged content | ✅ `test_content_version.py::test_is_stable_across_repeated_fetches_with_no_change` |
| 001 | Signal changes when content is edited | ✅ `test_content_version.py::test_reflects_the_most_recent_exercise_update` |
| 001 | No per-skill round trip (grouped query, not N+1) | ✅ `test_lesson_performance.py::TestSkillTreeQueryCount` (budget updated 6→8, still constant) |
| 002-timestamped-completion-for-streak-attribution | Streak/XP-day attribution uses `client_completed_at`, not server-arrival time | ✅ `test_lesson_engagement_use_cases.py::test_streak_day_attribution_uses_client_completed_at_not_now` |
| 002 | Two completions attributed to the same day increment the streak once, not per lesson | ✅ `::test_two_completions_attributed_to_the_same_day_increment_streak_once` |
| 002 | Implausible timestamps (far future / predates account) are rejected, no ledger effect | ✅ `::test_raises_invalid_completion_timestamp_for_a_far_future_timestamp`, `::test_raises_invalid_completion_timestamp_when_it_predates_account_creation`, `test_completion_timestamp_validator.py` (6 tests covering the validator directly), `test_lesson_engagement_endpoints.py::test_far_future_client_completed_at_returns_422` |
| 002 | No upper bound on staleness -- a long-past completion is accepted | ✅ `test_lesson_engagement_use_cases.py::test_accepts_a_completion_from_long_before_now_for_a_long_offline_gap`, `test_completion_timestamp_validator.py::test_accepts_a_timestamp_arbitrarily_far_in_the_past`, `test_lesson_engagement_endpoints.py::test_a_completion_from_long_before_now_is_accepted` |
| 003-idempotent-offline-replay | A replayed completion after a real-time delay never double-awards XP/Beans | ✅ `test_lesson_engagement_use_cases.py::test_idempotent_replay_after_a_multi_day_delay` |
| 003 | Idempotency check runs before timestamp validation (a valid, already-accepted attempt is never rejected on retry) | ✅ Same test -- second call uses a `now` 2 days later than the first but returns the identical outcome without re-validating |
| 003 | No batch-sync endpoint added; existing endpoint proven safe to call once per queued item | ✅ ADR-6; no new endpoint exists, existing endpoint's idempotency re-verified above |

## Cross-Bolt Amendments (Verified Together)

- **`001-lesson-service` (bolts 004/005)**: `POST /lessons/{id}/complete` now requires `client_completed_at`; `GET /skill-tree`/`GET /lessons/{id}` responses gained `content_version`. All 6 `complete_lesson` unit-test call sites and 8 HTTP payload sites across `test_lesson_engagement_endpoints.py` and `test_skill_tree_next_lesson_id.py` updated to match. `get_lesson_content`'s return type changed from `Lesson` to `LessonContentResult` (wraps `lesson` + `content_version`) -- `test_lesson_use_cases.py` updated accordingly. Full pre-existing suite re-run and passing, not just the touched tests.
- **`tests/fakes.py`**: `FakeLessonRepository`/`FakeLessonRepositoryWithSkillIndex` gained `get_content_version`/`list_content_versions_by_skills` (fixed canned value -- real version-change behavior is covered by the integration tests against the real repository, not the fakes).
- **Query-count NFR** (`test_lesson_performance.py`): budget explicitly raised 6→8 to account for the 2 new grouped content-version queries, with the comment updated to explain why -- still a small constant, not per-skill.

## Issues Found

| Issue | Severity | Status |
|-------|----------|--------|
| Technical Design assumed a new `client_completed_at` column would be needed | None (design refinement) | Not an issue -- discovered during Implement that `lesson_attempts.completed_at` was already exactly that field; repurposed it instead of adding a new column. Simpler than planned, documented in the bolt's Implement summary. |
| `mypy app` reports 1 error in `domain/lesson/services.py` (`new_crown_level` assignment) | Low | Not introduced by this bolt -- confirmed present at the same logical line before this bolt's changes via `git stash`; pre-existing, out of this bolt's scope to fix. |
| **Errata (found during bolt 009's wrap-up, 2026-09-17)**: this report's "migration verified to apply/downgrade cleanly" claim below was wrong. `server_default=sa.func.now()` compiles to `CURRENT_TIMESTAMP` on SQLite, and SQLite's `ALTER TABLE ADD COLUMN` rejects a non-constant default combined with `NOT NULL` outright ("Cannot add a column with non-constant default") -- `alembic upgrade head` failed against the real `dev.db`. | Medium (would have blocked any fresh environment from migrating) | Fixed in the same migration file: `server_default` changed to a fixed constant (`'1970-01-01 00:00:00'`, matching the app's own `_NO_CONTENT_VERSION` fallback epoch). Re-verified upgrade → downgrade → upgrade against real `dev.db`; full backend suite (242/242) re-run and still passing. |

## Ready for Operations

- [x] All acceptance criteria met
- [x] Code coverage: 100% on every module this bolt touched (`domain/lesson/services.py`, `domain/lesson/exceptions.py`, `domain/lesson/repositories.py`, `application/lesson_use_cases.py`, `infrastructure/db/lesson_repositories.py`, `infrastructure/api/lesson_schemas.py`); overall `app/` package 86%, shortfall entirely pre-existing out-of-scope code (external verifiers, `main.py`, session bootstrap), same as bolt 005's treatment
- [x] No critical/high severity issues open
- [x] Idempotency re-verified under delayed (not just near-immediate) replay, per story 003's specific gap
- [x] Alembic migration (`e3cea3ee5c84`) verified to apply and downgrade cleanly against a real SQLite database, independent of the test suite's `create_all`-based schema setup
- [x] Cross-bolt amendments (004, 005) re-verified with the full suite, not spot-checked
