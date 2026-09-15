---
stage: implement
bolt: 003-auth-onboarding-ui
created: 2026-09-15T15:30:00Z
---

## Implementation Walkthrough: Auth & Onboarding UI — Real Backend Integration

### Summary

Replaced the mock `FakeAuthApi` with a real, HTTP-backed `AuthApi` implementation that calls the three live `001-auth-service` endpoints, and replaced the sign-in flow's hardcoded placeholder tokens with real native Google/Apple OAuth SDK calls. A `GET /api/v1/auth/session` client was built as a deliverable but deliberately left unwired, per the plan's binding decision. Sign in with Apple's real SDK path is gated to iOS only; Android never invokes it. All work stayed within the Flutter client — the backend was not touched.

### Structure Overview

The network boundary (`HttpAuthApi`) and the native-SDK boundary (`GoogleNativeSignIn`/`AppleNativeSignIn`) are two separate, independently testable layers, exactly as the plan's "chosen" design shape specified. `HttpAuthApi` knows nothing about platform plugins; the native-SDK wrappers know nothing about HTTP. `SignInController` sits between them: it calls the native-SDK layer first, and only on success does it call the network layer, short-circuiting on cancellation or native failure without ever reaching the network. `AuthDependencies` is the single place in the real app that decides `HttpAuthApi` is now the default (previously `FakeAuthApi`); `SignInController`'s native collaborators default to the real plugin wrappers unless overridden, which is how tests substitute fakes without needing a different production code path. Configuration constants live in one small `AuthConfig` class, mirroring the backend's own `.env.example` placeholder convention.

### Completed Work

- [x] `lib/shared/config/auth_config.dart` — placeholder OAuth/API configuration constants (Google client/server IDs, Apple Services/Bundle/Team/Key IDs, API base URL), each an obvious placeholder string with a `TODO(deploy)` header pointing at the intended `--dart-define-from-file` mechanism for real values.
- [x] `lib/shared/services/http_auth_api.dart` — real `AuthApi` implementation calling `POST /api/v1/auth/google` / `/apple` via the `http` package, parsing a 200 response into `AuthSuccess`, and mapping every documented error code plus network-level/malformed-response failures to the correct `AuthFailureReason` per the plan's error-mapping table. Never logs tokens or payload contents.
- [x] `lib/shared/services/session_api.dart` — thin client for `GET /api/v1/auth/session` (Bearer-token auth header, valid/invalid/error outcomes). Built per the story's AC reference to the endpoint; intentionally not called from anywhere else in the app.
- [x] `lib/features/auth/state/native_sign_in.dart` — the `NativeSignIn` collaborator interface plus its two typed failure exceptions (cancellation vs. any other failure), and the two real implementations: `GoogleNativeSignIn` (wired on both platforms) and `AppleNativeSignIn` (gated to iOS; throws a graceful "not available on this platform" failure everywhere else, never invoking the plugin). Both implementations catch every native-SDK failure mode — including a missing/unconfigured platform implementation — and surface it as the same typed failure exception rather than letting a raw platform error propagate.
- [x] `lib/features/auth/state/sign_in_controller.dart` — updated `signIn()` to acquire a token from the relevant `NativeSignIn` collaborator before calling `AuthApi`; a cancellation sets `SignInStatus.errorCancelled` and returns without any network call, and any other native failure sets `SignInStatus.errorFailed` the same way. The constructor gained two optional collaborator parameters, defaulting to the real implementations.
- [x] `lib/features/auth/screens/sign_in_screen.dart` — gained two optional pass-through constructor parameters (`googleSignIn`, `appleSignIn`) so callers/tests can override the native collaborators; both default to `null`, which keeps the real app's behavior (and every existing call site's source) unchanged.
- [x] `lib/features/auth/auth_dependencies.dart` — now constructs `HttpAuthApi` instead of `FakeAuthApi` as the default `AuthApi`.
- [x] `ios/Runner/Info.plist` — added a `CFBundleURLTypes` entry with a placeholder reversed-client-ID URL scheme for Google's OAuth redirect.
- [x] `ios/Runner/Runner.entitlements` (new) — declares the `com.apple.developer.applesignin` capability.
- [x] `ios/Runner.xcodeproj/project.pbxproj` — added the entitlements file reference and wired `CODE_SIGN_ENTITLEMENTS` into all three Runner target build configurations (Debug/Release/Profile).
- [x] `pubspec.yaml` — added `http`, `google_sign_in`, `sign_in_with_apple` at their real, pub.dev-resolved current versions.
- [x] `test/shared/services/http_auth_api_test.dart` (new) — covers every row of the error-mapping table, a success path (with and without a pending selection), and malformed/missing-field/network-level failure cases, all against a mocked `http.Client`.
- [x] `test/features/auth/state/sign_in_controller_native_test.dart` (new) — covers the new cancellation-before-network-call and failure-before-network-call paths at the controller level, plus that a successful native step proceeds into `AuthApi` and that `retry()` re-invokes the native step.
- [x] `test/helpers/fake_native_sign_in.dart` (new) — deterministic `NativeSignIn` test double (success / cancelling / failing) used by both new and updated tests.
- [x] `test/features/auth/sign_in_screen_test.dart` — updated only to inject the new fake native-SDK collaborators into `SignInScreen` (see Deviations below); no assertions changed.

