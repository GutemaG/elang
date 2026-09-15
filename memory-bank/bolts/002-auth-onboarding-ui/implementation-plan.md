---
stage: plan
bolt: 002-auth-onboarding-ui
created: 2026-09-15T12:52:20Z
---

## Implementation Plan: Auth & Onboarding UI

### Objective

Build the full pre-lesson-loop Flutter screen flow for Buna — splash → skippable onboarding carousel → language selection → daily-goal selection → Google/Apple sign-in (equal prominence) with inline OAuth failure/retry — matching the exported Stitch "Highland Pulse" designs, and wire it to the (not-yet-finalized) `001-auth-service` API contract behind a thin, swappable interface.

Covers all 4 stories in this bolt:

- 001-splash-and-onboarding-carousel
- 002-language-and-daily-goal-selection-screens
- 003-sign-in-screen-google-apple-equal-prominence
- 004-oauth-failure-inline-retry

### Deliverables

- **Splash screen** — maps to `stich-screens/.../1._buna_splash_screen/`. Shows Buna wordmark/mascot, a "brewing your lessons" progress indicator, and a "Get Started" CTA. Performs the session-check (secure storage) while the progress indicator runs, then routes to either the onboarding carousel (no/invalid session) or straight to home (valid session — routing decision only, home screen itself is out of scope).
- **Onboarding carousel** — maps to `2._onboarding_carousel/`. 3-slide, swipeable, skippable carousel (top-right "Skip", bottom dot indicator, "Continue"/final-slide CTA, "Already have an account? Log In" escape hatch). Does not persist slide position across app restarts (per story 001 edge case).
- **Language selection screen** — maps to `3._language_selection/`. Renders Amharic as the one live, selectable course card; renders Afaan Oromo as a visibly disabled/"coming soon" card with waitlist affordance. Layout must be a list/grid of course cards, not a single hardcoded widget, so adding a second live course later is a data change, not a layout rewrite.
- **Daily-goal selection screen** — maps to `4._daily_goal_selection/`. 4 preset cards (Casual/5min, Regular/10min — default-selected, Serious/15min, Intense/20min), single-select radio-style behavior.
- **Sign-in screen** — maps to `5._create_account_sign_in/`. "Continue with Google" and "Continue with Apple" as two visually identical pill buttons (same size/weight/border treatment, order per export: Google above Apple), plus "Log In" link and ToS/Privacy footer.
- **Inline OAuth error/retry state** — same sign-in screen, not a separate route. The Stitch export for `5._create_account_sign_in` already includes this inline variant (a soft-terracotta banner reading "Something went wrong — try again" with an inline "Retry" pill) directly beneath the two provider buttons — confirming the story 004 technical note's open question: no dedicated error screen is needed, the inline treatment already exists in-design.
- **Local pending-selection state holder**: a small local data/service layer (not tied to any one screen) that persists `PendingOnboardingSelection` (selectedLanguage, dailyGoalMinutes) to secure storage as soon as both are confirmed, survives app kill/background, and is read (not cleared) at sign-in time to attach to the auth request.
- **Session-check / routing service**: reads `SessionState` (token + validity) from secure storage at splash time and produces a routing decision (home vs. carousel). Treats "token exists but expired/invalid" as "no session."
- **Auth-service interface stub**: an abstract client (e.g. `AuthApi`/`AuthRepository`-shaped interface) defining the two calls this UI needs — `signInWithGoogle(idToken, pendingSelection?)` and `signInWithApple(identityToken, pendingSelection?)`, each returning a session token or a typed failure. Concrete implementation deferred until `001-auth-service`'s API contract lands; this bolt only needs the shape to build and test the UI against a fake/mock implementation.
- Widget tests for each of the 5 screens (smoke/interaction level, per `coding-standards.md`'s "UI screens get smoke/widget-level coverage" guidance) — written in Stage 3, scoped here.

### Dependencies

- **001-auth-service** (blocking for real integration, not for this Plan stage): this bolt's `bolt.md` currently has `blocks: true` / `requires_bolts: [001-auth-service]`. The backend bolt has not yet reached its Technical Design stage, so no concrete API contract (request/response shape, error codes) exists yet. This plan treats the two sign-in calls as an internal interface/placeholder (see "Auth-service interface stub" above) so Stage 2 (Implement) can proceed against a mock. The interface should be revisited and firmed up — but not necessarily rewritten — once `001-auth-service` publishes its contract. Full end-to-end (real network) testing remains blocked until that unit's Implement stage completes.
- **Google Sign-In SDK (Flutter plugin)** — native OAuth trigger, platform channel. Low risk, well-documented.
- **Sign in with Apple SDK (Flutter plugin)** — native OAuth trigger, platform channel. Low risk, well-documented. Required alongside Google per App Store policy (`tech-stack.md`).
- **flutter_secure_storage** (or equivalent Keychain/Keystore-backed package) — for `SessionState` and `PendingOnboardingSelection` persistence. Not yet in `pubspec.yaml` — needs adding in Stage 2.
- **Stitch "Highland Pulse" design exports** (`stich-screens/extracted/stitch_ethiopian_language_learning_app/`) — visual source of truth; colors/typography/component styles per `highland_pulse/DESIGN.md` (Plus Jakarta Sans; primary `#1B5E3B` Highland Acacia; secondary `#E08722` Simien Gold; tertiary `#D84A38` Rift Terracotta; pill buttons with 3D bottom-bevel press effect via `translateY` on tap).

### Technical Approach

- **File organization** (per `coding-standards.md`): all new code under `lib/features/auth/`, e.g. `screens/` (splash, onboarding_carousel, language_selection, daily_goal_selection, sign_in), with shared pieces in `lib/shared/services/` (secure storage wrapper, session/pending-selection repositories) and `lib/shared/models/` (`PendingOnboardingSelection`, `SessionState`).
- **Screen-to-export mapping** is 1:1 as listed in Deliverables. Reuse the token values from `highland_pulse/DESIGN.md` directly (color/typography/spacing/radius constants) rather than re-deriving styles from the HTML/Tailwind exports — treat the exports as pixel/layout reference, `DESIGN.md` as the values-of-record.
- **Routing**: a single top-level flow controller (e.g. a `GoRouter`/`Navigator` route table scoped to `features/auth/`) rather than per-screen ad hoc navigation, since the flow is strictly linear (splash → carousel → language → goal → sign-in) except for the two branch points (valid-session skip at splash; skip/skip-to-signin from carousel via "Log In").
- **Pending-selection lifecycle**: written to secure storage only once both language and goal are confirmed (per story 002 edge case — no partial/corrupted state on early app-kill); read-not-cleared at sign-in; left untouched on OAuth failure (story 004); a returning user's real account load should not let leftover local pending selections override server state (story 003 edge case) — the auth client should treat pending selection as "hint for first-time account setup only," a concern for the request-shaping logic, not the storage layer itself.
- **Sign-in button concurrency guard**: a simple in-flight boolean/state (e.g. a `SignInInFlight` notifier) disables both provider buttons the moment either OAuth flow starts, re-enabled on completion or failure — covers story 003's "tap Google then Apple" edge case.
- **Error/retry state**: modeled as a screen-local state enum (idle / in-flight / error-cancelled / error-failed) on the sign-in screen itself, not a route — matches the confirmed inline design. Distinguish cancel-tone vs. failure-tone copy per story 004's technical note; exact copy is a content detail for Stage 2, not fixed here.
- **Auth API boundary**: per `coding-standards.md`'s Flutter error-handling convention, the UI layer only sees domain-level results (success/session-token, or a typed failure enum: `cancelled` / `network-error` / `provider-error`), never raw HTTP/SDK exceptions — this is exactly the seam where the `001-auth-service` contract will plug in later.
- **Logging**: never log tokens, OAuth identity payloads, or pending-selection contents beyond what's needed for a bug report, per `coding-standards.md`.
- **Testing** (scoped in Stage 3, noted now): `flutter_test` widget tests per screen, mocking the `AuthApi` interface and the secure-storage wrapper at the boundary — not mocking domain/state logic itself.

### Acceptance Criteria

- [ ] Splash screen performs the session-check and routes to carousel (no/invalid session) or signals a home-route decision (valid session) without rendering onboarding
- [ ] Onboarding carousel is skippable and reaching the last slide or tapping "Skip" proceeds to language selection; carousel position is not persisted across restarts
- [ ] Language selection screen renders Amharic as selectable and does not hardcode a single-item layout (Afaan Oromo shown as a locked/"coming soon" second entry)
- [ ] Daily-goal screen renders all 4 presets (Casual/Regular/Serious/Intense) with one selected by default
- [ ] Language + goal selections are written to secure local storage as pending state only after both are confirmed, and survive app kill/background before sign-in
- [ ] Sign-in screen renders Google and Apple buttons at identical size/weight/styling
- [ ] Tapping either provider button disables both buttons until that flow resolves
- [ ] A successful Google or Apple flow calls the (interim/mocked) `AuthApi` with the provider token and any pending selection, then signals a route-to-home decision
- [ ] An OAuth failure/cancellation shows an inline error+retry banner on the same sign-in screen (no navigation to a separate error screen), with tone distinguishing user-cancel from actual failure
- [ ] Retry re-triggers the same provider's flow; pending selections remain untouched through failure and retry
- [ ] No tokens, OAuth payloads, or pending-selection PII appear in logs
- [ ] All 5 screens have at least smoke-level widget test coverage (test-writing itself is Stage 3, but scope is fixed here)

### Checkpoint Decisions (Post-Plan)

- **Step-numbering chrome** (flagged as open: "1/3" on language selection, "STEP 2 OF 3" on daily-goal, "STEP 5 OF 5" on sign-in — inconsistent across screens): resolved 2026-09-15 — **no unified cross-screen progress stepper**. Each screen renders standalone; treat the Stitch exports' step-number chrome as placeholder noise and omit it (or replace with a self-contained 3-dot indicator on the carousel only, which is already screen-local, not cross-flow). Do not build a shared "step N of M" widget spanning splash→carousel→language→goal→sign-in.
- **Stale `0._splash_screen` export** (branded "Lomi", not Buna): not used by this plan (which correctly uses `1._buna_splash_screen`); safe to ignore/delete from `stich-screens/` — not this bolt's concern to clean up, just noting it's dead weight, not a second intended screen.
