---
stage: plan
bolt: 102-admin-access-check
created: '2026-10-13T11:05:00Z'
---

## Implementation Plan: admin-access-service

### Objective

Stories 003 and 004 (FR-3, FR-4). `require_admin` resolves the caller's
access from `ADMIN_EMAILS` and the team tables on every request, and
`/admin/me` says what it is. A stored member can now sign in; the
routes don't restrict anything yet (bolts 103–107 do).

### What the code says (checked before planning)

- **F1** `require_admin` (`dependencies.py`) takes the `User` from
  `get_current_user` and checks `is_admin(user.email, ADMIN_EMAILS)`.
  It returns the `User`.
- **F2** Six routers use it at router level. Four build their context
  with `_ctx(admin: User = Depends(require_admin))` →
  `AdminContext(email=admin.email or "", allow_local_media=...)`
  (`admin_routers`, `curriculum_routers`, `sound_routers`,
  `voice_routers`). `get_admin_me` and `patch_app_config` take the
  `User` directly. FastAPI resolves a dependency once per request, so
  the router-level and `_ctx` uses share one lookup.
- **F3** `AdminContext` (`admin_content_use_cases.py`) is a frozen
  dataclass `email`, `allow_local_media`. Tests build it directly, for
  example `AdminContext(email=OWNER)`.
- **F4** `test_admin_endpoints.py` asserts `/admin/me` is exactly
  `{"email": ADMIN}`; that test changes with the new fields.
- **F5** The 41 test files that sign in through `ADMIN_EMAILS` become
  owners, so they keep their access.

### Decisions

- **D1 `require_admin` returns `AdminAccess`:**
  - `owners = parse_admin_emails(settings.admin_emails)`;
  - if the email is an owner, no database read;
  - otherwise `SqlAlchemyAdminMemberRepository(session).find_by_email`;
  - `resolve_access(...)`; `None` → `NotAdminError` (403 `not_admin`),
    as today.
  - The old `is_admin` and its tests go (bolt 100 D6); its cases are
    covered by `resolve_access`.
- **D2 Fail closed:** a `SQLAlchemyError` while reading the team is
  logged and raised as a new `AdminAccessUnavailableError`
  (`AuthDomainError`, 503 `admin_access_unavailable`, "Admin access
  can't be checked right now. Try again.").
- **D3 `require_super_admin`:** depends on `require_admin`; a course
  admin gets a new `SuperAdminOnlyError` (`AuthDomainError`, 403
  `super_admin_only`, "Only a super admin can do this"). Not used on
  any route yet (bolt 103).
- **D4 `AdminContext.access: AdminAccess | None = None`.** Each `_ctx`
  passes the request's access. `None` is only for code with no request
  behind it (tests, scripts); bolt 104 decides how course checks treat
  it.
- **D5 Callers:** the four `_ctx` functions, `get_admin_me` and
  `patch_app_config` take `access: AdminAccess` instead of
  `admin: User` and use `access.email`.
- **D6 `/admin/me`:** `AdminMeResponse` gains `role`, `is_owner` and
  `course_ids: list[str] | None` (sorted; `null` for a super admin).
- **D7 Local database:** back up `backend/dev.db` to
  `dev.db.bak-028-102`, then `alembic upgrade head` on it, so the local
  server works with the new lookup. Production is untouched.

### Deliverables

- `dependencies.py`: D1–D3.
- `app/domain/exceptions.py` + `error_handlers.py`: the two errors.
- `admin_content_use_cases.py`: D4. Routers: D5. `admin_schemas.py`: D6.
- `app/domain/admin.py`: `is_admin` removed; tests updated.
- Tests (`tests/integration/test_admin_access.py`):
  - an owner, a stored super admin, a course admin with courses and one
    with none can each call `/admin/me`, with the right body;
  - an owner also stored is still an owner;
  - a removed member's next request is 403;
  - a course admin passes the router guard of an existing route
    (`GET /admin/courses`) — restrictions come later;
  - `require_super_admin` refuses a course admin (on a test-only route);
  - a broken team lookup is 503, not access.
- `test_admin_endpoints.py`: `/me` body assertion updated.

### Acceptance Criteria

- [x] Every criterion of stories 003 and 004.
- [x] `ruff` clean; `mypy` no new errors.
- [x] Full backend suite passes.

---

## Implement (2026-10-13)

- `dependencies.py`: `require_admin` returns `AdminAccess` (D1). An
  owner needs no database read; anyone else is looked up with
  `SqlAlchemyAdminMemberRepository.find_by_email`. A `SQLAlchemyError`
  is logged and raised as `AdminAccessUnavailableError` (503, D2).
  `require_super_admin` added (D3), not on any route yet.
- `app/domain/exceptions.py`: `SuperAdminOnlyError` (403
  `super_admin_only`) and `AdminAccessUnavailableError` (503
  `admin_access_unavailable`), mapped in `error_handlers.py`.
- `AdminContext.access` (D4); the four `_ctx` functions,
  `get_admin_me` and `patch_app_config` take `AdminAccess` (D5).
- `/admin/me` returns `email`, `role`, `is_owner`, `course_ids` (D6).
- `is_admin` removed from `app/domain/admin.py`; its cases moved to
  `resolve_access` tests (exact match, empty allow-list).
- `tests/team.py`: `add_member` / `remove_member` helpers for tests that
  sign in as a team member (used by bolts 103–109).
- Local `dev.db` backed up to `dev.db.bak-028-102` and upgraded to
  `c4e8a1f6d2b7` (D7). Production untouched.
- No deviations from the plan.

---

## Test (2026-10-13)

- `tests/integration/test_admin_access.py`: 12 passed.
- `tests/integration/test_admin_endpoints.py` and
  `tests/unit/test_admin_policy.py`: passed (the `/me` body assertion
  now has the new fields).
- Full backend suite: 1938 passed.
- `ruff` clean; `mypy app` shows only the 4 earlier errors.

| Criterion | Test |
|---|---|
| Access read on every request; removal is immediate | `test_removing_a_member_revokes_on_the_next_request` |
| 401 without a session, 403 `not_admin` for nobody | `test_admin_endpoints.py` 401 cases, `test_someone_not_on_the_team_is_403` |
| A course admin with no courses passes | `test_a_course_admin_with_no_courses_can_still_sign_in`, `test_a_course_admin_passes_the_router_guard` |
| `AdminContext` carries the access | the four `_ctx` functions; exercised by every admin route test |
| `require_super_admin` → 403 `super_admin_only` | `test_super_admin_only_refuses_a_course_admin`, `test_super_admin_only_lets_a_super_admin_through` |
| Fail closed: 503 | `test_a_team_that_cannot_be_read_is_503_not_access`; owners unaffected: `test_an_owner_needs_no_team_read` |
| Existing `ADMIN_EMAILS` tests unchanged | full suite |
| `/admin/me` body for each role | `test_an_owner_is_a_super_admin`, `test_an_owner_on_the_team_is_still_an_owner`, `test_a_stored_super_admin_has_every_course`, `test_a_course_admin_has_their_courses` |

No issues found.
