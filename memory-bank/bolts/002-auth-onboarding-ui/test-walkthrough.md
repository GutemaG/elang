---
stage: test
bolt: 002-auth-onboarding-ui
created: 2026-09-15T15:10:00Z
---

## Test Report: Auth & Onboarding UI

### Summary

- **Tests**: 24/24 passed (`flutter test test/`)
- **Coverage**: Not measured via `flutter test --coverage` (no coverage tooling configured in this project yet); scope is smoke/interaction-level per `coding-standards.md`'s "UI screens get smoke/widget-level coverage" guidance, not exhaustive/line coverage. Every screen and every behavior called out in the plan's 12 acceptance criteria has at least one dedicated test, and `flutter analyze` reports no issues.

### Test Files

- [x] `test/features/auth/splash_screen_test.dart` - Buna wordmark + "Get Started" render; routing decision (no session / expired session -> onboarding carousel; valid session -> home, skipping onboarding) via `BunaApp` + the real route table
- [x] `test/features/auth/onboarding_carousel_screen_test.dart` - "Skip" and the "Log In" escape hatch both proceed correctly; swipe-driven slide advance; tapping "Continue" through all 3 slides then "Get Started" on the last slide proceeds to language selection
- [x] `test/features/auth/language_selection_screen_test.dart` - Amharic renders selected/selectable; Afaan Oromo renders disabled/"coming soon" with a "Join Waitlist" affordance and cannot be selected; tapping the disabled card doesn't change what gets persisted; Continue records the language choice
- [x] `test/features/auth/daily_goal_selection_screen_test.dart` - all 4 presets render; Regular/10-min is the default; selecting a different preset (Intense) changes what gets persisted; the "no partial state" edge case — nothing is written to storage after only the daily goal (or only the language) is chosen, and the combined pending selection is written only once both are known
- [x] `test/features/auth/sign_in_screen_test.dart` - Google/Apple buttons render at identical `Size` (via `tester.getSize`); tapping either disables both while in-flight; the concurrency guard (tapping Apple immediately after Google never reaches the `AuthApi` boundary a second time); a forced failure shows the inline error banner + Retry and leaves a pre-existing pending selection byte-for-byte untouched; cancelled vs. failed show the correct cancel-tone vs. failure-tone copy; Retry re-invokes the same provider; success routes to home
- [x] `test/widget_test.dart` - pre-existing root smoke test (kept, now sharing the in-memory storage fake below)
- [x] `test/helpers/in_memory_secure_storage_service.dart` - shared in-memory `SecureStorageService` fake (factored out of `widget_test.dart` so it isn't duplicated across 5+ test files)
- [x] `test/helpers/controllable_auth_api.dart` - `Completer`-backed `AuthApi` test double that records every call (provider, pending selection) and lets a test resolve each call at will; used for the sign-in screen's concurrency-guard and retry-provider assertions, which need exact call-count control that a fixed-`Duration` fake can't give deterministically under `pump()`

### Acceptance Criteria Validation

- ✅ **Splash screen performs the session-check and routes to carousel (no/invalid session) or signals a home-route decision (valid session) without rendering onboarding**: verified via `splash_screen_test.dart`'s three routing tests (no session, expired session, valid session)
- ✅ **Onboarding carousel is skippable and reaching the last slide or tapping "Skip" proceeds to language selection; carousel position is not persisted across restarts**: Skip and last-slide-CTA both verified. Non-persistence across restarts is a "nothing to tear down" property of the screen (no persistence code exists, and the plan explicitly scopes it out of Stage 3) — not independently testable as a positive assertion beyond "the widget holds no such state," which code review confirms; noted as a gap below.
- ✅ **Language selection screen renders Amharic as selectable and does not hardcode a single-item layout (Afaan Oromo shown as a locked/"coming soon" second entry)**: verified directly; the data-driven `_courseOptions` list (not a single hardcoded widget) is confirmed by both options rendering from one loop
- ✅ **Daily-goal screen renders all 4 presets (Casual/Regular/Serious/Intense) with one selected by default**: verified
- ✅ **Language + goal selections are written to secure local storage as pending state only after both are confirmed, and survive app kill/background before sign-in**: the "only after both are confirmed" half is verified directly (storage stays empty after either choice alone, and is populated once both are known). "Survives app kill/background" is inherently a persistence-layer property, not a UI one — verified indirectly by confirming the value is durably present in the same `SecureStorageService` fake across the two screens' independent widget trees, but a true kill/restart can't be simulated by a widget test; see gap below.
- ✅ **Sign-in screen renders Google and Apple buttons at identical size/weight/styling**: verified via `tester.getSize` equality on both `TactileButton`s
- ✅ **Tapping either provider button disables both buttons until that flow resolves**: verified (`onPressed` is `null` on both mid-flight, re-enabled after failure)
- ✅ **A successful Google or Apple flow calls the (interim/mocked) `AuthApi` with the provider token and any pending selection, then signals a route-to-home decision**: verified — success routes to the home stub; `ControllableAuthApi.pendingSelectionsSeen` confirms the pending selection is attached to the call
- ✅ **An OAuth failure/cancellation shows an inline error+retry banner on the same sign-in screen (no navigation to a separate error screen), with tone distinguishing user-cancel from actual failure**: verified — "Sign-in was cancelled" vs. "Something went wrong — try again", both rendered on the same screen/route
- ✅ **Retry re-triggers the same provider's flow; pending selections remain untouched through failure and retry**: verified — `ControllableAuthApi.calls` shows the same provider twice after Retry; storage value is asserted unchanged after a forced failure
- ✅ **No tokens, OAuth payloads, or pending-selection PII appear in logs**: verified by code inspection (the only log line, `debugPrint('Sign-in attempt failed: $reason')`, logs only the `AuthFailureReason` enum value); not independently re-asserted in a test since there's no token/PII to accidentally capture in the current mocked flow, and asserting the *absence* of a log call is a weak test. Flagged as a code-review item rather than a widget-test target.
- ✅ **All 5 screens have at least smoke-level widget test coverage**: satisfied by the 5 test files above (24 tests total)

### Issues Found

- **Layout overflow bug in `LanguageSelectionScreen`** (`lib/features/auth/screens/language_selection_screen.dart`): the "You can always add more languages anytime in your settings." caption was a bare `Text` inside a `Row` with no `Expanded`/`Flexible` wrapper. A `Row` gives non-flexible children their unconstrained preferred (single-line) width rather than letting them wrap, so this line overflowed its available width and threw a `RenderFlex overflowed` error the moment the screen was pumped in a test — and would show the same red/black overflow banner on a real phone-width device. **Fixed**: wrapped the `Text` in `Expanded`, which is the minimal change needed for it to wrap/center within the available width; no other layout, styling, or behavior changed. Re-verified with `flutter analyze` (clean) and the full test suite (all passing) after the fix.
- No other implementation bugs were found. All screens matched their documented behavior in `implementation-walkthrough.md`.

### Notes

- Per the task's constraint, mocking is confined to the network/storage boundary: `SecureStorageService` (in-memory fake) and `AuthApi` (`ControllableAuthApi`/`FakeAuthApi`-shaped test doubles). `OnboardingRepository`, `SessionRepository`, `AuthFlowController`, and `SignInController` all run as real code against those fakes in every test — no domain/state logic is mocked, per `coding-standards.md`.
- Two acceptance-criteria sub-clauses are **not fully verifiable by widget tests alone** and are called out explicitly rather than claimed as covered:
  1. "Carousel position is not persisted across restarts" and "selections survive app kill/background" are persistence-durability claims that need either a true process-restart (integration test with a real `flutter_secure_storage` backing, or a manual device test) or a code-review argument (no persistence code exists for carousel position; the pending-selection write path is a plain secure-storage write that would survive a restart the same way any other stored value would). Widget tests can only exercise a single widget-tree lifetime, so this remains a manual/integration-test gap.
  2. "No tokens/PII in logs" is verified by reading `sign_in_controller.dart`'s single `debugPrint` call site, not by an automated test — there's no practical way to assert a negative ("nothing sensitive was ever logged") against a real logger without over-fitting the test to today's implementation.
- The real native Google Sign-In / Sign in with Apple SDKs are still not wired up (this was already flagged as a Stage 2 deviation) — every sign-in test here exercises the `AuthApi` boundary and the sign-in screen/controller, not any real OAuth flow. That remains out of scope until `001-auth-service` publishes its contract.
- `flutter test --coverage` was not run (no `lcov`/coverage tooling set up in this project); "24/24 passed" and `flutter analyze`'s clean result are the two concrete, observed signals reported here.
