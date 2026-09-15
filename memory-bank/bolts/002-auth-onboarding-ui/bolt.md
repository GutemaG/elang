---
id: 002-auth-onboarding-ui
unit: 002-auth-onboarding-ui
intent: 001-auth-onboarding
type: simple-construction-bolt
status: complete
stories:
  - 001-splash-and-onboarding-carousel
  - 002-language-and-daily-goal-selection-screens
  - 003-sign-in-screen-google-apple-equal-prominence
  - 004-oauth-failure-inline-retry
created: 2026-09-15T12:35:35Z
started: null
completed: 2026-09-15T15:10:00Z
current_stage: test
stages_completed:
  - name: plan
    completed: 2026-09-15T12:52:20Z
    artifact: implementation-plan.md
  - name: implement
    completed: 2026-09-15T13:40:00Z
    artifact: implementation-walkthrough.md
  - name: test
    completed: 2026-09-15T15:10:00Z
    artifact: test-walkthrough.md

requires_bolts: [001-auth-service]
enables_bolts: []
requires_units: [001-auth-service]
blocks: true

complexity:
  avg_complexity: 2
  avg_uncertainty: 1
  max_dependencies: 2
  testing_scope: 2
---

# Bolt: 002-auth-onboarding-ui

## Overview

First and only bolt for the `002-auth-onboarding-ui` unit: the full pre-lesson-loop Flutter screen flow (splash, onboarding carousel, language + daily-goal selection, sign-in with Google/Apple, inline OAuth error/retry), matching the existing Stitch "Highland Pulse" designs.

## Objective

Build all 4 stories as one cohesive bolt since they form a single linear screen flow with shared local state (pending onboarding selections, session check).

## Stories Included

- **001-splash-and-onboarding-carousel**: Splash screen + skippable onboarding carousel (Must)
- **002-language-and-daily-goal-selection-screens**: Language + daily-goal selection UI (Must)
- **003-sign-in-screen-google-apple-equal-prominence**: Sign-in screen with equal-prominence Google/Apple buttons (Must)
- **004-oauth-failure-inline-retry**: Inline OAuth failure + retry handling (Must)

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- ✅ **1. Plan**: Complete → `implementation-plan.md`
- ✅ **2. Implement**: Complete → source code + `implementation-walkthrough.md`
- ✅ **3. Test**: Complete → `test-walkthrough.md`

## Dependencies

### Requires
- 001-auth-service (API contract from its Technical Design stage minimum; full integration needs its Implement stage complete)

### Enables
- None (terminal bolt for this intent)

## Success Criteria

- ✅ All 4 stories implemented, matching the exported Stitch designs
- ✅ All acceptance criteria met (see `test-walkthrough.md` for the two sub-clauses verified by code review rather than an automated test: carousel non-persistence and log-content)
- ✅ Widget tests passing (24/24 — `test-walkthrough.md`)
- [ ] Code reviewed

## Notes

Currently `blocks: true` since `001-auth-service` is still `planned`. Re-evaluate once that bolt reaches Technical Design — Plan stage here can reasonably start once the API contract exists, even before backend Implement is done.
