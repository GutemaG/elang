---
id: 001-splash-and-onboarding-carousel
unit: 002-auth-onboarding-ui
intent: 001-auth-onboarding
status: ready
priority: must
created: 2026-09-15T12:35:35Z
assigned_bolt: 002-auth-onboarding-ui
implemented: false
---

# Story: 001-splash-and-onboarding-carousel

## User Story

**As a** new Buna user opening the app for the first time
**I want** a brief splash screen followed by an onboarding carousel introducing Buna
**So that** I understand what the app does before committing to an account

## Acceptance Criteria

- [ ] **Given** the app launches and no valid session token exists in secure storage, **When** the splash screen finishes, **Then** the onboarding carousel is shown
- [ ] **Given** the app launches and a valid session token exists, **When** the splash screen finishes, **Then** the carousel/onboarding is skipped entirely and the user lands on home (home screen itself is a different, future intent — for this story, verify routing decision only)
- [ ] **Given** the user is viewing the carousel, **When** they tap "Skip" or reach the last slide, **Then** they proceed to language selection (story 002)

## Technical Notes

- Match the Buna Splash Screen and Onboarding Carousel designs in `stitch-screens/extracted/stitch_ethiopian_language_learning_app/1._buna_splash_screen/` and `2._onboarding_carousel/`.
- Session check reads from secure local storage (Keychain/Keystore) — same storage story 003/004 write to.

## Dependencies

### Requires
- None (first screen in the flow)

### Enables
- 002-language-and-daily-goal-selection-screens

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Session token exists but is expired/invalid | Treated as no session — show onboarding, not a broken home screen |
| User backgrounds the app mid-carousel | Carousel position doesn't need to persist — reopening restarts the carousel (no state loss risk here, unlike post-selection) |

## Out of Scope

- Home screen content itself (future intent)
- Persisting carousel progress across app restarts
