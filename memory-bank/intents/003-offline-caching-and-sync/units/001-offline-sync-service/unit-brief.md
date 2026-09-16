---
unit: 001-offline-sync-service
intent: 003-offline-caching-and-sync
phase: construction
status: complete
created: '2026-09-16T20:30:00Z'
updated: '2026-09-16T23:15:00Z'
unit_type: backend
default_bolt_type: ddd-construction-bolt
---

# Unit Brief: Offline Sync Service

## Purpose

Make `002-core-lesson-loop`'s existing lesson-content and completion endpoints safe for the mobile client to call late and out of order, and teach the streak/XP-day business rule to trust a client-supplied offline-completion timestamp. This is a targeted amendment to `001-lesson-service`'s existing endpoints, not a new service.

## Scope

### In Scope
- Re-verify (and extend if needed) bolt 005's `attemptId`-based idempotency on the completion/answer endpoints under delayed/out-of-order replay
- Accept a client-supplied completion timestamp on completion calls; attribute streak-day/XP-day using it (bounded/validated, exact bound TBD in Technical Design) instead of only server-arrival time
- Expose a content-version/etag signal on lesson-content and skill-tree responses
- Decide whether a batch-sync endpoint is worth adding vs. replaying the existing per-completion endpoint N times

### Out of Scope
- Any UI/download/local-storage work (owned by `002-offline-caching-and-sync-ui`)
- New database tables — reuses `002-core-lesson-loop`'s existing skills/lessons/exercises/progress/beans/streak schema
- Multi-device concurrent-session conflict resolution (explicit non-goal, see `requirements.md`)

---

## Assigned Requirements

| FR | Requirement | Priority |
|----|-------------|----------|
| FR-1 | Downloadable Lesson Packs (content-version signal only) | Must |
| FR-3 | Beans/Streak/XP Sync on Reconnect (idempotency/replay guarantee) | Must |
| FR-4 | Streak-Day Conflict Resolution | Must |

---

## Domain Concepts

### Key Entities
| Entity | Description | Attributes |
|--------|-------------|------------|
| LessonAttempt (existing, amended) | Same entity from `002-core-lesson-loop`'s `001-lesson-service` | + `client_completed_at` (the offline-completion timestamp supplied by the client, distinct from server-received-at) |
| ContentVersion (new, lightweight) | A version marker per skill/lesson content | skill_id or lesson_id, version (int or hash), updated_at |

### Key Operations
| Operation | Description | Inputs | Outputs |
|-----------|-------------|--------|---------|
| CompleteLesson (amended) | Same as `002`'s, now also accepts and validates a client-supplied completion timestamp | lesson_attempt_id, attemptId, client_completed_at | XP awarded, updated streak (attributed to `client_completed_at`'s calendar day) |
| GetLessonContent / GetSkillTree (amended) | Same as `002`'s, now also returns a version signal | lesson_id / user_id | Existing payload + content version/etag |
| (Decision) BatchSyncCompletions | Optionally accept N queued completions in one call | list of {lesson_attempt_id, attemptId, client_completed_at, answers} | Per-item success/failure |

---

## Story Summary

| Metric | Count |
|--------|-------|
| Total Stories | 3 |
| Must Have | 3 |

### Stories

| Story ID | Title | Priority | Status |
|----------|-------|----------|--------|
| 001-content-version-signal | Expose a content-version signal for staleness checks | Must | Planned |
| 002-timestamped-completion-for-streak-attribution | Accept a client-supplied completion timestamp for streak/XP-day attribution | Must | Planned |
| 003-idempotent-offline-replay | Re-verify/extend idempotent replay of delayed completions | Must | Planned |

---

## Dependencies

### Depends On
| Unit | Reason |
|------|--------|
| `001-lesson-service` (intent `002-core-lesson-loop`, existing) | Extends its endpoints/tables; does not replace them |

### Depended By
| Unit | Reason |
|------|--------|
| `002-offline-caching-and-sync-ui` | Needs the amended API contract (timestamp field, version signal) to integrate offline download/sync |

### External Dependencies
| System | Purpose | Risk |
|--------|---------|------|
| None new | — | — |

---

## Technical Context

### Suggested Technology
FastAPI + SQLAlchemy (async), same `backend/` app and router modules as `001-lesson-service` — this is an amendment PR to that code, not a new module tree.

### Integration Points
| Integration | Type | Protocol |
|-------------|------|----------|
| `002-offline-caching-and-sync-ui` | API | REST over HTTPS, authenticated via existing session token |

### Data Storage
| Data | Type | Volume | Retention |
|------|------|--------|-----------|
| `client_completed_at` column on lesson_attempts | SQL (PostgreSQL), additive column | Same volume as existing lesson_attempts | Indefinite |
| Content version marker | SQL (PostgreSQL) or computed from existing `updated_at` | Low | Indefinite |

---

## Constraints

- No new auth scheme — reuses the existing session-token dependency.
- `client_completed_at` must be validated against abuse (e.g. a client can't backdate a completion to fabricate an arbitrarily long streak) — exact bound is a Technical Design decision, but the requirement itself (validate, don't blindly trust) is fixed here.
- Must not regress `002-core-lesson-loop`'s existing online behavior or its 215/215 backend test suite.

---

## Success Criteria

### Functional
- [ ] A completion call made minutes, hours, or days after the fact is attributed to the correct calendar day via `client_completed_at`
- [ ] A retried/replayed completion call never double-awards XP or double-deducts Beans
- [ ] Lesson-content/skill-tree responses carry a version signal the client can compare against its cached copy

### Non-Functional
- [ ] `client_completed_at` is bounds-checked, not blindly trusted
- [ ] No regression in `002-core-lesson-loop`'s existing backend test suite

### Quality
- [ ] Code coverage maintained on amended endpoints
- [ ] All acceptance criteria met
- [ ] Code reviewed and approved

---

## Bolt Suggestions

| Bolt | Type | Stories | Objective |
|------|------|---------|-----------|
| 008-offline-sync-service | DDD | 001, 002, 003 | Amend `001-lesson-service`'s endpoints for content versioning, timestamped streak attribution, and re-verified idempotent replay |

---

## Notes

Single bolt, unlike `002-core-lesson-loop`'s split — this unit is genuinely small (an amendment to existing endpoints, no new aggregate), so splitting it would be artificial.
