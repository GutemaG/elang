---
intent: 028-admin-roles
phase: inception
status: units-decomposed
updated: 2026-10-13T09:30:00Z
---

# Admin Roles - Unit Decomposition

## Units Overview

Six small units: three on the backend, three in the admin. Stories are
written inside each unit brief and numbered across the intent. Bolts
100–114 are one or two stories each.

### Unit 1: 001-admin-access-service

**Description:** Know, on every request, whether the caller is an owner, a super admin or a course admin, and which courses they have.

**Requirements:** FR-1, FR-2, FR-3, FR-4

**Deliverables:** Roles, the `admin_members` tables and repository, the new `require_admin` / `require_super_admin`, and `/admin/me`.

**Bolts:** `100-admin-roles-domain`, `101-admin-members-store`, `102-admin-access-check`

**Dependencies:** none.

**Estimated complexity:** S

### Unit 2: 002-route-permissions

**Description:** Apply the roles to every admin route: super admin only, course-scoped, language-scoped or open.

**Requirements:** FR-5, FR-6, FR-7, FR-8, FR-9

**Deliverables:** `require_super_admin` on configuration routes, course checks on content routes, language checks on Sounds and generation, and a sweep test.

**Bolts:** `103-super-admin-routes`, `104-course-id-routes`, `105-child-id-routes`, `106-language-scoped-routes`, `107-route-guard-sweep`

**Dependencies:** `001-admin-access-service`

**Estimated complexity:** M

### Unit 3: 003-team-api

**Description:** Let super admins list, add, change and remove admins.

**Requirements:** FR-10, FR-11

**Deliverables:** `GET`/`POST /admin/team`, `PUT`/`DELETE /admin/team/{id}`, the team rules and their errors.

**Bolts:** `108-team-read-api`, `109-team-write-api`

**Dependencies:** `001-admin-access-service`

**Estimated complexity:** S

### Unit 4: 004-role-aware-shell

**Description:** Make the admin site know the signed-in role, and group the configuration pages.

**Requirements:** FR-12, FR-13

**Deliverables:** The session's role, `useAccess()`, the not-on-the-team screen, the Configuration nav group and redirects.

**Bolts:** `110-session-role`, `111-configuration-nav`

**Dependencies:** `001-admin-access-service`

**Estimated complexity:** S

### Unit 5: 005-team-page

**Description:** Give super admins one page to manage the team.

**Requirements:** FR-14

**Deliverables:** The `/team` list, the add/edit dialog and the remove dialog.

**Bolts:** `112-team-list-page`, `113-team-member-dialogs`

**Dependencies:** `003-team-api`, `004-role-aware-shell`

**Estimated complexity:** S

### Unit 6: 006-course-admin-workspace

**Description:** Show a course admin only their courses and the actions they can use.

**Requirements:** FR-15

**Deliverables:** Empty course lists, hidden course and chart actions, and Sounds filtered to their languages.

**Bolts:** `114-course-admin-workspace`

**Dependencies:** `002-route-permissions`, `004-role-aware-shell`

**Estimated complexity:** S

## Execution order

1. `100` → `101` → `102` (access)
2. `103`, `104` → `105`, `106` → `107` (routes)
3. `108` → `109` (Team API), alongside step 2
4. `110` → `111` → `112` → `113` (shell and Team page)
5. `114` (course admin workspace)
