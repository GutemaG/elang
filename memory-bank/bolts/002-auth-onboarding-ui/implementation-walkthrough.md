---
stage: implement
bolt: 002-auth-onboarding-ui
created: 2026-09-15T13:40:00Z
---

## Implementation Walkthrough: Auth & Onboarding UI

### Summary

Built the full pre-lesson-loop Flutter screen flow — splash, skippable onboarding carousel, language selection, daily-goal selection, and a Google/Apple sign-in screen with an inline OAuth error/retry banner — matching the exported Stitch "Highland Pulse" designs. The flow runs against a local pending-selection store, a session-check router, and a mock `AuthApi`, since `001-auth-service`'s real contract isn't available yet.

### Structure Overview

New code lives under `lib/features/auth/` (the five screens, the route table, the session-check/routing decision, and the sign-in screen's state controller) and `lib/shared/` (design tokens, reusable tactile-button/selectable-card widgets, models, and the storage/repository/API-boundary services other features will also depend on). `main.dart` was rewritten from the default Flutter counter demo to construct one `AuthDependencies` bag and hand it to the auth route table. Navigation uses a flat named-route table (`AuthRoutes`) driven by `Navigator.pushReplacementNamed`/`pushNamed` rather than a routing package, since the flow is linear with only two branch points (valid-session skip at splash; carousel's "Log In" skip-to-sign-in).

### Completed Work

- [x] `lib/shared/theme/app_colors.dart` - Highland Pulse color tokens, mirrored 1:1 from `highland_pulse/DESIGN.md`'s YAML front matter
- [x] `lib/shared/theme/app_spacing.dart` - spacing and corner-radius tokens converted from DESIGN.md's rem values to logical pixels
- [x] `lib/shared/theme/app_typography.dart` - the Plus Jakarta Sans type scale (display/headline/body/label sizes) from DESIGN.md
- [x] `lib/shared/theme/app_theme.dart` - builds the app's `ThemeData`/`ColorScheme`/`TextTheme` from the token files above
- [x] `lib/shared/widgets/tactile_button.dart` - reusable pill button implementing the "3D bottom-bevel press" effect used for every primary/secondary/provider CTA
- [x] `lib/shared/widgets/selectable_option_card.dart` - reusable single-select tactile card (selected/selectable/disabled states) shared by language and daily-goal selection
- [x] `lib/shared/models/pending_onboarding_selection.dart` - language + daily-goal choice pair, with JSON (de)serialization
- [x] `lib/shared/models/session_state.dart` - token + expiry, with the "expired counts as no session" validity rule
- [x] `lib/shared/services/secure_storage_service.dart` - abstract storage interface plus the real `flutter_secure_storage`-backed implementation
- [x] `lib/shared/services/onboarding_repository.dart` - holds in-progress language/goal choices in memory and only persists the pending selection once both are known; reads (without clearing) at sign-in time
- [x] `lib/shared/services/session_repository.dart` - reads/writes the stored session and clears it on demand
- [x] `lib/shared/services/auth_api.dart` - the `AuthApi` interface (`signInWithGoogle`/`signInWithApple`), plus the `AuthResult`/`AuthSuccess`/`AuthFailure`/`AuthFailureReason` result types this UI's sign-in flow depends on
- [x] `lib/shared/services/fake_auth_api.dart` - mock `AuthApi` implementation (simulated latency, optional forced-failure mode) standing in for `001-auth-service`
- [x] `lib/shared/screens/home_placeholder_screen.dart` - minimal stub destination for "user is signed in / has a valid session"; the real home screen is a separate, future intent
- [x] `lib/features/auth/auth_flow_controller.dart` - the session-check/routing decision service: reads session state, returns "go home" or "go to onboarding"
- [x] `lib/features/auth/auth_dependencies.dart` - constructs and threads the shared storage/repository/API instances through the route table
- [x] `lib/features/auth/auth_routes.dart` - the named-route table for the whole flow
- [x] `lib/features/auth/state/sign_in_controller.dart` - screen-local sign-in state machine (idle/in-flight/error-cancelled/error-failed), the single-flow-at-a-time concurrency guard, and the retry path
- [x] `lib/features/auth/screens/splash_screen.dart` - brewing-progress animation running in parallel with the session check; routes to home or the carousel
- [x] `lib/features/auth/screens/onboarding_carousel_screen.dart` - 3-slide swipeable/skippable carousel with a screen-local dot indicator and the "Log In" escape hatch
- [x] `lib/features/auth/screens/language_selection_screen.dart` - data-driven course list (Amharic live, Afaan Oromo disabled/"coming soon")
- [x] `lib/features/auth/screens/daily_goal_selection_screen.dart` - 4 single-select goal presets, Regular/10-min selected by default
- [x] `lib/features/auth/screens/sign_in_screen.dart` - equal-prominence Google/Apple buttons, the inline error/retry banner, and the ToS/privacy footer
- [x] `lib/main.dart` - rewritten from the default Flutter counter demo to boot straight into the auth flow's route table

