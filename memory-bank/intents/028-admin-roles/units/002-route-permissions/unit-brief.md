---
unit: 002-route-permissions
intent: 028-admin-roles
unit_type: backend
default_bolt_type: simple-construction-bolt
phase: inception
status: complete
created: '2026-10-13T09:30:00Z'
updated: '2026-10-13T09:30:00Z'
---

# Unit Brief: Route Permissions

## Purpose

Apply the roles to every admin route: super admin only, course-scoped, language-scoped or open.

## Scope

### In Scope
- `require_super_admin` on configuration routes, course checks on content routes, language checks on Sounds and generation, and a sweep test.

### Out of Scope
- The Team API.
- Hiding actions in the admin site.

---

## Assigned Requirements

| FR | Requirement | Priority |
|----|-------------|----------|
| FR-5 | Super admin only | Must |
| FR-6 | Any admin, filtered | Must |
| FR-7 | Course content | Must |
| FR-8 | Languages a course admin may use | Must |
| FR-9 | The check can't be forgotten | Must |

---

## Stories

| Story ID | Title | Priority | Status |
|----------|-------|----------|--------|
| 005-super-admin-only-routes | Configuration, courses, learners and feedback are for super admins | Must | Complete (bolt 103) |
| 006-course-list-filtered | A course admin's course list has only their courses | Must | Complete (bolt 104) |
| 007-course-id-routes | Routes named by course check the course | Must | Complete (bolt 104) |
| 008-child-id-routes | Routes named by a section, skill, lesson, exercise or word check its course | Must | Complete (bolt 105) |
| 009-language-scoped-routes | Sounds and generation are open for a course admin's languages | Must | Complete (bolt 106) |
| 010-route-guard-sweep | No admin route can skip the role decision | Must | Complete (bolt 107) |

### 005-super-admin-only-routes (FR-5)

**As an** owner, **I want** configuration kept to super admins, **so that** helpers can't change things outside their courses.

- [x] These use `require_super_admin`: `POST`/`PATCH`/`DELETE /admin/courses…`; `POST`/`PATCH`/`DELETE /admin/languages…`; `GET`/`PATCH /admin/app-config`; `PUT /admin/voice/settings/{language}`; `GET /admin/voice/usage`; `POST /admin/sound-charts`; `DELETE /admin/sound-charts/{language}`; `GET /admin/learners`, `/admin/learners/{id}`, `/admin/reports`; `GET`/`PATCH /admin/feedback…`.
- [x] A course admin gets 403 `super_admin_only` on each (parametrised test over the list).
- [x] A super admin stored on the Team (not an owner) can call each.
- [x] Nothing is written when a course admin is refused.

### 006-course-list-filtered (FR-6)

**As a** course admin, **I want** to see only my courses, **so that** I'm not distracted by, or able to open, other courses.

- [x] `GET /admin/courses` returns only the caller's courses for a course admin, in the usual order.
- [x] A course admin with no courses gets an empty list (200).
- [x] Super admins and owners still get every course.

### 007-course-id-routes (FR-7)

**As a** course admin, **I want** my courses' tree, vocabulary and Workbook open as before, **so that** I can keep working; others' courses stay closed.

- [x] A `require_course(course_id)` check covers every route with `{course_id}` in its path: the tree, `POST …/sections`, `PUT …/sections/order`, `GET …/vocab`, and every Workbook route under `/courses/{course_id}/curriculum` (read, save, rows, audio uploads, lesson exercises, publish).
- [x] A course admin without the course gets 404 with the same body as an unknown course id.
- [x] A course admin with the course can do everything they could before, publishing included.

### 008-child-id-routes (FR-7)

**As a** course admin, **I want** every edit inside my course to work, **so that** and every edit outside it to be refused.

- [x] A repository method `course_of(kind, id)` finds the course of a `section`, `skill`, `lesson`, `exercise` or `vocab_item` in one query; `None` for an unknown id.
- [x] These routes check that course: `/sections/{id}…` (edit, delete, add skill, skill order), `/skills/{id}…` (edit, delete, add lesson, lesson order), `/lessons/{id}…` (edit, delete, list, add, import, order exercises), `/exercises/{id}` (edit, delete), `/vocab/{id}`.
- [x] `POST /admin/audio/uploads` and `POST /admin/images/uploads` check the lesson's course when `lesson_id` is given.
- [x] `POST /admin/voice/generate` checks the lesson's course when `lesson_id` is given.
- [x] Another course's id gives 404, the same as an unknown id; nothing changes in the database.

### 009-language-scoped-routes (FR-6, FR-8)

**As a** course admin, **I want** to edit and record the Sounds chart of the languages my courses teach, **so that** learners hear every letter.

- [x] A course admin's languages are the learning languages of their courses.
- [x] `GET /admin/sound-charts` lists only those languages' charts for a course admin.
- [x] `GET`/`PATCH /admin/sound-charts/{language}`, adding, changing and deleting letters, and the letter upload link are allowed for those languages; another language is 404.
- [x] `POST /admin/voice/generate` with `language` (no `lesson_id`) is allowed for those languages; another is 403 `super_admin_only`.
- [x] `GET /admin/languages`, `GET /admin/voice/settings`, `GET /admin/voice/voices` and `POST /admin/audio/links` stay open to any admin.
- [x] Uploads without `lesson_id` stay open to any admin.

### 010-route-guard-sweep (FR-9)

**As an** owner, **I want** a test that fails when a new admin route forgets its check, **so that** a helper never gets access by accident.

- [x] Each admin route declares its rule (`super`, `any`, `course`, `language`) in one table the guard test reads.
- [x] A test walks every route under `/api/v1/admin` in the app and fails when a route is not in the table, or is in it with no matching dependency.
- [x] A test signs in as a course admin with one course and calls every `course` route with ids from another course: each is 404 or 403 and the database is unchanged.

---

## Dependencies

### Depends On
- `001-admin-access-service`

---

## Bolt Suggestions

| Bolt | Type | Stories | Objective |
|------|------|---------|-----------|
| 103-super-admin-routes | simple-construction-bolt | 005 | Keep configuration, course writes, learners and feedback to super admins. |
| 104-course-id-routes | simple-construction-bolt | 006, 007 | Filter the course list and check routes named by course. |
| 105-child-id-routes | simple-construction-bolt | 008 | Check the course behind section, skill, lesson, exercise and word routes. |
| 106-language-scoped-routes | simple-construction-bolt | 009 | Open Sounds and generation for a course admin's languages. |
| 107-route-guard-sweep | simple-construction-bolt | 010 | Fail the build when an admin route has no role rule. |
