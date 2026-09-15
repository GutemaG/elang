---
id: 002-google-oauth-authentication
unit: 001-auth-service
intent: 001-auth-onboarding
status: ready
priority: must
created: 2026-09-15T12:35:35Z
assigned_bolt: 001-auth-service
implemented: false
---

# Story: 002-google-oauth-authentication

## User Story

**As a** Buna user
**I want** to sign up or log in with my Google account
**So that** I can access Buna without creating or remembering a password

## Acceptance Criteria

- [ ] **Given** a valid Google ID token from a first-time user, **When** the backend verifies it, **Then** a new `users` row is created (with pending onboarding selections attached per story 001) and a session token is returned
- [ ] **Given** a valid Google ID token from a returning user, **When** the backend verifies it, **Then** the existing account is loaded (no new row, no data overwritten) and a session token is returned
- [ ] **Given** an invalid, expired, or tampered Google ID token, **When** the backend attempts verification, **Then** authentication is rejected with a clear error code (no account created, no session issued)
- [ ] **Given** a valid session token from a prior Google sign-in, **When** the app restarts and sends it, **Then** the session is recognized as valid without requiring the user to re-authenticate

## Technical Notes

- Verify the Google ID token server-side using Google's official verification approach — never trust client-asserted identity alone.
- Account lookup/dedup key is Google's stable user ID (`sub` claim), not email.
- Session token issuance/validation logic is shared with story 003 (Apple) — same underlying session mechanism, different upstream verification.

## Dependencies

### Requires
- 001-persist-pending-onboarding-selections (the create-account path uses this logic)

### Enables
- Frontend story 003-sign-in-screen-google-apple-equal-prominence (UI consumes this endpoint)

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Google token verification service is unreachable | Return a retryable error (distinct from "invalid token"), so the client can show the right message |
| User revokes Google access after having a Buna account | Existing account/session unaffected until they try to sign in again, at which point verification fails normally |
| Same Google account signs in from two devices | Both succeed; same account, same data, independent session tokens |

## Out of Scope

- Google account linking/unlinking after the fact (not in Phase 1 spec)
- Any UI (owned by unit `002-auth-onboarding-ui`)
