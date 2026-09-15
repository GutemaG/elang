---
id: 003-auth-onboarding-ui
unit: 002-auth-onboarding-ui
intent: 001-auth-onboarding
type: simple-construction-bolt
status: complete
stories:
  - 005-real-backend-integration-and-native-sdks
created: 2026-09-15T14:00:58Z
started: 2026-09-15T14:05:00Z
completed: 2026-09-15T16:15:00Z
current_stage: test
stages_completed:
  - name: plan
    completed: 2026-09-15T14:05:00Z
    artifact: implementation-plan.md
  - name: implement
    completed: 2026-09-15T15:30:00Z
    artifact: implementation-walkthrough.md
  - name: test
    completed: 2026-09-15T16:15:00Z
    artifact: test-walkthrough.md

requires_bolts: [001-auth-service]
enables_bolts: []
requires_units: [001-auth-service]
blocks: false

complexity:
  avg_complexity: 2
  avg_uncertainty: 2
  max_dependencies: 3
  testing_scope: 2
---

# Bolt: 003-auth-onboarding-ui

## Overview

Second bolt for the `002-auth-onboarding-ui` unit, created after both `001-auth-service` and the original `002-auth-onboarding-ui` bolt reached completion independently. Wires the frontend's mock `AuthApi` to the now-fully-implemented backend, and adds the real Google Sign-In / Sign in with Apple native SDK plugins.

## Objective

Replace `FakeAuthApi` with a real HTTP-backed implementation of the existing `AuthApi` interface, and swap the placeholder-token sign-in trigger for real native OAuth SDK calls — without changing any screen or controller code, per the original Stage 2 plan's design intent.

## Stories Included

- **005-real-backend-integration-and-native-sdks**: Real backend integration + native SDKs (Must)

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- ✅ **1. Plan**: Complete → `implementation-plan.md`
- ✅ **2. Implement**: Complete → source code + `implementation-walkthrough.md`
- ✅ **3. Test**: Complete → `test-walkthrough.md`

## Dependencies

### Requires
- 001-auth-service (complete — its API contract is now real, implemented, and tested, not just documented)

### Enables
- None (terminal bolt for this intent, for now)

## Success Criteria

- ✅ Real `AuthApi` implementation calling the 3 live backend endpoints
- ✅ Native Google/Apple SDK plugins added and wired (config values as placeholders, not real secrets)
- ✅ No screen/controller code changes required beyond the `AuthApi` swap (or, if that assumption breaks, an explicit report of why) — assumption broke for both `SignInController` (anticipated by the plan) and `SignInScreen` (not anticipated); both reported explicitly in `implementation-walkthrough.md`
- ✅ Existing 24 widget tests still pass (one helper updated to inject a test double, no assertions changed — see walkthrough); new tests added for the real `AuthApi` implementation's error-mapping plus the new native-SDK cancellation path

## Notes

Unlike the original two bolts, this one was not planned during Inception — it's a direct consequence of both units reaching "complete" independently and needing an integration pass. This is exactly the kind of mid-project bolt that Construction is allowed to plan itself (per `memory-bank.yaml`'s ownership note: "Construction: executes, can replan bolts").