### Key Decisions

- **Two independent collaborator layers, not one merged client**: keeps `HttpAuthApi` testable with only a mocked `http.Client` (no platform plugins involved at all), matching the plan's explicitly "chosen" shape over the alternative of folding native-SDK calls into `HttpAuthApi` itself.
- **Broad catch-all in both native-SDK wrappers**: beyond the provider's own typed cancellation/error, any other exception (including "no platform implementation registered") is caught and reported as the same graceful `NativeSignInFailedException`, per the story's own edge case ("native SDK plugin not configured... should fail gracefully, not crash the app").
- **Apple gated to iOS via `defaultTargetPlatform`, not `dart:io`'s `Platform`**: this project has a `web/` target (and desktop targets) where `dart:io` isn't universally available; `package:flutter/foundation.dart`'s `defaultTargetPlatform` is the platform-agnostic equivalent already idiomatic in Flutter code.
- **`invalid_pending_selection` → `providerError`**: accepted as-is per the plan's binding checkpoint decision — not worth a 4th `AuthFailureReason` value.
- **`GET /api/v1/auth/session` built but unused**: per the plan's binding checkpoint decision, `AuthFlowController` still only performs a local-expiry check at splash time; no network call was added to the app's launch path.

### Deviations from Plan

- **`SignInScreen` required a small change, not zero.** The plan's AC list stated `SignInScreen` would need zero source changes, and separately stated the existing 24 widget tests must keep passing unmodified. Once real native SDKs are wired with no test-environment implementation, any widget test that taps a sign-in button and doesn't supply a fake native-SDK collaborator hits an unavoidable platform error (verified directly: `google_sign_in`'s placeholder platform interface throws `UnimplementedError` in the test environment). There is no code-only way to keep both "SignInScreen has zero changes" and "old tests pass unmodified" once a real, un-mockable-by-default native SDK sits in front of the network call. Resolved by adding two optional, backward-compatible constructor parameters to `SignInScreen` (default `null`, preserving the real app's behavior at every existing call site) and updating `sign_in_screen_test.dart`'s single helper function to pass a fake collaborator — no test assertion changed, only the widget construction helper. This is exactly the class of finding the plan invited being reported rather than forced.
- **Real package versions differ from the plan's guesses**: pub.dev resolved `http: 1.6.0`, `google_sign_in: 7.2.0`, `sign_in_with_apple: 8.2.0` (the plan's placeholders were `1.2.2`/`7.1.0`/`6.1.4`). `google_sign_in`'s actual 7.x API (`GoogleSignIn.instance.initialize()` + `.authenticate()`, `GoogleSignInException`/`GoogleSignInExceptionCode.canceled`) and `sign_in_with_apple`'s 8.x API (`SignInWithApple.getAppleIDCredential()`, `SignInWithAppleAuthorizationException`/`AuthorizationErrorCode.canceled`) were confirmed directly against the installed package source rather than assumed from memory.
- **Android manifest**: no changes made, as anticipated by the plan (no Firebase-style `google_sign_in` setup needed; Apple's Android path is deferred, not stubbed).

### Dependencies Added

- [x] `http` — HTTP client for the three live `001-auth-service` endpoints.
- [x] `google_sign_in` — native Google OAuth flow, wired on both Android and iOS.
- [x] `sign_in_with_apple` — native Apple OAuth flow, wired on iOS only per this bolt's binding checkpoint decision.

### Developer Notes

- `HttpAuthApi`'s error mapping only branches on HTTP status code, not `error_code` — every status the backend actually returns for these two endpoints already maps to exactly one outcome (401 → providerError, 400 → providerError, 502 → networkError), so parsing `error_code` would add no discriminating power; if the backend ever adds a second 4xx meaning under the same status code, this mapping will need to start reading `error_code`.
- The native-SDK collaborators call `initialize()`/authenticate lazily and only once per `GoogleNativeSignIn` instance (`_initialized` guard) — `SignInController` is expected to own one long-lived instance per screen, not construct a fresh one per tap.
- Real Google/Apple developer console values (client IDs, Team/Key IDs) are still placeholders — sign-in will not actually succeed end-to-end against real providers until those are supplied via the deployment mechanism noted in `auth_config.dart`'s header comment. This was explicitly out of scope per the story.
- `flutter analyze` is clean and `flutter test test/` passes all 24 pre-existing tests plus 17 new ones (41 total).
