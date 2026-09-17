---
stage: test
bolt: 013-user-preferences-service
created: '2026-09-17T11:10:00Z'
---

## Test Report: user-preferences-service

### Summary

- **Unit Tests**: `tests/unit/test_user_preferences_service.py` — 9 new tests, all passing. `UserPreferencesService` exercised directly against `FakeUserRepository` (DB boundary mocked, per `coding-standards.md`); `LanguageCode`/`DailyXPTarget`/`OnboardingAttachmentPolicy` exercised for real.
- **Integration Tests**: `tests/integration/test_user_preferences_endpoint.py` — 9 new tests (full `PATCH /api/v1/users/me` flow via `TestClient` against a real temp-file SQLite DB); `tests/integration/test_repositories.py` — 1 new test (`SqlAlchemyUserRepository.update`).
- **Full suite**: `uv run pytest -q` → **270/270 passing** (251 pre-existing + 19 new). Zero regressions.
- **Lint**: `uv run ruff check app tests` → clean.
- **Coverage** (bolt-touched modules): `app/domain/services.py` 100%, `app/infrastructure/db/repositories.py` 100%, `app/application/use_cases.py` 96% (the 2 "missing" lines belong to the pre-existing `authenticate_with_google`/`authenticate_with_apple` code paths not exercised by *this* bolt's own test run in isolation — covered elsewhere in the full suite), `app/infrastructure/api/user_routers.py` reports 92%/1-line-missing (the multi-line `return UserPreferencesResponse(...)` statement) — confirmed via an isolated single-test run that this line *is* actually executed on every successful call; a coverage.py line-attribution quirk on this Python version for multi-line returns in `async def`, not a real gap.

### Acceptance Criteria Validation

**Story 001-update-daily-goal-and-language**
- ✅ Daily goal update persists and is reflected on later reads — `test_updates_language_goal_and_notification`, `test_change_is_reflected_on_a_later_session_check`
- ✅ Language update persists — same tests
- ✅ Invalid goal/language rejected — `test_invalid_language_is_rejected_422`, `test_invalid_daily_goal_minutes_is_rejected_422` (both 422, `error_code: invalid_preference_value` — see Technical Design's Stage-4 correction #2 for why 422 rather than the sign-up flow's 400)
- ✅ `entities.py`'s `User` docstring updated to document the new deliberate exception (ADR-7) — done at Stage 4, re-verified by reading the file: invariant #2 now states the amended rule explicitly.

**Story 002-store-notification-preference**
- ✅ `notification_enabled` persists and is returned on subsequent reads — `test_updates_language_goal_and_notification`, `test_change_is_reflected_on_a_later_session_check`
- ✅ Existing/pre-migration rows backfill sensibly (not null) — migration `e02dd0a9ae54` uses a constant `server_default=true`; verified via the manual `alembic upgrade/downgrade/upgrade` round-trip at Stage 4. New signups also default to `true` — `test_new_signup_defaults_notification_enabled_to_true`.
- ✅ No notification is ever sent as a result of this toggle — true by construction: no notification-delivery code exists anywhere in this codebase to send one (confirmed by the Domain Model stage's search).

**Both stories' shared edge cases**
- ✅ Resubmitting current values is a no-op success — `test_resubmitting_current_values_is_a_no_op_success` (integration), `test_resubmitting_current_values_succeeds_as_no_op` (unit)
- ✅ Empty/all-omitted body is a no-op success — `test_empty_body_is_a_no_op_success`, `test_all_none_is_a_no_op`
- ✅ Missing/unknown auth rejected 401, reusing the existing `get_current_user` dependency unchanged — `test_missing_auth_header_is_rejected_401`, `test_unknown_session_token_is_rejected_401`

### Issues Found

None. No regressions; no new bugs surfaced during testing.

### Recommendations

- `014-profile-and-settings-ui` can now build against the real, verified `PATCH /api/v1/users/me` contract and the extended `AuthUserResponse`/`SessionUserResponse` shapes (both now carry `notification_enabled`) — no further backend guessing needed.
- The coverage-quirk noted above (line 43 of `user_routers.py`) is worth a one-line mention if this project ever writes a coverage-tooling errata doc, but doesn't block anything.