### Key Decisions

- **DESIGN.md as the literal token source**: rather than hand-picking just the three headline brand colors, every color/spacing/radius/type token in `highland_pulse/DESIGN.md`'s front matter was mirrored into `AppColors`/`AppSpacing`/`AppRadii`/`AppTypography`, since that YAML is exactly what the Stitch `code.html` exports use — keeping the Flutter tokens traceable 1:1 to the pixel/layout reference.
- **No routing package**: the flow is linear with only two branch points, so a flat `Map<String, WidgetBuilder>` route table plus `Navigator.pushReplacementNamed`/`pushNamed` was used instead of pulling in `go_router` or similar.
- **Plain constructor-injected dependency bag**: `AuthDependencies` is a simple class built once in `main.dart`, not a service-locator or DI framework, since the project has neither today.
- **`SignInController` as a `ChangeNotifier`, not embedded `StatefulWidget` logic**: keeps the concurrency guard, error-state machine, and retry logic in one testable unit separate from widget-tree code, per the plan's "SignInInFlight notifier" note.
- **Sealed `AuthResult`**: used Dart 3's sealed classes (`AuthSuccess`/`AuthFailure`) instead of a boolean+nullable-error pattern, so failure handling is exhaustive at compile time.
- **Data-driven course/goal lists**: `CourseOption`/`GoalOption` are `const` data lists rendered with a loop, not individually hand-built widgets, specifically so a second live course is a data change later (an explicit acceptance criterion).

### Deviations from Plan

- **No native Google Sign-In / Sign in with Apple SDK plugins added.** The plan listed these as bolt dependencies, but this stage's scope (per the task brief) is UI built and exercised against a mock `AuthApi`, not real OAuth triggers. `SignInController` calls `AuthApi` directly with a placeholder token string instead of invoking a native SDK. Wiring the real SDKs is deferred to whenever `001-auth-service`'s contract lands and native sign-in is actually implemented — flagged in code with a `NOTE:` comment at the call site in `sign_in_controller.dart`.
- **No bundled illustration assets.** The Stitch exports reference remote-generated images (googleusercontent URLs) for the mascot and carousel slide art. No image assets ship with this bolt, so the splash mascot and carousel slides use Material icons on tinted rounded containers as stand-ins for the illustrated artwork, matching the color/shape language but not the actual artwork.
- **Carousel header has no back button.** The Stitch export includes a back button in the carousel's top bar, but there's no earlier screen to return to in this flow (splash doesn't wait for input), so it was dropped rather than wired to a no-op.
- **Sign-in screen's "Already have an account? Log In" footer link is non-interactive.** This is already the app's only sign-in screen (a single OAuth flow serves both new and returning users), so there's nowhere else for that link to go; it's omitted rather than pointing at a dead-end route.
- **Cross-screen step-numbering chrome omitted**, per the plan's own "Checkpoint Decisions" section — the exported "1/3", "STEP 2 OF 3", "STEP 5 OF 5" badges were intentionally not built.

### Dependencies Added

- [x] `flutter_secure_storage: ^9.2.4` - Keychain/Keystore-backed storage backing `SecureStorageService`, used by both `OnboardingRepository` and `SessionRepository`

### Developer Notes

- `OnboardingRepository` holds the in-progress language/goal choice in memory and only writes to secure storage once both are set — this is what makes the "app killed mid-selection leaves no partial state" edge case work without any extra guard code; there was nothing to write yet.
- `FakeAuthApi` takes an optional `failureReason` constructor argument specifically so the inline error/retry banner can be exercised manually during development (construct it with `AuthFailureReason.networkError`, etc., in `main.dart` temporarily) without needing a real backend.
- Logging: the only log line in this flow is `debugPrint('Sign-in attempt failed: $reason')` in `sign_in_controller.dart`, which logs only the enum value — never the OAuth token or the pending selection contents.
- Once `001-auth-service` publishes its real contract, only `lib/shared/services/fake_auth_api.dart` needs to be replaced with a real implementation of `lib/shared/services/auth_api.dart`'s `AuthApi` interface; no screen or controller code should need to change.
