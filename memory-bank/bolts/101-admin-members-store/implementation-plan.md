---
stage: plan
bolt: 101-admin-members-store
created: '2026-10-13T10:15:00Z'
---

## Implementation Plan: admin-access-service

### Objective

Story 002 (FR-2). Store the team: each admin other than an owner, their
role and their courses. Nothing reads it for access yet; bolt 102 does.

### What the code says (checked before planning)

- **F1 Pattern:** intent 027's `voice_models.py`,
  `voice_settings_repository.py` and migration `a3f7c2e9b1d4` (the
  current single head). Models are imported in `migrations/env.py` and
  `tests/conftest.py`.
- **F2 Courses:** `CourseModel` (`lesson_models.py`, table `courses`,
  `id` `String(36)`). Curriculum tables reference it with
  `ondelete="CASCADE"`.
- **F3 SQLite foreign keys are off** in the app and in tests (only one
  sound-chart test turns `PRAGMA foreign_keys` on). So a cascade works
  on Neon but not in dev. `delete_course` deletes the course row
  through the ORM (`repo.delete_row`).
- **F4 Timestamps:** SQLite returns them without a zone; the voice
  repository's `_utc` fixes that.
- **F5 Migration tests:** `test_voice_settings_migration.py`, with
  `_ok` and `_alembic` from `test_courses_migration.py`. It also holds
  the "single head" test, which moves to the new migration's test.

### Decisions

- **D1 Models** in a new `app/infrastructure/db/admin_member_models.py`:

  | Table | Column | Type | Notes |
  |---|---|---|---|
  | `admin_members` | `id` | `String(36)` PK | uuid4 |
  | | `email` | `String(320)` not null | unique (`uq_admin_members_email`), stored normalised |
  | | `role` | `String(20)` not null | check `ck_admin_members_role`: `super_admin` or `course_admin` |
  | | `created_by`, `updated_by` | `String(320)` not null | admin email |
  | | `created_at`, `updated_at` | `DateTime(timezone=True)` not null | |
  | `admin_member_courses` | `member_id` | FK `admin_members.id`, `ON DELETE CASCADE` | PK part |
  | | `course_id` | FK `courses.id`, `ON DELETE CASCADE` | PK part, indexed |

- **D2 Cascades in code too** (F3): the repository deletes course rows
  itself when a member is removed or made a super admin, and gets
  `forget_course(course_id)`, which `delete_course` calls before
  deleting the course. Reads also join `courses`, so a stray row from
  before this bolt can never count.
- **D3 Repository** `SqlAlchemyAdminMemberRepository` in
  `admin_member_repository.py`, returning domain `AdminMember`:
  - `find_by_email(email)` (normalises first) → member or `None`;
  - `get(id)` → member or `None`;
  - `list_all()` → by email, courses loaded in one extra query;
  - `add(email, role, course_ids, admin)` → raises
    `AdminMemberExistsError` when the email is taken (checked first,
    with the `IntegrityError` also caught for a race);
  - `update(id, role, course_ids, admin)` → replaces the course rows;
    `super_admin` keeps none;
  - `remove(id)`;
  - `forget_course(course_id)`.
  - No validation of roles or course ids: bolt 109's use case does it.
    The check constraint refuses a bad role whatever happens.
  - The use case commits, as elsewhere; the repository flushes.
- **D4 `AdminMemberExistsError`** in `app/domain/exceptions.py`:
  409 `admin_member_exists`, registered with the error handlers.
- **D5 Migration** `c4e8a1f6d2b7_create_admin_members`, revising
  `a3f7c2e9b1d4`, written by hand. Nothing is seeded.

### Deliverables

- `admin_member_models.py`, imported in `migrations/env.py` and
  `tests/conftest.py`.
- `admin_member_repository.py`.
- The migration.
- `AdminMemberExistsError` and its handler mapping.
- `delete_course` calls `forget_course`.
- Tests:
  - `tests/integration/test_admin_members_repository.py`: add/find
    (mixed case), list order, update both ways, remove, duplicate
    email, `forget_course`, deleting a course clears it from members,
    aware timestamps.
  - `tests/integration/test_admin_members_migration.py`: single head,
    upgrade creates both empty tables with the role check and unique
    email, downgrade removes them. The single-head test leaves
    `test_voice_settings_migration.py`.

### Acceptance Criteria

- [x] Every criterion of story 002 in the unit brief.
- [x] `ruff`, `mypy` clean on touched files.
- [x] Full backend suite still passes.

---

## Implement (2026-10-13)

- `app/infrastructure/db/admin_member_models.py`: `AdminMemberModel`
  and `AdminMemberCourseModel` as D1; the role check is built from
  `ADMIN_ROLES`. Imported in `migrations/env.py` and `tests/conftest.py`.
- `app/infrastructure/db/admin_member_repository.py`:
  `SqlAlchemyAdminMemberRepository` as D3. Course ids are always read
  joined to `courses`; `_set_courses` replaces a member's rows and keeps
  none for a super admin.
- Migration `c4e8a1f6d2b7_create_admin_members` (revises
  `a3f7c2e9b1d4`): both tables, the role check, the unique email and an
  index on `admin_member_courses.course_id`.
- `delete_course` calls the new
  `SqlAlchemyAdminContentRepository.forget_course_admins(course_id)`
  before deleting the course (D2).

### Deviations from Plan

- **D4:** `AdminMemberExistsError` subclasses `AdminContentError` in
  `app/domain/lesson/exceptions.py`, not `app/domain/exceptions.py`.
  That base carries `details` (here `field: "email"`) to the client,
  as the Team dialog needs, and the voice errors already live there.
  Mapped to 409 in `error_handlers.py`.
- The single-head test moved from `test_voice_settings_migration.py`
  to `test_admin_members_migration.py`, as planned.

---

## Test (2026-10-13)

- `tests/integration/test_admin_members_repository.py`: 13 passed.
- `tests/integration/test_admin_members_migration.py`: 5 passed.
- Full backend suite: 1933 passed.
- `ruff` clean; `mypy app` shows only the 4 errors already present in
  files this bolt doesn't touch.

| Story 002 criterion | Test |
|---|---|
| `admin_members` columns, unique email, role check | `test_upgrade_adds_empty_team_tables`, `test_the_migrated_table_refuses_an_unknown_role`, `test_the_migrated_table_refuses_a_second_row_for_an_email` |
| `admin_member_courses` with cascades | `test_remove_deletes_the_member_and_their_courses`, `test_deleting_a_course_takes_it_off_its_admins` |
| Migration up and down, nothing seeded, single head | `test_upgrade_adds_empty_team_tables`, `test_downgrade_removes_the_tables`, `test_there_is_a_single_head` |
| Repository methods; super admin keeps no courses | `test_add_stores_a_normalised_email_and_find_ignores_case`, `test_list_is_by_email_with_courses`, `test_update_replaces_role_and_courses`, `test_making_a_course_admin_super_drops_their_courses`, `test_a_super_admin_keeps_no_course_rows`, `test_update_and_remove_of_an_unknown_id` |
| Duplicate email is a domain error | `test_a_second_member_with_the_same_email_is_refused` |
| Aware timestamps | `test_timestamps_read_back_with_a_zone` |
| Stray rows never count | `test_a_row_for_a_course_that_is_gone_never_counts`, `test_forget_course_takes_it_off_every_member` |

No issues found.
