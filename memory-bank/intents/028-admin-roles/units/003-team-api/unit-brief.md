---
unit: 003-team-api
intent: 028-admin-roles
unit_type: backend
default_bolt_type: simple-construction-bolt
phase: inception
status: complete
created: '2026-10-13T09:30:00Z'
updated: '2026-10-13T09:30:00Z'
---

# Unit Brief: Team API

## Purpose

Let super admins list, add, change and remove admins.

## Scope

### In Scope
- `GET`/`POST /admin/team`, `PUT`/`DELETE /admin/team/{id}`, the team rules and their errors.

### Out of Scope
- The Team page.

---

## Assigned Requirements

| FR | Requirement | Priority |
|----|-------------|----------|
| FR-10 | Team API | Must |
| FR-11 | Team rules | Must |

---

## Stories

| Story ID | Title | Priority | Status |
|----------|-------|----------|--------|
| 011-list-team | A super admin can see the whole team | Must | Complete (bolt 108) |
| 012-change-team | A super admin can add, change and remove admins | Must | Complete (bolt 109) |

### 011-list-team (FR-10)

**As a** super admin, **I want** to see who can sign in and what they can reach, **so that** I know who to add or remove.

- [x] `GET /admin/team` returns `members`, owners first, then by email.
- [x] Each member has `id` (`null` for an owner), `email`, `role`, `is_owner`, `courses` (`[{id, title}]` for a course admin, `[]` otherwise), `last_signed_in_at`, `created_by`, `created_at`, `updated_by`, `updated_at` (`null` for owners).
- [x] `last_signed_in_at` is the newest `auth_sessions.issued_at` of any user with that email, or `null`.
- [x] One query for members and courses, one for last sign-ins.
- [x] Super admin only (403 `super_admin_only` for a course admin).

### 012-change-team (FR-10, FR-11)

**As a** super admin, **I want** to add a helper with their courses, change them, or remove them, **so that** the team changes without a deploy.

- [x] `POST /admin/team` `{email, role, course_ids}` adds a member (201, the member as in story 011).
- [x] `PUT /admin/team/{id}` `{role, course_ids}` changes role and courses; the email can't change.
- [x] `DELETE /admin/team/{id}` removes a member (204).
- [x] Errors: bad email 422 `email` "Enter an email address"; an owner's email 409 `admin_member_exists` "{email} is an owner already"; a member's email 409 "{email} is already on the team"; bad role 422 `role` "Choose super admin or course admin"; unknown course 422 `course_ids` "A chosen course no longer exists"; courses for a super admin 422 `course_ids` "A super admin has every course".
- [x] Changing or removing yourself is 409 `admin_member_self` "You can't change your own access. Ask another super admin."
- [x] An unknown id is 404 `entity: admin_member`.
- [x] A course admin with no courses may be added.
- [x] Each write logs `admin_write action={add|update|remove} entity=admin_member id={id} role={role} courses={n} admin={email}`.
- [x] A removed member's next admin request is 403 `not_admin` (test).

---

## Dependencies

### Depends On
- `001-admin-access-service`

---

## Bolt Suggestions

| Bolt | Type | Stories | Objective |
|------|------|---------|-----------|
| 108-team-read-api | simple-construction-bolt | 011 | List the team for super admins. |
| 109-team-write-api | simple-construction-bolt | 012 | Add, change and remove admins with the team rules. |
