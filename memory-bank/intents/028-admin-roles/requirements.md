---
intent: 028-admin-roles
phase: inception
status: complete
created: '2026-10-13T09:00:00Z'
updated: '2026-10-13T09:30:00Z'
---

# Requirements: Super admins and course admins

## Intent Overview

Today an admin is anyone whose verified email is in `ADMIN_EMAILS`
(ADR-16, bolt 034). Every admin can change everything. That doesn't
scale once other people help write lessons, and adding a helper means
editing the server's environment and redeploying.

This intent adds two roles, both managed on a new **Team** page:

- A **super admin** does everything an admin does today. Only a super
  admin creates or deletes courses, manages the team, and changes the
  configuration: languages, voices and app updates. Only a super admin
  sees learners, the dashboard and feedback.
- A **course admin** works only on the courses a super admin chose for
  them. For example, someone who speaks Amharic and Afaan Oromo may be
  given the four courses between them and English. In those courses
  they can edit the tree, exercises, vocabulary and Workbook, record,
  upload and generate audio, and publish lessons. They can also edit
  and record the Sounds chart of each language their courses teach.

`ADMIN_EMAILS` stays. The emails in it are **owners**: always super
admins, shown on the Team page but not editable there, so the site can
never lock its owner out. Every other admin, super admins included, is
added and removed on the Team page.

## Current state (2026-10-13)

| Topic | What is there |
|---|---|
| Admin check | `require_admin` in `app/infrastructure/api/dependencies.py`: a signed-in user whose `email` is in `ADMIN_EMAILS`, read on every request. Missing or bad session is 401; a non-admin is 403 `not_admin`. |
| Admin routes | 8 routers with a router-level `require_admin`: `admin_routers` (content, courses, languages, app config, uploads), `curriculum_routers` (Workbook), `sound_routers` (admin part), `voice_routers`, `admin_learner_routers`, `feedback_routers` (admin part). |
| How routes name their course | Some by `course_id` in the path (`/courses/{id}/…`, the Workbook). Others by a child: `section_id`, `skill_id`, `lesson_id`, `exercise_id`, `vocab_item_id`. Sounds are by `language`. Uploads take an optional `lesson_id`. |
| `users.email` | Google's verified email from the latest sign-in. Not unique. Used only for the admin check. |
| Admin site | `GET /api/v1/admin/me` returns `{email}`. A 403 shows `NotAuthorisedScreen`, which tells the person to be added to `ADMIN_EMAILS`. |
| Courses | 4 courses: English→Amharic, English→Afaan Oromo, Amharic→Afaan Oromo, Afaan Oromo→Amharic. |
| Tests | 41 backend test files sign in as an admin by setting `ADMIN_EMAILS`. Owners stay super admins, so they keep passing unchanged. |

## Business Goals

| Goal | Success Metric | Priority |
|------|----------------|----------|
| Add a helper without a deploy | A super admin adds a course admin by email, with their courses, in under a minute; the helper's next sign-in works | Must |
| Helpers see only their courses | A course admin can neither see nor change anything in a course they weren't given, through the site or the API | Must |
| Configuration stays with super admins | Courses, languages, voices, app updates, team, learners and feedback are refused to course admins | Must |
| The owner can't be locked out | An `ADMIN_EMAILS` owner is a super admin whatever the database says | Must |
| Changes are immediate | Removing an admin, or a course from them, takes effect on their next request | Must |

## Scope

In scope:

- **Backend:**
  - Roles and course assignments: tables, migration, repository.
  - Role and course checks on every admin route.
  - Team API: list, add, change and remove admins.
  - `GET /api/v1/admin/me` returns the role and courses.
- **Admin:**
  - A **Configuration** nav group for super admins: Team, Languages,
    Voices, App updates.
  - The Team page.
  - Course admins see only their courses, and no actions they can't
    use.

Out of scope:

