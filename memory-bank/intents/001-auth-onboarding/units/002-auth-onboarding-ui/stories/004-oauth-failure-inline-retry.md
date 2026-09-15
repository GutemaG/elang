---
id: 004-oauth-failure-inline-retry
unit: 002-auth-onboarding-ui
intent: 001-auth-onboarding
status: ready
priority: must
created: 2026-09-15T12:35:35Z
assigned_bolt: 002-auth-onboarding-ui
implemented: false
---

# Story: 004-oauth-failure-inline-retry

## User Story

**As a** Buna user whose sign-in attempt failed (network error, cancelled, or permission denied)
**I want** a clear inline error with a retry option, without losing my onboarding selections
**So that** a hiccup doesn't force me to redo the whole onboarding flow

## Acceptance Criteria

- [ ] **Given** the Google or Apple OAuth flow fails or is cancelled by the user, **When** control returns to the sign-in screen, **Then** an inline error message appears on the same screen (no navigation to a separate error screen)
- [ ] **Given** the inline error is showing, **When** the user taps "Retry", **Then** the same provider's OAuth flow is re-triggered
- [ ] **Given** an OAuth attempt fails, **When** the failure is handled, **Then** the pending onboarding selections in local secure storage are untouched — still present for the retry or a later attempt

## Technical Notes

- Match the inline-error variant referenced in the original Stitch design prompt (no separate error screen was designed — confirm this still holds against the current exported screens before implementation; if a dedicated error state isn't in the export, design it inline consistent with the Highland Pulse system).
- Distinguish, in the error message shown, between "you cancelled" (neutral tone) vs. an actual failure (apologetic tone with retry) — exact copy is a technical/content detail, not fixed here.

## Dependencies

### Requires
- 003-sign-in-screen-google-apple-equal-prominence

### Enables
- None (terminal story in this unit)

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| User cancels the native OAuth dialog themselves | Treated as a failure for retry purposes, but the message tone should not imply something broke |
| Repeated failures (3+ retries) | No special lockout in Phase 1 — just keep allowing retry (rate limiting, if any, is a backend concern outside this story) |

## Out of Scope

- A dedicated full-screen error state (explicitly out of scope per resolved requirements)
- Backend-side rate limiting of retry attempts
