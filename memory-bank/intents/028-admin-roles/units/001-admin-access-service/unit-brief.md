---
unit: 001-admin-access-service
intent: 028-admin-roles
unit_type: backend
default_bolt_type: simple-construction-bolt
phase: inception
status: complete
created: '2026-10-13T09:30:00Z'
updated: '2026-10-13T09:30:00Z'
---

# Unit Brief: Admin Access Service

## Purpose

Know, on every request, whether the caller is an owner, a super admin or a course admin, and which courses they have.

## Scope

### In Scope
- Roles, the `admin_members` tables and repository, the new `require_admin` / `require_super_admin`, and `/admin/me`.

### Out of Scope
- The route checks, the Team API and the admin site.

---

## Assigned Requirements

| FR | Requirement | Priority |
|----|-------------|----------|
| FR-1 | Roles | Must |
| FR-2 | Admin members store | Must |
| FR-3 | The admin check | Must |
| FR-4 | Who am I | Must |

---

## Stories

| Story ID | Title | Priority | Status |
|----------|-------|----------|--------|
| 001-admin-roles-domain | The domain knows owners, super admins and course admins | Must | Complete (bolt 100) |
| 002-admin-members-store | Admins other than owners are stored with their courses | Must | Complete (bolt 101) |
| 003-admin-access-check | Every admin request resolves the caller's access | Must | Complete (bolt 102) |
| 004-admin-me-role | The admin site can ask who it is signed in as | Must | Complete (bolt 102) |

### 001-admin-roles-domain (FR-1)

**As a** super admin, **I want** the server to tell owners, super admins and course admins apart, **so that** each one gets exactly the access their role allows.

- [x] `ADMIN_ROLES = ("super_admin", "course_admin")` is a constant in `app/domain/admin.py`.
- [x] `AdminAccess` (frozen dataclass): `email`, `role`, `is_owner`, `course_ids` (`None` = all courses).
- [x] `resolve_access(email, owners, member)` returns an owner (super admin, all courses) when the email is in `ADMIN_EMAILS`, trimmed and case-insensitive, even when a stored member also exists.
- [x] A stored `super_admin` resolves to all courses; a stored `course_admin` to its course ids, possibly none.
- [x] No email, or an email that is neither an owner nor stored, resolves to `None`.
- [x] `normalise_email` trims and lower-cases; used everywhere emails are compared or stored.
- [x] Pure Python, no framework imports, with unit tests for each case.

### 002-admin-members-store (FR-2)

**As a** super admin, **I want** the team kept in the database, **so that** I can add helpers without editing the server's environment.

- [x] Table `admin_members`: `id` uuid PK, `email` unique not null (stored normalised), `role` with a check on the two roles, `created_by`, `updated_by`, `created_at`, `updated_at` (timezone-aware).
- [x] Table `admin_member_courses`: `member_id` FK `ON DELETE CASCADE`, `course_id` FK to `courses` `ON DELETE CASCADE`, PK on both.
- [x] One Alembic migration creates both; it upgrades and downgrades on SQLite and Postgres. Nothing is seeded.
- [x] Repository `find_by_email`, `get`, `list`, `add`, `update`, `remove`; `update` to `super_admin` deletes the member's course rows.
- [x] Deleting a course removes it from every member (test). Removing a member removes their course rows (test).
- [x] Adding an email that already exists raises a domain error (`AdminMemberExistsError`), not an `IntegrityError`.
- [x] Timestamps read back timezone-aware on SQLite (the `_utc` normalisation used by `voice_settings`).

### 003-admin-access-check (FR-3)

**As a** super admin, **I want** access read fresh on every request, **so that** removing someone, or a course from them, works on their next click.

- [x] `require_admin` returns `AdminAccess`, reading `ADMIN_EMAILS` and `admin_members` on every request.
- [x] No session: 401 as today. Resolves to nobody: 403 `not_admin` as today.
- [x] A course admin with no courses passes `require_admin`.
- [x] `AdminContext` carries the access (`ctx.access`); existing callers that build `AdminContext(email=...)` keep working (owner access by default only in tests' helpers, never in routes).
- [x] `require_super_admin` gives 403 `super_admin_only`, message "Only a super admin can do this", for a course admin.
- [x] A failure reading `admin_members` is a 503, never access (fail closed).
- [x] Existing admin tests (signed in through `ADMIN_EMAILS`) pass unchanged.

### 004-admin-me-role (FR-4)

**As an** admin, **I want** the site to know my role and courses, **so that** it shows me only what I can use.

- [x] `GET /api/v1/admin/me` returns `{email, role, is_owner, course_ids}`.
- [x] `course_ids` is `null` for an owner or super admin, and a list (possibly empty) for a course admin.
- [x] Any admin may call it; a non-admin is 403 `not_admin`.

---

## Dependencies

### Depends On
None.

---

## Bolt Suggestions

| Bolt | Type | Stories | Objective |
|------|------|---------|-----------|
| 100-admin-roles-domain | simple-construction-bolt | 001 | Model owners, super admins and course admins as pure domain code. |
| 101-admin-members-store | simple-construction-bolt | 002 | Store team members and their courses. |
| 102-admin-access-check | simple-construction-bolt | 003, 004 | Resolve access on every admin request and expose it on `/admin/me`. |
