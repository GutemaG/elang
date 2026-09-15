---
id: 003-sign-in-screen-google-apple-equal-prominence
unit: 002-auth-onboarding-ui
intent: 001-auth-onboarding
status: ready
priority: must
created: 2026-09-15T12:35:35Z
assigned_bolt: 002-auth-onboarding-ui
implemented: false
---

# Story: 003-sign-in-screen-google-apple-equal-prominence

## User Story

**As a** new Buna user who just finished pre-auth onboarding
**I want** to create my account with either Google or Apple, shown as equally valid options
**So that** I'm not steered toward one provider and Buna stays compliant with App Store policy

## Acceptance Criteria

- [ ] **Given** the sign-in screen renders, **When** compared, **Then** the Google and Apple buttons have identical size, weight, and visual styling (neither is primary/secondary)
- [ ] **Given** the user taps "Continue with Google", **When** the native Google Sign-In flow succeeds, **Then** the app calls `001-auth-service`'s Google endpoint with the ID token and any pending onboarding selections, then routes to home on success
- [ ] **Given** the user taps "Continue with Apple", **When** the native Sign in with Apple flow succeeds, **Then** the app calls `001-auth-service`'s Apple endpoint with the identity token and any pending onboarding selections, then routes to home on success
- [ ] **Given** a returning user (this device previously signed in), **When** they land on the sign-in screen and re-authenticate, **Then** their real account loads — pending local selections (if any leftover) are not sent as overriding data

## Technical Notes

- Match `stitch-screens/extracted/stitch_ethiopian_language_learning_app/5._create_account_sign_in/`.
- This story is the integration point between the UI and both backend stories (002, 003 in `001-auth-service`) — both provider buttons hit the same shape of request/response.

## Dependencies

### Requires
- 002-language-and-daily-goal-selection-screens (pending selections must exist to send)
- Backend: 002-google-oauth-authentication, 003-apple-sign-in-authentication (API contract)

### Enables
- 004-oauth-failure-inline-retry

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| User taps Google then immediately taps Apple before the first flow resolves | Only one flow should be in-flight at a time — disable both buttons while one is active |
| Backend is unreachable (network error, not an OAuth-provider error) | Same inline error/retry path as story 004 |

## Out of Scope

- The error/retry UI itself (story 004)
- Home screen (future intent)
