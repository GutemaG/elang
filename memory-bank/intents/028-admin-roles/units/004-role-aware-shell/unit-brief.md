---
unit: 004-role-aware-shell
intent: 028-admin-roles
unit_type: frontend
default_bolt_type: simple-construction-bolt
phase: inception
status: complete
created: '2026-10-13T09:30:00Z'
updated: '2026-10-13T09:30:00Z'
---

# Unit Brief: Role-aware Shell

## Purpose

Make the admin site know the signed-in role, and group the configuration pages.

## Scope

### In Scope
- The session's role, `useAccess()`, the not-on-the-team screen, the Configuration nav group and redirects.

### Out of Scope
- The Team page's content.
- Hiding actions inside course pages.

---

## Assigned Requirements

| FR | Requirement | Priority |
|----|-------------|----------|
| FR-12 | Session knows the role | Must |
| FR-13 | Navigation | Must |

---

## Stories

| Story ID | Title | Priority | Status |
|----------|-------|----------|--------|
| 013-session-knows-role | The admin site knows the signed-in role | Must | Complete (bolt 110) |
| 014-configuration-nav | Configuration has its own nav group | Must | Complete (bolt 111) |

### 013-session-knows-role (FR-12)

**As an** admin, **I want** the site to know my role and courses, **so that** it can show me only what I may use.

- [x] The admin `SessionState` carries `email`, `role`, `isOwner` and `courseIds` from `/admin/me`.
- [x] `useAccess()` returns `isSuper` and `canOpenCourse(id)`.
- [x] A 403 `super_admin_only` shows "Only a super admin can do this" where the action was.
- [x] `NotAuthorisedScreen` says "{email} is signed in, but is not on the team. Ask a super admin to add this address." and no longer mentions `ADMIN_EMAILS`.

### 014-configuration-nav (FR-13)

**As a** super admin, **I want** configuration grouped in one place, **so that** I find Team, Languages, Voices and App updates together.

- [x] Super admin nav: Workspace (Curriculum, Vocabulary, Workbook, Sounds, Guide); Learners (Dashboard, Learners, Feedback); Configuration (Team, Languages, Voices, App updates).
- [x] The "App" group is gone; URLs of moved pages don't change.
- [x] Team: icon `group_add`, URL `/team` (a placeholder page until bolt 112).
- [x] A course admin sees only Workspace.
- [x] A course admin opening `/team`, `/languages`, `/voices`, `/app-updates`, `/dashboard`, `/learners…` or `/feedback` directly is sent to `/`.

---

## Dependencies

### Depends On
- `001-admin-access-service`

---

## Bolt Suggestions

| Bolt | Type | Stories | Objective |
|------|------|---------|-----------|
| 110-session-role | simple-construction-bolt | 013 | Carry the role in the admin session. |
| 111-configuration-nav | simple-construction-bolt | 014 | Group configuration pages and keep course admins out of them. |
