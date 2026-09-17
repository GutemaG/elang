---
unit: 001-user-preferences-service
intent: 005-profile-and-settings
phase: inception
status: complete
created: '2026-09-17T07:50:00Z'
updated: '2026-09-17T07:50:00Z'
---

# Unit Brief: User Preferences Service

## Purpose

Amend `001-auth-service`'s `User` aggregate so `selected_language` and `daily_xp_target` can be changed after account creation through one explicit, documented endpoint, and add a new `notification_enabled` preference field. Deliberately formalizes an exception to the existing "written exactly once at creation" invariant rather than silently bypassing it.

## Scope

### In Scope
- A new endpoint accepting preference updates (language, daily goal, notification toggle)
- The domain-level invariant amendment itself (documented, with an ADR if the ADR-analysis stage confirms it's warranted)
- `notification_enabled` field: new column, no delivery-system wiring (none exists yet)
- Validation: goal/language values must be valid options (same option sets as onboarding's existing selection screens)

### Out of Scope
- Any UI (owned by `002-profile-and-settings-ui`)
- Building an actual notification-delivery system
- Any name/email/avatar field
- Sound preference (client-local, owned entirely by the UI unit)

---

## Assigned Requirements

| FR | Requirement | Priority |
|----|-------------|----------|
| FR-2 | Edit Daily Goal | Must |
| FR-3 | Edit Language Preference | Must |
| FR-4 | Notification Toggle (Stored, Not Yet Wired) | Must |

---

## Domain Concepts

### Key Entities
| Entity | Description | Attributes |
|--------|-------------|------------|
| `User` (existing, amended) | Aggregate root | Gains `notification_enabled: bool`; `selected_language`/`daily_xp_target` invariant amended from "write-once" to "write-once-then-only-via-this-endpoint" |

### Key Operations
| Operation | Description | Inputs | Outputs |
|-----------|-------------|--------|---------|
| UpdateUserPreferences | Change language/daily-goal/notification-enabled for the authenticated user | user_id, new values | Updated `User` |

---

## Story Summary

| Metric | Count |
|--------|-------|
| Total Stories | 2 |
| Must Have | 2 |
| Should Have | 0 |
| Could Have | 0 |

### Stories

| Story ID | Title | Priority | Status |
|----------|-------|----------|--------|
| 001-update-daily-goal-and-language | Change daily goal and language preference after account creation | Must | Planned |
| 002-store-notification-preference | Persist a notification on/off preference | Must | Planned |

---

## Dependencies

### Depends On
| Unit | Reason |
|------|--------|
| None | Extends existing `001-auth-service` code in place |

### Depended By
| Unit | Reason |
|------|--------|
| `002-profile-and-settings-ui` | Needs the real endpoint contract to build the Settings screen's edit flows against |

### External Dependencies
| System | Purpose | Risk |
|--------|---------|------|
| None | — | — |

---

## Technical Context

### Suggested Technology
Python/FastAPI, extending `backend/app/domain/entities.py` (`User`), `backend/app/domain/services.py`/`app/application/use_cases.py` (new use case), `backend/app/infrastructure/db/models.py`/`repositories.py` (new column + update method), `backend/app/infrastructure/api/routers.py`/`schemas.py` (new endpoint) — same files/patterns `001-auth-service` already established. Requires an Alembic migration (new `notification_enabled` column) — verify constant-default requirements against the SQLite `ADD COLUMN` + `NOT NULL` gotcha already documented in this project's errata (`001-offline-sync-service`'s construction-log) before writing it.

### Integration Points
| Integration | Type | Protocol |
|-------------|------|----------|
| `002-profile-and-settings-ui` | API | REST over HTTPS, session-token auth (existing pattern) |

### Data Storage
| Data | Type | Volume | Retention |
|------|------|--------|-----------|
| `notification_enabled` | New column on existing `users` table | 1 bool per user | Same lifecycle as the user row |

---

## Constraints

- Must not weaken session-token authentication or introduce a new auth mechanism.
- The invariant amendment must be explicit and documented (comment + likely ADR), not a silent removal of the existing "write-once" language in `entities.py`'s docstring.
- Goal/language value sets must match the existing onboarding selection screens exactly — no new values invented here.

---

## Success Criteria

### Functional
- [ ] Authenticated user can change language, daily goal, and notification-enabled via the new endpoint
- [ ] Invalid goal/language values are rejected (422), matching the existing validation-error pattern
- [ ] `notification_enabled` defaults sensibly for existing users (backfilled, not left null)

### Non-Functional
- [ ] No regression to `001-auth-service`'s existing test suite

### Quality
- [ ] Unit + integration test coverage for the new use case and endpoint
- [ ] All acceptance criteria met
- [ ] Code reviewed and approved

---

## Bolt Suggestions

| Bolt | Type | Stories | Objective |
|------|------|---------|-----------|
| 013-user-preferences-service | ddd-construction-bolt | 001, 002 | Invariant amendment + new endpoint + notification field |

---

## Notes

Unlike `004-match-pairs-exercise-type`'s purely additive backend unit, this one amends a documented domain invariant — treat the ADR Analysis stage seriously here; skipping it just because the last bolt didn't need one would be following a pattern rather than judging this bolt's actual decision on its own merits.
