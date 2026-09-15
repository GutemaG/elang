---
unit: 001-auth-service
intent: 001-auth-onboarding
phase: inception
status: ready
created: 2026-09-15T12:35:35Z
updated: 2026-09-15T12:35:35Z
unit_type: backend
default_bolt_type: ddd-construction-bolt
---

# Unit Brief: Auth Service

## Purpose

Own identity for Buna: verify Google OAuth and Sign in with Apple credentials, create or load the corresponding `users` row, and attach any pending pre-auth onboarding selections (language, daily goal) to a newly created account.

## Scope

### In Scope
- Verifying Google ID tokens and Apple identity tokens server-side
- Creating a new `users` row on first sign-in via either provider, with pending onboarding selections attached
- Loading an existing `users` row on repeat sign-in without overwriting real account state
- Issuing/persisting a session token the client can use across app restarts
- Account dedup by provider-stable ID (Apple's user identifier, not email)

### Out of Scope
- Rendering any UI (owned by `002-auth-onboarding-ui`)
- Email/password authentication (not in Phase 1 — auth-only via OAuth)
- Any teacher/admin/content-manager role (doesn't exist in Phase 1 — student-only)
- Streaks, XP, Beans, Amole logic (separate future gamification-engine intent)

---

## Assigned Requirements

| FR | Requirement | Priority |
|----|-------------|----------|
| FR-2 | Language + Daily Goal Selection (Pre-Auth) — persistence side | Must |
| FR-3 | Google OAuth Sign-Up/Sign-In | Must |
| FR-4 | Sign in with Apple | Must |

---

## Domain Concepts

### Key Entities
| Entity | Description | Attributes |
|--------|-------------|------------|
| User | A Buna learner account | id, auth_provider, provider_user_id, selected_language, daily_goal_minutes, session_token, created_at |
| PendingOnboardingSelection | Client-held, pre-auth state (not a DB entity — arrives as request payload on first auth) | selected_language, daily_goal_minutes |

### Key Operations
| Operation | Description | Inputs | Outputs |
|-----------|-------------|--------|---------|
| AuthenticateWithGoogle | Verify Google ID token, create-or-load user, attach pending selections if new | Google ID token, optional pending selections | User record, session token |
| AuthenticateWithApple | Verify Apple identity token, create-or-load user by stable Apple user ID, attach pending selections if new | Apple identity token, optional pending selections | User record, session token |
| ValidateSession | Verify a stored session token is still valid on app restart | Session token | Valid/invalid + User record if valid |

---

## Story Summary

| Metric | Count |
|--------|-------|
| Total Stories | 3 |
| Must Have | 3 |
| Should Have | 0 |
| Could Have | 0 |

### Stories

| Story ID | Title | Priority | Status |
|----------|-------|----------|--------|
| 001-persist-pending-onboarding-selections | Attach pending onboarding selections on first auth | Must | Planned |
| 002-google-oauth-authentication | Sign up / log in with Google | Must | Planned |
| 003-apple-sign-in-authentication | Sign in with Apple | Must | Planned |

---

## Dependencies

### Depends On
| Unit | Reason |
|------|--------|
| None | Foundation unit for this intent |

### Depended By
| Unit | Reason |
|------|--------|
| 002-auth-onboarding-ui | Needs the auth API contract and session tokens to integrate the sign-in screens |

### External Dependencies
| System | Purpose | Risk |
|--------|---------|------|
| Google OAuth | Primary identity provider | Medium — token verification must handle expiry/revocation correctly |
| Sign in with Apple | Required alongside Google (App Store policy) | Medium — private-relay email must not break account dedup |

---

## Technical Context

### Suggested Technology
FastAPI + SQLAlchemy (async) + Alembic per `memory-bank/standards/tech-stack.md` and `data-stack.md`. Token verification via each provider's official server-side verification library (Google: `google-auth`; Apple: JWT verification against Apple's public keys).

**Repo location**: lives in this same repository, under `backend/` at the root (alongside the Flutter app's `lib/`, `android/`, etc.) — a monorepo, not a separate repo.

**Local dev/test database**: SQLite via `aiosqlite`, per `data-stack.md`'s Local Development & Testing section — same SQLAlchemy async engine, just a different connection string. PostgreSQL remains the target for real deployment.

### Integration Points
| Integration | Type | Protocol |
|-------------|------|----------|
| 002-auth-onboarding-ui | API | REST over HTTPS |
| Google OAuth | External API | REST (token verification) |
| Sign in with Apple | External API | REST/JWT (identity token verification) |

### Data Storage
| Data | Type | Volume | Retention |
|------|------|--------|-----------|
| users | SQL (PostgreSQL) | Low initially (MVP launch) | Indefinite (account data) |

---

## Constraints

- No password storage anywhere — OAuth-only per intent requirements.
- Account dedup for Apple must use the stable user identifier, not email (private-relay emails are not reliable keys).
- Session tokens must never appear in logs (per `coding-standards.md`).

---

## Success Criteria

### Functional
- [ ] New user via Google or Apple creates a `users` row with pending onboarding selections attached
- [ ] Returning user via either provider logs in without pending-selection data overwriting real account state
- [ ] Session token issued and validated correctly across app restarts

### Non-Functional
- [ ] OAuth tokens verified server-side, never trusted from client claims alone
- [ ] No PII/tokens in logs

### Quality
- [ ] Code coverage > 80% on auth logic
- [ ] All acceptance criteria met
- [ ] Code reviewed and approved

---

## Bolt Suggestions

| Bolt | Type | Stories | Objective |
|------|------|---------|-----------|
| 001-auth-service | DDD | 001, 002, 003 | Full identity + onboarding-attach logic in one cohesive bolt |

---

## Notes

All three stories are tightly coupled (same aggregate — the `User` entity, same "verify token → create-or-load → attach pending state" shape), so they're planned as a single bolt rather than split further.