- Roles in the learner app. Learners are unchanged.
- Invitations by email. The super admin tells the person to sign in;
  no message is sent.
- Finer permissions than the two roles, such as read-only admins, or
  courses that may be edited but not published.
- Sign-in with anything other than Google on the admin site.
- An audit history page. Changes are logged, as admin writes are today.

---

## Functional Requirements

### Backend: who is an admin

#### FR-1: Roles
- **Description**: The domain knows two roles and the owners.
- **Acceptance Criteria**:
  - Roles are `super_admin` and `course_admin`, as a domain constant.
  - An **owner** is an email in `ADMIN_EMAILS`, compared trimmed and
    case-insensitive, as `parse_admin_emails` does today.
  - Resolving an email gives one of:
    - `owner`: super admin, all courses;
    - a stored `super_admin`: all courses;
    - a stored `course_admin` with its course ids (possibly none);
    - nobody.
  - An owner who is also stored is treated as an owner; the stored row
    is ignored.
  - Pure Python in `app/domain/admin.py`, with unit tests.
- **Priority**: Must

#### FR-2: Admin members store
- **Description**: Admins other than owners are stored in the database.
- **Acceptance Criteria**:
  - New table `admin_members`:
    - `id` (uuid PK);
    - `email` (text, not null, unique; stored trimmed and lower-case);
    - `role` (text, not null, check `super_admin` or `course_admin`);
    - `created_by`, `updated_by` (admin email);
    - `created_at`, `updated_at` (timestamps with time zone).
  - New table `admin_member_courses`:
    - `member_id` (FK to `admin_members`, `ON DELETE CASCADE`);
    - `course_id` (FK to `courses`, `ON DELETE CASCADE`);
    - primary key on both.
  - Deleting a course removes it from every admin's list. Deleting a
    member removes their courses.
  - A super admin's row has no course rows. Changing a course admin to
    super admin deletes theirs.
  - One Alembic migration creates both tables. It runs on SQLite (dev)
    and Postgres (Neon). Nothing is seeded: owners come from
    `ADMIN_EMAILS`.
  - Repository: `find_by_email(email)`, `get(id)`, `list()`,
    `add(email, role, course_ids, admin)`,
    `update(id, role, course_ids, admin)`, `remove(id)`.
  - Unique-email clash on add is a domain error (FR-11), not a database
    error.
- **Priority**: Must

#### FR-3: The admin check
- **Description**: `require_admin` decides who may call admin routes,
  and what they may reach.
- **Acceptance Criteria**:
  - It resolves the signed-in user's `email` (FR-1) on every request,
    reading `ADMIN_EMAILS` and `admin_members` each time. Removing
    someone, or a course from them, takes effect on their next request.
  - It returns an `AdminAccess` value: `email`, `role`, `is_owner`, and
    `course_ids` (`None` meaning all courses).
  - No session is 401, as today. A user who resolves to nobody is 403
    `not_admin`, as today. A course admin with no courses is still an
    admin: they can sign in and see an empty list.
  - `AdminContext` (used by the use cases) carries the access, so use
    cases can check a course.
  - A new dependency `require_super_admin` is 403 `super_admin_only`
    ("Only a super admin can do this") for a course admin.
- **Priority**: Must

#### FR-4: Who am I
- **Description**: `GET /api/v1/admin/me` tells the site what to show.
- **Acceptance Criteria**:
  - Response: `{email, role, is_owner, course_ids}`. `course_ids` is
    `null` for a super admin and a list for a course admin.
  - Any admin may call it.
- **Priority**: Must

### Backend: what each role may reach

