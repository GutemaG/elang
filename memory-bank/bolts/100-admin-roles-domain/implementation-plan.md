---
stage: plan
bolt: 100-admin-roles-domain
created: '2026-10-13T09:40:00Z'
---

## Implementation Plan: admin-access-service

### Objective

Story 001 (FR-1). Pure domain code that turns a signed-in email into
its access: an owner, a stored super admin, a stored course admin with
their courses, or nobody. Nothing reads it yet; bolt 102 wires it into
`require_admin`.

### What the code says (checked before planning)

- **F1** `app/domain/admin.py` holds `parse_admin_emails(allow_list)`
  and `is_admin(email, allow_list)`. Pure Python, no framework imports.
- **F2** `is_admin` has one caller, `require_admin` in
  `app/infrastructure/api/dependencies.py`. Its tests are
  `tests/unit/test_admin_policy.py`.
- **F3** Domain records elsewhere are frozen dataclasses
  (`VoiceSettings` in `app/domain/voices.py`).

### Decisions

- **D1 Constants:** `SUPER_ADMIN = "super_admin"`,
  `COURSE_ADMIN = "course_admin"`, `ADMIN_ROLES = (SUPER_ADMIN,
  COURSE_ADMIN)`.
- **D2 `normalise_email(email) -> str`:** trims and lower-cases.
  `parse_admin_emails` uses it, so owners and members compare the same
  way.
- **D3 `AdminMember`** (frozen dataclass), the stored member that bolt
  101's repository returns: `id`, `email`, `role`,
  `course_ids: frozenset[str]`, `created_by`, `created_at`,
  `updated_by`, `updated_at`.
- **D4 `AdminAccess`** (frozen dataclass): `email`, `role`, `is_owner`,
  `course_ids: frozenset[str] | None` (`None` = every course). Two
  helpers:
  - `is_super` (property): role is `super_admin`;
  - `can_open_course(course_id)`: `True` for a super admin, otherwise
    membership in `course_ids`.
- **D5 `resolve_access(email, owners, member) -> AdminAccess | None`:**
  - no email → `None`;
  - email in `owners` (a `frozenset` from `parse_admin_emails`) → owner,
    super admin, `course_ids=None`, whatever `member` is;
  - `member` with role `super_admin` → `course_ids=None`;
  - `member` with role `course_admin` → its `course_ids`;
  - otherwise `None`.
  - The caller finds `member` by the normalised email; this function
    does no lookups.
- **D6 Keep `is_admin`** unchanged for now, so nothing else moves in
  this bolt. Bolt 102 replaces its one caller and removes it.

### Deliverables

- `app/domain/admin.py`: D1–D5.
- `tests/unit/test_admin_policy.py`: new cases for `normalise_email`,
  `AdminAccess` helpers and each `resolve_access` branch, including an
  owner who is also stored, mixed-case emails and an empty course set.

### Acceptance Criteria

- [x] Every criterion of story 001 in the unit brief.
- [x] `ruff` and `mypy` clean on the touched files.
- [x] Full backend suite still passes.

---

## Implement (2026-10-13)

- `app/domain/admin.py`: `SUPER_ADMIN`, `COURSE_ADMIN`, `ADMIN_ROLES`,
  `normalise_email`, `AdminMember`, `AdminAccess` (`is_super`,
  `can_open_course`) and `resolve_access`, as D1–D5.
  `parse_admin_emails` and `is_admin` now use `normalise_email`; their
  behaviour is unchanged (D6).
- `can_open_course` fails closed: a course admin with no course list
  opens nothing; it is never read as "every course".
- An unknown stored role resolves to nobody, so a bad row can't grant
  access.
- No deviations from the plan.

---

## Test (2026-10-13)

- `tests/unit/test_admin_policy.py`: 25 passed (8 existing, 17 new).
- Full backend suite: 1916 passed.
- `ruff check`, `ruff format --check` and `mypy` clean on the touched
  files.

| Story 001 criterion | Test |
|---|---|
| `ADMIN_ROLES` constant | `TestRoles` |
| `AdminAccess` fields | `TestResolveAccess`, `TestAdminAccess` |
| Owner wins, even when stored; case-insensitive | `test_owner_is_super_admin_for_every_course`, `test_owner_wins_over_a_stored_row` |
| Stored super admin: all courses; course admin: theirs, possibly none | `test_stored_super_admin_has_every_course`, `test_course_admin_has_their_courses`, `test_course_admin_with_no_courses_is_still_an_admin` |
| Nobody otherwise | `test_anyone_else_is_nobody`, `test_unknown_stored_role_is_nobody` |
| `normalise_email` | `TestNormaliseEmail` |
| Pure Python | `app/domain/admin.py` imports only `dataclasses` and `datetime` |

No issues found.
