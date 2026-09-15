---
intent: 001-auth-onboarding
phase: inception
status: units-decomposed
updated: 2026-09-15T12:35:35Z
---

# Auth & Onboarding - Unit Decomposition

## Requirement-to-Unit Mapping

- **FR-1** (Onboarding Carousel) → `002-auth-onboarding-ui`
- **FR-2** (Language + Daily Goal Selection, Pre-Auth) → `001-auth-service`
- **FR-3** (Google OAuth Sign-Up/Sign-In) → `001-auth-service`
- **FR-4** (Sign in with Apple) → `001-auth-service`
- **FR-5** (OAuth Failure/Denial Handling) → `002-auth-onboarding-ui`

Note: `002-auth-onboarding-ui` implements the screens for FR-2/FR-3/FR-4 as well (it's the only client), but the acceptance criteria and business rules for those FRs are owned by `001-auth-service`.

## Units Overview

This intent decomposes into 2 units of work:

### Unit 1: 001-auth-service

**Description**: FastAPI backend service owning identity (Google OAuth + Sign in with Apple verification, account creation/lookup) and the pending-onboarding-selection attach logic.

**Stories**:

- 001-persist-pending-onboarding-selections
- 002-google-oauth-authentication
- 003-apple-sign-in-authentication

**Deliverables**:

- `users` table read/write logic (via SQLAlchemy per `data-stack.md`)
- Token verification against Google and Apple
- REST endpoints for sign-in/sign-up with both providers

**Dependencies**:

- Depends on: None
- Depended by: `002-auth-onboarding-ui`

**Estimated Complexity**: M

### Unit 2: 002-auth-onboarding-ui

**Description**: Flutter client screens for splash, onboarding carousel, language + daily-goal selection, and the sign-in screen (Google + Apple, equally prominent) with inline OAuth failure/retry handling. Matches the Stitch designs already produced (Highland Pulse design system, `stitch-screens/` export).

**Stories**:

- 001-splash-and-onboarding-carousel
- 002-language-and-daily-goal-selection-screens
- 003-sign-in-screen-google-apple-equal-prominence
- 004-oauth-failure-inline-retry

**Deliverables**:

- Flutter screens for the full pre-auth flow, matching the exported Stitch designs
- Local pre-auth state holder for pending language/goal selections
- API client calls into `001-auth-service` endpoints

**Dependencies**:

- Depends on: `001-auth-service` (needs its API contract to integrate against; can scaffold from Technical Design stage before backend implementation is complete)
- Depended by: None

**Estimated Complexity**: M

## Unit Dependency Graph

```text
[001-auth-service] ──> [002-auth-onboarding-ui]
```

## Execution Order

Based on dependencies:

1. `001-auth-service` first (foundation — defines the API contract the UI integrates against)
2. `002-auth-onboarding-ui` second (can start screen-building in parallel once the API contract from `001-auth-service`'s Technical Design stage is available, but full integration waits on backend implementation)