#### FR-5: Super admin only
- **Description**: These routes use `require_super_admin`.
- **Acceptance Criteria**:

  | Area | Routes |
  |---|---|
  | Courses | `POST /admin/courses`, `PATCH /admin/courses/{id}`, `DELETE /admin/courses/{id}` |
  | Languages | `POST`, `PATCH`, `DELETE /admin/languages…` |
  | App updates | `GET`, `PATCH /admin/app-config` |
  | Voices | `PUT /admin/voice/settings/{language}`, `GET /admin/voice/usage` |
  | Sounds | `POST /admin/sound-charts` (new chart), `DELETE /admin/sound-charts/{language}` |
  | Learners | `GET /admin/learners`, `GET /admin/learners/{id}`, `GET /admin/reports` |
  | Feedback | `GET /admin/feedback`, `PATCH /admin/feedback/{id}` |
  | Team | every route in FR-10 |

  - A course admin gets 403 `super_admin_only` on each one.
- **Priority**: Must

#### FR-6: Any admin, filtered
- **Description**: These routes stay open to course admins, but show
  only what is theirs.
- **Acceptance Criteria**:
  - `GET /admin/courses` lists only the caller's courses for a course
    admin, in the usual order.
  - `GET /admin/sound-charts` lists only charts whose language is the
    learning language of one of the caller's courses.
  - `GET /admin/languages`, `GET /admin/voice/settings` and
    `GET /admin/voice/voices` are open to any admin, unfiltered: the
    course list and the Generate tab read them.
  - `POST /admin/audio/links` is open to any admin (it only checks a
    link).
- **Priority**: Must

#### FR-7: Course content
- **Description**: Every route that reads or changes a course's content
  checks that the caller has that course.
- **Acceptance Criteria**:
  - The course is found from the route:

    | Route names | Course from |
    |---|---|
    | `/courses/{course_id}/…` (tree, sections, order, vocab, Workbook and its lessons, exercises, publish) | `course_id` |
    | `/sections/{section_id}…` | the section's course |
    | `/skills/{skill_id}…` | the skill's section's course |
    | `/lessons/{lesson_id}…` (edit, delete, exercises, import, order) | the lesson's course |
    | `/exercises/{exercise_id}` | the exercise's lesson's course |
    | `/vocab/{vocab_item_id}` | the item's course |
    | `POST /audio/uploads`, `POST /images/uploads` with `lesson_id` | the lesson's course |
    | `POST /admin/voice/generate` with `lesson_id` | the lesson's course |

  - A course admin without that course gets **404**, the same response
    as for an id that doesn't exist, so other courses' ids are not
    revealed.
  - The lookup is one query per request, through a repository method
    `course_of(kind, id)`.
  - A course admin may publish a lesson in their course (Workbook
    `POST …/lessons/{ref}/publish`).
- **Priority**: Must

#### FR-8: Languages a course admin may use
- **Description**: Where a route names a language, not a course, a
  course admin may use the languages their courses teach.
- **Acceptance Criteria**:
  - A course admin's languages are the **learning languages** of their
    courses. Someone given English→Amharic has `am`.
  - Sounds: `GET`, `PATCH /sound-charts/{language}`, adding, changing
    and deleting letters, and the letter upload link are allowed for
    those languages. Another language is 404.
  - `POST /admin/voice/generate` with `language` (no `lesson_id`) is
    allowed for those languages. Another is 403 `super_admin_only`.
  - `POST /audio/uploads` and `POST /images/uploads` **without**
    `lesson_id` are allowed for any admin. The key is random and the
    file is reachable only once saved into content the admin may edit.
- **Priority**: Must

#### FR-9: The check can't be forgotten
- **Description**: A new admin route can't skip the role decision by
  accident.
- **Acceptance Criteria**:
  - A test walks every route under `/api/v1/admin` in the FastAPI app
    and fails if a route is in neither the FR-5 list, the FR-6 list,
    nor uses a course or language check (FR-7, FR-8).
  - A test signs in as a course admin with one course and calls every
    content route with ids from another course; each gives 404 or 403,
    and nothing changes in the database.
- **Priority**: Must

### Backend: the team

#### FR-10: Team API
- **Description**: Super admins manage the team at
  `/api/v1/admin/team`.
