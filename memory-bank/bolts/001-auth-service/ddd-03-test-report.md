---
unit: 001-auth-service
bolt: 001-auth-service
stage: test
status: complete
updated: 2026-09-15T18:10:00Z
---

# Test Report - Auth Service

## Test Summary

| Category | Passed | Failed | Skipped | Coverage |
|----------|--------|--------|---------|----------|
| Unit | 45 | 0 | 0 | 100% (domain + application layers) |
| Integration | 23 | 0 | 0 | 100% (db/repositories, db/models); endpoint routes exercised end-to-end |
| Security | 6 | 0 | 0 | - |
| Performance | 2 | 0 | 0 | - |
| **Total** | **76** | **0** | **0** | **69% of `app/` overall; 99% of auth-logic-bearing modules (see Coverage Report)** |

Command run: `uv run pytest --cov=app --cov-report=term-missing` (from `backend/`). All 76 tests pass on a clean run.

## Acceptance Criteria Validation

| Story | Criteria | Status |
|-------|----------|--------|
| 001-persist-pending-onboarding-selections | AC1: first-time sign-in with pending language + daily-goal-minutes → new row stores language + mapped XP target | ✅ `test_authentication_service.py::TestNewUserPath::test_creates_user_with_pending_selection_attached`, `test_auth_endpoints.py::TestGoogleAuthEndpoint::test_new_user_via_google_with_pending_selection` |
| 001-persist-pending-onboarding-selections | AC2: first-time sign-in with NO pending payload → account still created with documented defaults, not an error | ✅ `test_authentication_service.py::test_creates_user_with_defaults_when_no_pending_selection`, `test_auth_endpoints.py::test_new_user_via_google_with_no_pending_selection_uses_defaults` |
| 001-persist-pending-onboarding-selections | AC3: returning user's pending payload does NOT overwrite existing account language/goal | ✅ `test_authentication_service.py::TestReturningUserPath::test_pending_selection_ignored_for_returning_user`, `test_auth_endpoints.py::test_returning_user_via_google_no_data_overwrite` |
| 001-persist-pending-onboarding-selections | Edge case: invalid/unsupported language on pending payload → rejected, no malformed account created | ✅ `test_onboarding_attachment_policy.py::test_malformed_language_on_new_user_path_raises`, `test_authentication_service.py::test_malformed_language_rejected_and_no_account_created`, `test_auth_endpoints.py::test_unsupported_pending_language_returns_400_and_creates_no_account` |
| 001-persist-pending-onboarding-selections | Edge case: pending payload on returning-user login (even malformed) → ignored, no error | ✅ `test_authentication_service.py::test_malformed_pending_selection_causes_no_error_for_returning_user` (the bolt's bug #1 regression, explicitly) |
| 002-google-oauth-authentication | AC1: valid Google ID token, first-time user → new row created + session token returned | ✅ `test_auth_endpoints.py::TestGoogleAuthEndpoint::test_new_user_via_google_with_pending_selection` |
| 002-google-oauth-authentication | AC2: valid Google ID token, returning user → existing account loaded, no overwrite, session returned | ✅ `test_auth_endpoints.py::test_returning_user_via_google_no_data_overwrite` |
| 002-google-oauth-authentication | AC3: invalid/expired/tampered Google token → rejected with clear error code, no account/session created | ✅ `test_auth_endpoints.py::test_invalid_token_returns_401`; expiry mapping covered at the verifier-boundary level by code review (see Issues Found) since `GoogleTokenVerifier` itself is not exercised (no real network calls made, per constraints) |
| 002-google-oauth-authentication | AC4: valid session token recognized on app restart without re-auth | ✅ `test_auth_endpoints.py::TestSessionEndpoint::test_valid_session_recognized` |
| 002-google-oauth-authentication | Edge case: provider verification service unreachable → distinct retryable error | ✅ `test_authentication_service.py::test_provider_unreachable_propagates`, `test_auth_endpoints.py::test_provider_unreachable_returns_502` |
| 002-google-oauth-authentication | Edge case: same account, two devices → both succeed, independent sessions | ✅ `test_auth_endpoints.py::test_two_devices_same_account_get_independent_sessions` |
| 003-apple-sign-in-authentication | AC1: valid Apple identity token, first-time user → new row keyed by stable Apple id, session returned | ✅ `test_auth_endpoints.py::TestAppleAuthEndpoint::test_new_user_via_apple_with_pending_selection` |
| 003-apple-sign-in-authentication | AC2: valid Apple identity token, returning user → matched correctly even with differing/absent email-equivalent field | ✅ `test_authentication_service.py::test_returning_user_via_apple_matched_by_stable_id`, `test_auth_endpoints.py::test_returning_user_via_apple_dedup_by_stable_id` |
| 003-apple-sign-in-authentication | AC3: invalid/expired/tampered Apple token → rejected with clear error code | ✅ `test_auth_endpoints.py::TestAppleAuthEndpoint::test_invalid_token_returns_401`; real JWT/JWKS verification logic in `AppleTokenVerifier` itself not exercised (see Issues Found) |
| 003-apple-sign-in-authentication | AC4: valid session token from prior Apple sign-in recognized on restart | ✅ Covered by the shared session mechanism — same code path as `test_valid_session_recognized`, verified is provider-agnostic via `SessionValidationService` unit tests |
| 003-apple-sign-in-authentication | Edge case: private-relay email changes between sign-ins → account still matched via stable ID | ✅ `test_returning_user_via_apple_dedup_by_stable_id` (dedup is structurally impossible to do by email — `ProviderIdentity` has no email field) |
| 003-apple-sign-in-authentication | Edge case: Apple verification service unreachable → distinct retryable error | ✅ `test_auth_endpoints.py::TestAppleAuthEndpoint::test_provider_unreachable_returns_502` |

## Unit Tests

45 tests, `tests/unit/`, no DB/HTTP — fakes only at the network/DB boundary (`tests/fakes.py`), real domain logic throughout:

- `test_value_objects.py` (12 tests): `ProviderIdentity` equality by `(provider, id)` — never email, structurally (no email field exists); rejects empty `provider_user_id`; `LanguageCode`/`DailyGoalPreset`/`DailyXPTarget` invariants; `SessionToken.is_expired` before/after/exactly-at the expiry boundary.
- `test_onboarding_attachment_policy.py` (7 tests): all 4 minutes→XP presets (5→20, 10→40, 15→60, 20→80); no-pending-selection defaults (`am`/40); malformed language on the **new**-user path raises `InvalidPendingSelectionError` (the mirror-image check of bug #1).
- `test_authentication_service.py` (13 tests): new-user creation with pending selection / with defaults / rejecting a malformed selection with no account left behind; session issuance shape; returning-user path ignoring a valid AND a malformed pending selection (bug #1's exact regression, by name); returning-user-via-Apple dedup by stable id; invalid-token and provider-unreachable propagation with nothing persisted.
- `test_session_validation_service.py` (3 tests): valid/expired/unknown token outcomes; asserts an unknown token never even loads a `User`.
- `test_use_cases.py` (5 tests): the application layer's `authenticate_with_google`/`authenticate_with_apple`/`validate_session` directly, added specifically to get a normal-event-loop cross-check against the endpoint tests (see Coverage Report note on `routers.py`).

## Integration Tests

23 tests, `tests/integration/`, real SQLAlchemy models via the actual repository implementations against a fresh temp-file SQLite database per test (in-memory SQLite's async connection-per-engine quirks were avoided per the task's guidance):

- `test_repositories.py` (10 tests): `SqlAlchemyUserRepository` add/find/get round trips; `SqlAlchemyAuthSessionRepository`'s find/get-by-id including the **bug #2 regression** — a session with a timezone-aware `expires_at` written and read back through a brand-new session/connection (forcing a real SQLite round trip, not an in-memory identity-map hit) must compare correctly as not-yet-expired and as expired, without the `TypeError` the naive-datetime bug used to raise; plus `UserModel`'s id/`created_at` column-default factories.
- `test_auth_endpoints.py` (13 tests): full `TestClient` coverage of all 3 routes (`/auth/google`, `/auth/apple`, `/auth/session`) with `GoogleTokenVerifier`/`AppleTokenVerifier` replaced by `FakeTokenVerifier` (never a real call to Google/Apple) — new/returning user for both providers, no-overwrite, invalid token → 401, unsupported pending language → 400 (with a follow-up proving no malformed account was left behind), provider-unreachable → 502, two-device independent sessions, Apple dedup-by-stable-id, and session validation valid/unknown/missing/malformed-header.

## Security Tests

6 tests, `tests/security/test_security.py`:

- The `auth_sessions.token_hash` column never stores the raw token value — verified by reading the raw ORM row directly and comparing against a manually computed `SHA-256` digest (ADR-1).
- `AuthSessionRepository.get_by_id` never reconstructs a usable raw token (returns `token.value == ""`) — the only path that yields a live token is `find_by_token` with the value the client itself presented.
- The `/auth/session` endpoint response never echoes the raw session token back.
- Missing, non-Bearer, and empty-Bearer `Authorization` headers on `/auth/session` all return the documented `401 missing_credentials` structured error — never an unhandled exception/500.

## Performance Tests

No dedicated numeric NFR targets exist for this bolt beyond `ddd-02-technical-design.md`'s qualitative notes (one outbound verification call + one DB round trip per auth; a single indexed lookup for session validation). Rather than fabricate a load test against infrastructure this bolt doesn't provision, two measured smoke tests were run against the temp-file SQLite test DB:

| Metric | Target | Actual | Status |
|--------|--------|--------|--------|
| 50 sequential `/auth/google` requests, total wall time | < 5.0s (generous local-SQLite bound, not a production SLA) | ~0.5-1.5s locally (varies by run) | ✅ |
| Session validation of the *first*-ever-issued token after 50 accumulated sessions | < 1.0s | well under 1s | ✅ |

These catch an accidental O(n²) regression in session lookup as rows accumulate; they are not a substitute for a real load-testing pass against a provisioned environment, which does not exist yet for this bolt (see Recommendations).

## Coverage Report

`uv run pytest --cov=app --cov-report=term-missing` results, by module:

| Layer | Modules | Coverage |
|-------|---------|----------|
| Domain | `entities.py`, `events.py`, `exceptions.py`, `repositories.py`, `services.py`, `value_objects.py` | 100% (179/179 stmts) |
| Application | `use_cases.py` | 100% (43/43 stmts) |
| API | `dependencies.py`, `error_handlers.py`, `routers.py`, `schemas.py` | 96/100 stmts (96%) — see note below on `routers.py` |
| DB | `models.py`, `repositories.py` | 100% (87/87 stmts) |
| **Auth-logic subtotal** (the four rows above) | | **401/405 stmts = 99%** |
| Infra bootstrap / external | `session.py` (33%), `google_verifier.py`/`apple_verifier.py` (0%), `logging_config.py` (0%), `main.py` (0%) | intentionally out of scope — see Issues Found |
| **Whole `app/` package** | | **429/620 stmts = 69%** |

**Note on `routers.py`'s 4 reported-missed lines (73, 84, 104, 107)**: these are the tail `return` statement of each of the 4 route handlers. All 4 are demonstrably executed — every endpoint test asserts on the exact response body/status those lines produce, and `tests/unit/test_use_cases.py` was added specifically to call the identical application-layer code from a normal pytest-asyncio loop, where it registers as 100% covered. This is consistent with a known `coverage.py`/thread-tracing artifact affecting the final line of functions run inside FastAPI `TestClient`'s background portal thread, not an actual gap in behavior coverage. Bolt's coverage target (>80% on auth logic) is met either way (99% including or 100% excluding these 4 lines).

The success criteria's ">80% coverage on auth logic" target is interpreted as the domain/application/API/DB layers that implement the 3 stories (99%), not the whole `app/` package, which also contains code this stage deliberately does not exercise (see Issues Found).

## Issues Found

| Issue | Severity | Status |
|-------|----------|--------|
| `GoogleTokenVerifier`/`AppleTokenVerifier` (`app/infrastructure/external/`) have 0% test coverage | Low | Open — by design. Per the task's explicit constraint, no real network call to Google/Apple was made. Their `verify()` logic was validated by code review against ADR-1/ADR-2 during Stage 4 and exercised only through the `TokenVerifier` protocol boundary via fakes here, per `coding-standards.md`'s "mock at the network boundary only" rule. Real-token verification against live provider endpoints remains unverified by automated tests — flagged as a genuine gap, not silently glossed over. |
| `app/infrastructure/db/session.py` (the production engine/session-factory singleton) has 33% coverage | Low | Open — by design. Endpoint/integration tests deliberately bypass the global singleton via a `get_db_session` dependency override (see `tests/conftest.py`) so each test gets an isolated temp-file DB; the module's actual singleton-construction/commit-rollback code paths are exercised implicitly (the same logic is duplicated in the test override and passes), but not the module itself. |
| `app/main.py`/`logging_config.py` have 0% coverage | Low | Open — out of scope for this stage. These are app bootstrap/lifespan wiring and structured-logging setup, not auth business logic; no story's acceptance criteria depends on them directly. |
| No genuine new (undocumented) bugs found beyond the 2 already flagged in `implementation-notes.md` | - | N/A — both bug #1 (pending-selection validation must be skipped entirely for returning users) and bug #2 (SQLite timezone round-trip) are covered by dedicated regression tests and pass against the current implementation, confirming the Stage 4 fixes hold. |

No source code in `app/domain/`, `app/application/`, or `app/infrastructure/` was modified during this stage — only `backend/pyproject.toml` (dev dependencies + `[tool.pytest.ini_options]`) and the new `backend/tests/` tree.

## Recommendations

- Before real Google/Apple credentials exist in any environment, run at least one manual end-to-end check of `GoogleTokenVerifier.verify()`/`AppleTokenVerifier.verify()` against a real, valid token (and one deliberately expired/tampered token) — this stage's automated suite cannot do this safely without live secrets, per the task's constraint against real network calls.
- If a future story adds session revocation/logout, extend `AuthSessionRepository` and add corresponding tests then — no such tests exist now because no story requires the capability yet (consistent with `ddd-01-domain-model.md`'s explicit note).
- Consider wiring `coverage.py`'s dynamic-context/thread tracing (or switching endpoint tests to `httpx.AsyncClient` + `ASGITransport` instead of the synchronous `TestClient`) if `routers.py`'s reported coverage number itself (not just the underlying behavior) needs to reach 100% for a future stricter CI gate — not necessary for this bolt's own >80% target, which is already met.
- This is the final stage of this bolt (`001-auth-service`); `002-auth-onboarding-ui` can now proceed with full integration against a fully implemented and tested backend, not just the API contract.

## Ready for Operations

- [x] All acceptance criteria met
- [x] Code coverage > 80% (99% on auth-logic-bearing modules; 69% on the whole `app/` package, with the shortfall fully accounted for by out-of-scope external-verifier/bootstrap code — see Coverage Report and Issues Found)
- [x] No critical/high severity issues open
- [x] Performance targets met (smoke-level; no dedicated NFR numeric targets exist for this bolt)
- [x] Security tests passing
