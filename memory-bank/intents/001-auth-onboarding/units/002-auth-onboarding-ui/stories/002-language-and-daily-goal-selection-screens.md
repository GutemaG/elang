---
id: 002-language-and-daily-goal-selection-screens
unit: 002-auth-onboarding-ui
intent: 001-auth-onboarding
status: ready
priority: must
created: 2026-09-15T12:35:35Z
assigned_bolt: 002-auth-onboarding-ui
implemented: false
---

# Story: 002-language-and-daily-goal-selection-screens

## User Story

**As a** new Buna user who just finished the onboarding carousel
**I want** to pick my target language and a daily study goal before creating an account
**So that** signing in afterward immediately applies to a personalized setup, not a blank account

## Acceptance Criteria

- [ ] **Given** the language selection screen, **When** it renders, **Then** Amharic is shown as the selectable course and the layout doesn't assume it's the only course that will ever exist (no hardcoded single-item layout)
- [ ] **Given** the daily-goal screen, **When** it renders, **Then** 4 presets are shown (Casual 5 min, Regular 10 min, Serious 15 min, Intense 20 min) with one selected by default
- [ ] **Given** the user selects a language and a daily goal, **When** they proceed, **Then** both selections are written to local secure storage as "pending" state — not sent to the backend yet (that happens on sign-in, story 003 backend-side)
- [ ] **Given** the user backgrounds or force-kills the app after selecting but before signing in, **When** they reopen the app, **Then** the pending selections are still present (not lost)

## Technical Notes

- Match `stitch-screens/extracted/stitch_ethiopian_language_learning_app/3._language_selection/` and `4._daily_goal_selection/`.
- Pending state must be written to the same secure storage session/data 001-auth-service's stories expect as the request payload on first auth (see backend story 001).

## Dependencies

### Requires
- 001-splash-and-onboarding-carousel

### Enables
- 003-sign-in-screen-google-apple-equal-prominence

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| User changes their goal selection before signing in | Local pending state simply reflects the latest choice — no versioning needed |
| App is killed mid-selection (before confirming) | No pending state written yet — user just repeats the selection on reopen, no corruption |

## Out of Scope

- Sending the pending payload to the backend (that's part of the sign-in call in story 003)
- Afaan Oromo as a selectable option (Phase 2)