- **Acceptance Criteria**:
  - `GET /admin/team` returns `members`, owners first then by email:
    - `id` (`null` for an owner);
    - `email`, `role`, `is_owner`;
    - `courses`: `[{id, title}]` for a course admin, `[]` otherwise;
    - `last_signed_in_at`: the newest `auth_sessions.issued_at` of any
      user with that email, or `null` ("Not signed in yet");
    - `created_by`, `created_at`, `updated_by`, `updated_at` (`null`
      for owners).
  - `POST /admin/team` with `{email, role, course_ids}` adds a member
    and returns it (201).
  - `PUT /admin/team/{id}` with `{role, course_ids}` changes a member
    and returns it. The email can't be changed; remove and add instead.
  - `DELETE /admin/team/{id}` removes a member (204).
  - For a `super_admin`, `course_ids` must be empty or left out.
  - Each write is logged: `admin_write action={add|update|remove}
    entity=admin_member id={id} role={role} courses={n}
    admin={email}`.
- **Priority**: Must

#### FR-11: Team rules
- **Description**: The team can't be broken by a mistake.
- **Acceptance Criteria**:

  | Situation | HTTP | Code / field | Message |
  |---|---|---|---|
  | Email not a valid address | 422 | field `email` | Enter an email address |
  | Email is an owner's | 409 | `admin_member_exists` | {email} is an owner already |
  | Email already a member | 409 | `admin_member_exists` | {email} is already on the team |
  | `role` not one of the two | 422 | field `role` | Choose super admin or course admin |
  | A course id doesn't exist | 422 | field `course_ids` | A chosen course no longer exists |
  | `course_ids` given for a super admin | 422 | field `course_ids` | A super admin has every course |
  | Changing or removing yourself | 409 | `admin_member_self` | You can't change your own access. Ask another super admin. |
  | Owner id (there is none) or unknown id | 404 | `entity: admin_member` | |

  - A course admin with **no** courses is allowed (for example, someone
    added before their course exists).
  - Because owners can't be changed and nobody can change themselves,
    there is always at least one super admin: the owner.
- **Priority**: Must

### Admin site

#### FR-12: Session knows the role
- **Description**: The site reads the role once per sign-in.
- **Acceptance Criteria**:
  - `SessionState` for an admin carries `email`, `role`, `isOwner` and
    `courseIds` from FR-4.
  - A hook `useAccess()` gives `isSuper` and `canOpenCourse(id)`.
  - A 403 `super_admin_only` from any call shows the usual error
    message, "Only a super admin can do this", in place.
  - `NotAuthorisedScreen` says: "{email} is signed in, but is not on
    the team. Ask a super admin to add this address." The
    `ADMIN_EMAILS` hint is removed.
- **Priority**: Must

#### FR-13: Navigation
- **Description**: The side nav shows each role what it can use.
- **Acceptance Criteria**:
  - Groups for a super admin:

    | Group | Items |
    |---|---|
    | Workspace | Curriculum, Vocabulary, Workbook, Sounds, Guide |
    | Learners | Dashboard, Learners, Feedback |
    | Configuration | Team, Languages, Voices, App updates |

    The "App" group is gone; App updates moves to Configuration.
    Languages and Voices move from Workspace to Configuration. Their
    URLs don't change.
  - A course admin sees only Workspace.
  - Team: icon `group_add`, URL `/team`.
  - A course admin who opens a super-admin URL directly is sent to `/`.
- **Priority**: Must

