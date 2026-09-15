---
id: 001-auth-service
unit: 001-auth-service
intent: 001-auth-onboarding
type: ddd-construction-bolt
status: complete
stories:
  - 001-persist-pending-onboarding-selections
  - 002-google-oauth-authentication
  - 003-apple-sign-in-authentication
created: 2026-09-15T12:35:35Z
started: 2026-09-15T12:52:04Z
completed: 2026-09-15T18:10:00Z
current_stage: test
stages_completed:
  - name: model
    completed: 2026-09-15T12:52:04Z
    artifact: ddd-01-domain-model.md
  - name: design
    completed: 2026-09-15T13:20:00Z
    artifact: ddd-02-technical-design.md
  - name: adr
    completed: 2026-09-15T13:00:03Z
    artifact: adr-1-session-token-hashing.md, adr-2-apple-jwt-jwks-verification.md
  - name: implement
    completed: 2026-09-15T16:30:00Z
    artifact: backend/ (source code), implementation-notes.md
  - name: test
    completed: 2026-09-15T18:10:00Z
    artifact: backend/tests/ (76 tests), ddd-03-test-report.md

requires_bolts: []
enables_bolts: [002-auth-onboarding-ui]
requires_units: []
blocks: false

complexity:
  avg_complexity: 2
  avg_uncertainty: 2
  max_dependencies: 2
  testing_scope: 2
---

# Bolt: 001-auth-service

## Overview

First and only bolt for the `001-auth-service` unit: identity verification for Google OAuth and Sign in with Apple, account creation/lookup, and attaching pre-auth onboarding selections to newly created accounts.

## Objective

Implement the full "verify token → create-or-load user → attach pending onboarding selections → issue session token" flow for both Google and Apple, since all three stories share the same `User` aggregate and request shape.

## Stories Included

- **001-persist-pending-onboarding-selections**: Attach pending onboarding selections on first auth (Must)
- **002-google-oauth-authentication**: Sign up / log in with Google (Must)
- **003-apple-sign-in-authentication**: Sign in with Apple (Must)

## Bolt Type

**Type**: DDD Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/ddd-construction-bolt.md`

## Stages

- ✅ **1. Domain Model**: Complete → `ddd-01-domain-model.md`
- ✅ **2. Technical Design**: Complete → `ddd-02-technical-design.md`
- ✅ **3. ADR Analysis** (optional): Complete → `adr-1-session-token-hashing.md`, `adr-2-apple-jwt-jwks-verification.md`
- ✅ **4. Implement**: Complete → `backend/` source code, `implementation-notes.md`
- ✅ **5. Test**: Complete → `backend/tests/` (76 tests, 99% coverage on auth-logic modules), `ddd-03-test-report.md`

## Dependencies

### Requires
- None (foundation bolt for this intent)

### Enables
- 002-auth-onboarding-ui (needs this bolt's API contract and, for full integration, its implementation)

## Success Criteria

- ✅ All 3 stories implemented
- ✅ All acceptance criteria met
- ✅ Tests passing (>80% coverage on auth logic) — 76/76 passing, 99% coverage on auth-logic modules (see `ddd-03-test-report.md`)
- [ ] Code reviewed (independent human/peer review not yet performed)

## Notes

`002-auth-onboarding-ui` can start screen-building against this bolt's Technical Design (API contract) before Implement/Test are done, but full end-to-end integration is blocked until this bolt reaches at least Implement.

**Confirmed at Checkpoint 3 (2026-09-15)**: backend code lives in this repo under `backend/` (monorepo alongside the Flutter app), and local dev/test uses SQLite (`aiosqlite`) via the same SQLAlchemy async engine — PostgreSQL stays the real-deployment target. These carry into Stage 1/2 (Domain Model, Technical Design) as constraints, not shortcuts past them — actual FastAPI scaffolding still happens at Stage 4 (Implement), per the DDD bolt's stage discipline.
