---
id: 001-onboarding-and-sign-in-on-the-library
unit: 003-screen-migration-ui
intent: 018-mobile-design-system
status: draft
priority: must
created: '2026-09-24T12:55:00Z'
assigned_bolt: 046-onboarding-screens-on-kit
implemented: false
---

# Story: 001-onboarding-and-sign-in-on-the-library

## User Story

**As a** new Buna learner
**I want** the first screens I see to look polished and consistent with each other
**So that** my first impression of the app is a well-made product

## Acceptance Criteria

- [ ] **Given** splash, onboarding carousel, language selection, daily goal and sign-in, **When** shown, **Then** each is built on `AppPage`, `AppButton`, `AppCard`/`SelectableOptionCard` and the status pieces, and matches its Stitch mockup
- [ ] **Given** Skip, "I'll do it later" and similar actions, **When** shown, **Then** they are `AppButton.text` links (Checkpoint 1: 2a)
- [ ] **Given** the Google and Apple sign-in buttons, **When** shown, **Then** they keep equal prominence and their provider-required look, sitting inside the shared layout (the web Google button keeps Google's own rendering)
- [ ] **Given** the auth and onboarding tests, **When** run, **Then** all pass, changed only where a replaced widget type was found
- [ ] **Given** the rules test, **When** run, **Then** these five screens are off the allow-list and pass

## Reference Design (FR-11)

- `stich-screens/extracted/stitch_ethiopian_language_learning_app/0._splash_screen`, `1._buna_splash_screen`, `2._onboarding_carousel`, `3._language_selection`, `4._daily_goal_selection`, `5._create_account_sign_in`

## Technical Notes

- Provider buttons must still follow Google's and Apple's branding rules; only their surroundings change.

## Dependencies

### Requires
- 001-design-foundation-ui

### Enables
- 005-consistency-sweep

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Sign-in error | Shown inline with the shared error style; retry works as today |

## Out of Scope

- Changing the onboarding flow or copy
