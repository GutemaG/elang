---
id: 005-real-backend-integration-and-native-sdks
unit: 002-auth-onboarding-ui
intent: 001-auth-onboarding
status: implemented
priority: must
created: 2026-09-15T14:00:58Z
assigned_bolt: 003-auth-onboarding-ui
implemented: true
---

# Story: 005-real-backend-integration-and-native-sdks

## User Story

**As a** Buna user
**I want** the sign-in screen to actually create/load my account on the real backend and trigger real Google/Apple sign-in
**So that** the app works end-to-end instead of against a mock

## Acceptance Criteria

- [x] **Given** `001-auth-service` is now fully implemented and tested, **When** the app calls `signInWithGoogle`/`signInWithApple`, **Then** a real `AuthApi` implementation calls `POST /api/v1/auth/google` / `/apple` over HTTP, matching the exact request/response/error shapes in `ddd-02-technical-design.md`
- [x] **Given** the backend returns a success response, **When** the client receives it, **Then** the session token is persisted via `SessionRepository` exactly as the mocked flow already does, and the user is routed home
- [x] **Given** the backend returns one of the 4 documented error codes (`invalid_token`, `expired_token`, `invalid_pending_selection`, `provider_unreachable`) or a network-level failure (timeout, no connectivity), **When** the client receives it, **Then** it maps to the existing `AuthFailure`/`AuthFailureReason` sealed type already consumed by `SignInController` — no screen/controller code should need to change, only the `AuthApi` implementation (per the Stage 2 plan's explicit design intent)
- [x] **Given** the Google Sign-In and Sign in with Apple Flutter plugins are added, **When** a user taps a provider button, **Then** the real native OAuth flow launches (not a placeholder token) and its result (ID token / identity token, or cancellation) feeds into the real `AuthApi` call
- [x] **Given** no real OAuth client IDs/Team ID/Key ID exist yet in this environment, **When** the native SDKs are wired, **Then** their required configuration values are read from placeholders (e.g. a `.env`-equivalent or platform config file) analogous to the backend's `.env.example` — not hardcoded, and not blocking this story's completion on having real secrets

**Post-implementation note (2026-09-15)**: real Google OAuth credentials were subsequently configured by the user and the full flow was verified working end-to-end on both Flutter Web (via `GoogleWebSignInButton`'s rendered-button flow, added to satisfy GIS's Web restriction — see `implementation-walkthrough.md`) and a physical Android device (via `adb reverse` for local backend reachability). CORS middleware was added to the backend to support the Web flow. See root `README.md` "Known gotchas" for details.

## Technical Notes

- This story did not exist during the original Inception pass for this intent — it's added now because both bolts (`001-auth-service`, `002-auth-onboarding-ui`) reached "complete" independently, and this is the integration seam between them, discovered only once the backend was actually finished.
- Per the Stage 2 implementation plan's own design ("only `fake_auth_api.dart` needs to be replaced... no screen or controller code should need to change"), this should be a small, contained change if the original interface design holds. If it doesn't hold cleanly, that's itself a finding worth reporting, not something to force.
- Real Google/Apple developer console configuration (OAuth client ID, Apple Services ID/Team ID/Key ID) is out of scope for this story to obtain — placeholders only, consistent with the backend's already-flagged "deployment secrets" open item.

## Dependencies

### Requires
- `001-auth-service` bolt (complete) — real API contract now exists, not just documented
- `003-sign-in-screen-google-apple-equal-prominence` (original story — the screen/controller this plugs into)

### Enables
- None (terminal story for this unit, for now)

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Backend unreachable (dev server not running, network error) | Maps to the same failure path as `provider_unreachable`/network error already handled by `SignInController` — inline error + retry, no crash |
| Native SDK plugin not configured (missing platform config on a dev machine) | Should fail gracefully at the SDK layer with a clear error, not crash the app |

## Out of Scope

- Obtaining real Google OAuth client ID / Apple Services ID / Team ID / Key ID values (a deployment/ops task, not a code task)
- Any change to `001-auth-service` (backend is already complete for this intent's scope)
