---
id: 003-apple-sign-in-authentication
unit: 001-auth-service
intent: 001-auth-onboarding
status: ready
priority: must
created: 2026-09-15T12:35:35Z
assigned_bolt: 001-auth-service
implemented: false
---

# Story: 003-apple-sign-in-authentication

## User Story

**As a** Buna user on iOS (or any user who prefers it)
**I want** to sign up or log in with Sign in with Apple
**So that** I have a privacy-respecting alternative to Google, as required by App Store policy

## Acceptance Criteria

- [ ] **Given** a valid Apple identity token from a first-time user, **When** the backend verifies it, **Then** a new `users` row is created (with pending onboarding selections attached per story 001) keyed by Apple's stable user identifier, and a session token is returned
- [ ] **Given** a valid Apple identity token from a returning user, **When** the backend verifies it, **Then** the existing account is loaded correctly even if Apple's private-relay email differs or is absent this time
- [ ] **Given** an invalid, expired, or tampered Apple identity token, **When** the backend attempts verification, **Then** authentication is rejected with a clear error code
- [ ] **Given** a valid session token from a prior Apple sign-in, **When** the app restarts and sends it, **Then** the session is recognized as valid without requiring re-authentication

## Technical Notes

- Verify the Apple identity token (JWT) against Apple's published public keys server-side.
- Account lookup/dedup key is Apple's stable user identifier, **never** email — Apple's private-relay email feature means the same user can present different (or no) email across sign-ins.
- Session token issuance/validation is the same mechanism as story 002 (Google) — shared code path, different upstream verification.

## Dependencies

### Requires
- 001-persist-pending-onboarding-selections (the create-account path uses this logic)

### Enables
- Frontend story 003-sign-in-screen-google-apple-equal-prominence (UI consumes this endpoint)

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| User's Apple private-relay email changes between sign-ins | Account is still matched correctly via stable user ID, not email |
| Apple identity token verification service unreachable | Return a retryable error distinct from "invalid token" |
| User has both a Google-created and an Apple-created account with the same real email | Treated as two separate accounts in Phase 1 (no cross-provider account linking) — documented limitation, not a bug |

## Out of Scope

- Cross-provider account linking (Google account + Apple account merging) — not in Phase 1 spec
- Any UI (owned by unit `002-auth-onboarding-ui`)
