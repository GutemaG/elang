---
id: 001-persist-pending-onboarding-selections
unit: 001-auth-service
intent: 001-auth-onboarding
status: ready
priority: must
created: 2026-09-15T12:35:35Z
assigned_bolt: 001-auth-service
implemented: false
---

# Story: 001-persist-pending-onboarding-selections

## User Story

**As a** new Buna user who just finished onboarding (chose Amharic + a daily goal) but hasn't signed in yet
**I want** those selections attached to my account the moment I successfully authenticate
**So that** I never have to repeat onboarding just because I had to sign in after making my choices

## Acceptance Criteria

- [ ] **Given** a first-time sign-in (Google or Apple) arrives with a pending language + daily-goal-minutes payload, **When** the account is created, **Then** the new `users` row stores that language and the daily-goal-minutes mapped to a daily XP target
- [ ] **Given** a first-time sign-in arrives with NO pending payload (edge case — client didn't send one), **When** the account is created, **Then** the account is still created successfully with sensible defaults (documented in technical design), not an error
- [ ] **Given** a returning user's sign-in arrives with a pending payload (e.g. they redid onboarding on a new device before logging into an existing account), **When** authentication succeeds, **Then** the existing account's language/goal are NOT overwritten by the pending payload

## Technical Notes

- The minutes→daily-XP-target mapping formula is a technical-design decision (flagged as an open cross-intent dependency with the future gamification-engine intent in `requirements.md`).
- This logic lives inside the same request/transaction as account creation in stories 002/003 — it's a shared code path, not a separate endpoint.

## Dependencies

### Requires
- None (foundational)

### Enables
- 002-google-oauth-authentication
- 003-apple-sign-in-authentication

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Pending payload has an invalid/unsupported language code | Reject with a validation error, don't create a malformed account |
| Pending payload sent on a returning-user login | Ignored — existing account state wins (see AC3) |
| Client never sends a pending payload at all (network dropped it) | Account still created with defaults, no hard failure |

## Out of Scope

- Changing daily goal after onboarding (Settings, future Account intent)
- The exact minutes→XP formula's numeric values (technical design + gamification-engine intent)
