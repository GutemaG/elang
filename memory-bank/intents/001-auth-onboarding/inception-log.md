---
intent: 001-auth-onboarding
created: 2026-09-15T10:48:32Z
completed: 2026-09-15T12:46:24Z
status: complete
---

# Inception Log: 001-auth-onboarding

## Overview

**Intent**: Auth (Google OAuth + Sign in with Apple) and onboarding (carousel, language + daily-goal selection) — the foundation intent for Buna Phase 1. Chosen as intent 001 because the core lesson loop, gamification, and SRS all assume an authenticated, onboarded user.
**Type**: green-field
**Created**: 2026-09-15

## Artifacts Created

| Artifact | Status | File |
|----------|--------|------|
| Requirements | ✅ | requirements.md |
| System Context | ✅ | system-context.md |
| Units | ✅ | units/001-auth-service/unit-brief.md, units/002-auth-onboarding-ui/unit-brief.md |
| Stories | ✅ | units/001-auth-service/stories/*.md (3), units/002-auth-onboarding-ui/stories/*.md (4) |
| Bolt Plan | ✅ | memory-bank/bolts/001-auth-service/bolt.md, memory-bank/bolts/002-auth-onboarding-ui/bolt.md |

## Summary

| Metric | Count |
|--------|-------|
| Functional Requirements | 5 |
| Non-Functional Requirements | 3 (Security, Reliability, Compliance) |
| Units | 2 |
| Stories | 7 |
| Bolts Planned | 2 |

## Units Breakdown

| Unit | Stories | Bolts | Priority |
|------|---------|-------|----------|
| 001-auth-service | 3 | 1 (001-auth-service) | Must |
| 002-auth-onboarding-ui | 4 | 1 (002-auth-onboarding-ui) | Must |

## Decision Log

| Date | Decision | Rationale | Approved |
|------|----------|-----------|----------|
| 2026-09-15 | Selected "Auth & onboarding" as intent 001 over "core lesson loop" and "gamification engine" | Every other Phase 1 feature depends on an authenticated, onboarded user existing first | Yes |
| 2026-09-15 | Onboarding (carousel + language/goal selection) happens before account creation | Resolved via clarifying questions at Checkpoint 1; matches standard Duolingo-style pattern | Yes |
| 2026-09-15 | Daily-goal presets are 4 tiers by minutes/day (5/10/15/20) | Resolved via clarifying questions at Checkpoint 1 | Yes |
| 2026-09-15 | OAuth failure handling is inline error + retry, no dedicated error screen | Resolved via clarifying questions at Checkpoint 1; keeps Phase 1 screen count at ~12-14 | Yes |
| 2026-09-15 | Split into 2 units: 001-auth-service (backend, DDD) and 002-auth-onboarding-ui (frontend, simple) | Matches full-stack-web project-type unit structure from catalog.yaml; backend owns identity/persistence FRs, frontend owns pure-UI FRs (FR-1, FR-5) and implements screens for all | Yes |
| 2026-09-15 | Single bolt per unit (no further splitting) | All stories per unit share the same aggregate/screen-flow and are small enough to stay cohesive in one bolt | Yes |
| 2026-09-15 | Backend lives in this same repo under `backend/` (monorepo, not a separate repo) | User confirmed at Checkpoint 3 | Yes |
| 2026-09-15 | Local dev/test database is SQLite (`aiosqlite`) via the same SQLAlchemy async engine; PostgreSQL remains the real-deployment target | User confirmed at Checkpoint 3 — updated `memory-bank/standards/data-stack.md` accordingly | Yes |

## Scope Changes

| Date | Change | Reason | Impact |
|------|--------|--------|--------|
| 2026-09-15 | Added story 005-real-backend-integration-and-native-sdks to unit 002-auth-onboarding-ui, planned as new bolt 003-auth-onboarding-ui | Both original bolts (001-auth-service, 002-auth-onboarding-ui) reached completion independently; the integration seam between them (swap mock AuthApi for real backend calls, add native OAuth SDKs) wasn't visible during Inception since the backend didn't exist yet | +1 story, +1 bolt for this intent |

## Ready for Construction

**Checklist**:
- [x] All requirements documented
- [x] System context defined
- [x] Units decomposed
- [x] Stories created for all units
- [x] Bolts planned
- [x] Human review complete (Checkpoint 3 approved 2026-09-15)

## Next Steps

1 - **construction**: Start building with first bolt → `/specsmd-construction-agent --unit="001-auth-service" --bolt-id="001-auth-service"`

## Dependencies

None — this is the first intent; everything else in Phase 1 depends on it.
