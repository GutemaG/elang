---
stage: test
bolt: 003-auth-onboarding-ui
created: 2026-09-15T16:15:00Z
---

## Test Report: Auth & Onboarding UI — Real Backend Integration

### Summary

- **Tests**: 49/49 passed (`flutter test test/`)
- **Coverage**: 41 pre-existing tests (unchanged, still passing) + 8 new real end-to-end tests added this stage. No regressions.
- A real instance of the `backend/` FastAPI app was started as a live process (`uv run uvicorn app.main:app --port 8000`, against a fresh, throwaway, gitignored SQLite `dev.db` created via `uv run alembic upgrade head`) and hit with genuine HTTP requests from Dart's real `http.Client` — no mocking on either side. The server was confirmed up via `GET /health` before any test ran, and stopped cleanly afterward; the throwaway `dev.db` was deleted (it is also covered by `backend/.gitignore`'s `*.db`/`dev.db` entries, so it would not have been committed either way).

### Test Files

- [x] `test/shared/services/http_auth_api_e2e_test.dart` (new) — genuine integration test against a live backend process. Covers: garbage Google/Apple tokens → real 401 `invalid_token` → `HttpAuthApi` → `AuthFailure(providerError)`; `GET /session` with an effectively-empty Authorization value and with no header at all → real 401 `missing_credentials`, handled by `SessionApi` without throwing (`SessionCheckStatus.error`); `GET /session` with a garbage-but-present Bearer token → real `200 {"valid": false}` → `SessionApi` → `SessionCheckStatus.invalid`; malformed non-JSON body and a body missing the required `id_token` field → both real `422`s (FastAPI/Pydantic validation errors, discovered — not previously documented in this bolt's error-mapping table). Clearly marked at the top of the file as requiring a running backend and not passing in isolation; includes the exact `uv run uvicorn app.main:app --port 8000` command a human needs to run first.
- [x] `test/shared/services/http_auth_api_test.dart` (Stage 2, unmodified) — mocked `http.Client` coverage of the full error-mapping table and the 200-success parse path.
- [x] `test/features/auth/state/sign_in_controller_native_test.dart` (Stage 2, unmodified) — native-SDK cancellation/failure short-circuit coverage via fakes.
- [x] All other pre-existing test files (`test/features/**`, `test/widget_test.dart`, `test/helpers/**`) — unmodified, still passing.

### Acceptance Criteria Validation

- ✅ **`HttpAuthApi` implements `AuthApi` and calls the real endpoints with the exact request shape**: confirmed twice over — Stage 2's mocks assert the request body shape, and this stage's e2e test proves the real server actually accepts that shape and responds in the shape `HttpAuthApi` expects (real round trip, not just two independent assumptions).
- ✅ **A 200 response parses into `AuthSuccess`**: verified only via Stage 2's mocked test (see Notes — no real-provider 200 is obtainable in this environment).
- ✅ **Each documented error code maps correctly**: `invalid_token` (401) verified for real against the live server for both Google and Apple in this stage; `expired_token`, `invalid_pending_selection`, `provider_unreachable` remain verified only via Stage 2's mocks (none of these are reachable for real without a valid-but-expired token, a real pending-selection validation bug, or a simulated upstream outage — none of which this environment can produce).
- ✅ **Native-SDK cancellation short-circuits before any network call**: verified via Stage 2's fakes; unchanged and unaffected by this stage (no native plugin can run in this test environment regardless).
- ✅ **Config values are placeholders, not secrets**: unchanged from Stage 2; `AuthConfig.apiBaseUrl` (`http://localhost:8000`) is exactly the value this stage's e2e test pointed at, confirming the default matches a real local dev server's actual address.
- ✅ **Existing 24 (now 41, pre-this-stage) tests still pass unmodified; new tests added**: confirmed — full suite is 49/49 green.
- ✅ **No tokens/secrets in logs**: the e2e test sends only garbage/synthetic strings, never a real credential; nothing new to leak.

### Issues Found

No backend bugs. Two real-server behaviors worth flagging (neither is a defect, both are useful discoveries from hitting the live process rather than only mocks):

1. **Malformed/incomplete request bodies return `422`, not one of the 4 documented domain error codes.** `POST /api/v1/auth/google` with a non-JSON body, or with valid JSON missing the required `id_token` field, returns FastAPI/Pydantic's own validation-error shape (`{"detail": [...]}`) at status `422` — this status was never in this bolt's error-mapping table (which only documents `401`/`400`/`502`, plus network-level failures). This is not reachable through real app usage (`HttpAuthApi` always constructs a well-formed body), so it required no code change — but if it ever were hit, `HttpAuthApi._mapResponse`'s `default` branch (any unexpected status → `networkError`) would apply. Recorded here for completeness since the plan explicitly asked this class of gap to be surfaced rather than silently discovered-and-ignored.
2. **A malformed-but-present `Authorization` header behaves identically to a missing one** (`401 missing_credentials`), and a Bearer scheme with an empty/whitespace token also collapses into that same case server-side — confirmed directly rather than inferred from `routers.py`'s source, closing a gap between reading the code and observing its actual behavior.

### Notes

**What the e2e check proved, precisely:**
- That `HttpAuthApi` and the real running backend agree on the wire format for the token-rejection error path, for both `/google` and `/apple` — same request field names, same response shape, same status code, on both sides genuinely exercised (no mock stood in for either the client or the server).
- That `SessionApi` and the real running backend agree on the wire format for both of `/session`'s non-provider-dependent outcomes: a real `401` (missing/malformed credentials) and a real `200 {"valid": false}` (a recognized-but-unknown/garbage token) — including the important, easy-to-get-wrong distinction that the latter is *not* an error status.
- Two real-server response shapes for request-malformation cases that weren't previously exercised by any test in this bolt.

**What the e2e check did NOT prove — stated explicitly, matching the same limitation already recorded in `memory-bank/bolts/001-auth-service/ddd-03-test-report.md`'s Issues Found section:**
- It did **not** prove a real Google or Apple OAuth token can be verified successfully end-to-end. There are no real developer-console credentials in this environment, and none were obtained or fabricated (per this task's constraints) — any token this test could construct is indistinguishable, from the verifier's perspective, from a garbage string, so only the *rejection* path could be exercised for real.
- It did **not** prove the 200-success parsing path (`AuthResponse` → `AuthSuccess`) against a genuine server-produced success response — that path is, and remains, verified only via Stage 2's synthetic mocked 200 response in `http_auth_api_test.dart`.
- It did **not** exercise `expired_token`, `invalid_pending_selection`, or `provider_unreachable` against the real server (none of these are producible without either a real-but-expired provider token, a genuine backend-side validation bug, or a way to simulate Google's/Apple's own servers being down) — those three rows of the error-mapping table remain verified only by Stage 2's mocks.
- It did **not** exercise anything native-SDK-related (`GoogleNativeSignIn`/`AppleNativeSignIn`) — no real device/platform plugin runs in this test environment; that boundary remains covered only by `sign_in_controller_native_test.dart`'s fakes.

**How to re-run this later:** start the backend (`cd backend && uv run alembic upgrade head && uv run uvicorn app.main:app --port 8000`) from a separate terminal, then run `flutter test test/shared/services/http_auth_api_e2e_test.dart` (or the full `flutter test test/`) from the repo root while it's up. The backend process used for this stage was stopped, and its throwaway `dev.db` deleted, before this report was written — nothing was left running.

This is the bolt's final stage. All three stages (Plan → Implement → Test) are now complete.