#### FR-14: Team page
- **Description**: `/team` lists the team and changes it.
- **Acceptance Criteria**:
  - Header "Team", description: "Who can sign in to Buna Studio, and
    which courses they work on." Eyebrow "Configuration".
  - A table: Email, Role ("Owner", "Super admin" or "Course admin"),
    Courses (titles, or "All courses", or "No courses yet"), Last
    signed in ("Not signed in yet" when null). It stacks into cards on
    a phone.
  - Owners show a lock icon and the hint "Set in the server's
    ADMIN_EMAILS". They have no Edit or Remove.
  - The signed-in super admin's own row says "You" and has no Edit or
    Remove.
  - **Add admin** opens a dialog:
    - Email (focused);
    - Role: "Course admin" (default) or "Super admin", as two radio
      cards with one line each: "Works on the courses you choose" /
      "Everything, including the team and configuration";
    - Courses: a checkbox per course, by title, shown only for a
      course admin, with "Select all";
    - Add / Cancel. Server field errors show under their field.
    - Help: "They sign in with Google using this address. No email is
      sent."
  - **Edit** opens the same dialog with the email read-only.
  - **Remove** asks to confirm in a dialog: "Remove {email}? They lose
    access on their next click." Remove / Cancel.
  - The list refreshes after each change.
- **Priority**: Must

#### FR-15: Course admins' Workspace
- **Description**: A course admin works only on their courses, and
  doesn't see actions they can't use.
- **Acceptance Criteria**:
  - Curriculum, Vocabulary and Workbook course lists show their courses
    (the API already filters, FR-6). With none: "No courses yet. Ask a
    super admin to give you one."
  - "New course", "Edit course" and "Delete course" are hidden.
  - Sounds lists only their languages' charts. "New chart" and "Delete
    chart" are hidden.
  - Everything else inside a course is unchanged: sections, skills,
    lessons, exercises, imports, vocabulary, the Workbook, publishing,
    and Record / Upload / Link / Generate.
  - A URL for another course shows the usual "not found" state.
- **Priority**: Must

---

## Non-Functional Requirements

### Security
- Every decision is made by the backend. The admin site hides what a
  role can't use, but hiding is not the protection.
- Fail closed: an error reading `admin_members` is a 503, never access.
- Emails are compared trimmed and lower-case everywhere.
- An admin's access is read on every request, never cached in the
  session token.
- No admin email is written to a log except as the `admin=` of a write,
  as today.

### Performance
- `require_admin` adds at most two indexed queries per request (member
  by email, and its course ids). The course lookup in FR-7 is one more.
- `GET /admin/team` is one query for members and courses, and one for
  last sign-ins.

### Reliability
- Existing tests that sign in through `ADMIN_EMAILS` pass unchanged:
  those admins are owners.
- The migration is additive. Rolling it back drops the two tables, and
  the old behaviour (owners only) is what remains.

## Constraints

### Technical Constraints
- FastAPI dependencies, async SQLAlchemy, Alembic. SQLite in dev, Neon
  Postgres in production.
- Admin: React 19, Vite, Tailwind, Vitest. Reuse `Modal`, `Button`,
  `Field` styles and `PageHeader`.
- Production steps (Neon migration, Vercel env) need the owner's
  go-ahead.

### Business Constraints
- The owner is the one email in `ADMIN_EMAILS` today. It stays that
  way.

## Assumptions

| Assumption | Risk if wrong | Mitigation |
|---|---|---|
| Admins sign in to the site with Google, so `users.email` is verified | A wrong email could get access | Only Google's verified email is stored (ADR-16) |
| A course admin's Sounds languages are their courses' learning languages | A helper might need a base language's chart too | A super admin can give them a course that teaches it |
| Uploads without `lesson_id` are harmless for course admins | A stray file in storage | Keys are random; files are only reachable once saved into content |

## Decisions (2026-10-13)

| Question | Decision |
|---|---|
| Can course admins publish? | Yes, lessons in their own courses. |
| Who sees learners, dashboard and feedback? | Super admins only. |
| Can course admins work on Sounds? | Yes: edit and record the charts of their courses' languages. Creating and deleting charts is for super admins. |
| `ADMIN_EMAILS` | Kept as owners, always super admins. More super admins are added on the Team page. |
| Course admin without that course | 404, as if it didn't exist. |
| Changing yourself | Not allowed; another super admin must do it. |

## Open Questions

None.
