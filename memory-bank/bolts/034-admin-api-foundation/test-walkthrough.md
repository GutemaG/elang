---
stage: test
bolt: 034-admin-api-foundation
created: '2026-09-22T12:05:00Z'
---

## Test Report: content-admin-api

### Summary

- **Tests**: 640/640 passed across the full backend suite. That is 594 before
  this stage plus 46 new; one existing test was rewritten in Implement.
- **Lint**: `ruff check` and `ruff format --check` are clean over `app/` and
  `tests/`.
- **Coverage** (line, from `pytest --cov=app`):
  - 100% for the new or changed admin modules: `domain/admin.py`, `admin_routers.py`, `admin_schemas.py`, `dependencies.py`, `db/repositories.py`
  - 91% for `seed_lesson_content.py`; the uncovered lines are its CLI `main()`

### Test Files

- [x] `backend/tests/unit/test_admin_policy.py` - `ADMIN_EMAILS` parsing and
  `is_admin`:
  - case, whitespace and blank entries
  - fails closed on an empty list or a missing email
  - exact match, not a prefix
- [x] `backend/tests/unit/test_google_verifier_email.py` - the email is passed
  on only for `email_verified: true`, which must be a real boolean. Unverified,
  missing or string `"true"` are dropped.
- [x] `backend/tests/unit/test_authentication_service.py` (new
  `TestVerifiedEmail`):
  - a new user is created with the email
  - a returning user's email follows the latest sign-in, including back to
    `None`
  - an unchanged email is not rewritten
  - `update` (preferences) is never called on sign-in
  - Apple stores no email
- [x] `backend/tests/integration/test_admin_endpoints.py` - through the real
  `/auth/google` flow:
  - `401` with no token or an unknown token
  - `200` with the email for an admin, and case-insensitive matching
  - `403 not_admin` for a non-admin or an unverified email
  - removing an email revokes access on the next request
  - an empty allow-list admits nobody
  - an email changed at Google moves admin access
  - learner endpoints are unaffected
  - the router-level guard covers every admin route
- [x] `backend/tests/integration/test_user_email_repository.py` -
  `users.email` round-trips, and `set_email` changes only the email
- [x] `backend/tests/integration/test_user_email_migration.py` - Alembic in a
  subprocess:
  - upgrade keeps existing users, with `email` NULL
  - downgrade removes the column and keeps users
  - there is a single head
- [x] `backend/tests/integration/test_seed_insert_only.py`:
  - a fresh seed inserts every row of the real content
  - changes to seed code do not reach existing rows, at all six levels
  - an admin edit survives a re-seed
  - a new exercise under an existing lesson is inserted
  - a deleted seeded row comes back (the documented consequence)
  - seeding twice does not move `updated_at`
- [x] `backend/tests/integration/test_seed_lesson_content.py` - the
  update-in-place test was rewritten in Implement to assert the new rule
- [x] `backend/tests/conftest.py` - the test app now mounts the admin router

### Acceptance Criteria Validation

- ✅ **No token → 401; non-admin → 403; admin → 200 with the email**:
  `TestAdminMe`
- ✅ **Removing an email revokes access on the next request, with no
  re-login**: `test_removing_the_email_revokes_on_the_next_request`
- ✅ **`ADMIN_EMAILS` unset or empty → 403 for everyone**:
  `test_empty_allow_list_admits_nobody`, plus the unit tests
- ✅ **`email_verified: false` stores no email and is never an admin**: the
  Google verifier unit tests plus `test_unverified_email_is_never_admin`
- ✅ **Apple sign-in stores no email**: tested at the service level. See
  Issues Found for the gap.
- ✅ **A returning user's changed email is updated at sign-in**:
  `test_returning_user_email_follows_the_latest_sign_in` and
  `test_email_changed_at_google_moves_admin_access`
- ✅ **Migration upgrades and downgrades on SQLite, with one head**:
  `test_user_email_migration.py`. It was also applied to the local `dev.db`
  (see Notes).
- ✅ **Empty DB + seed gives today's content**:
  `test_fresh_seed_inserts_every_row_of_the_real_content`, plus the existing
  seed content tests, which are unchanged and green
- ✅ **An admin edit + re-seed → the edit survives**:
  `test_an_admin_edit_survives_a_re_seed` and the rewritten skill-title test
- ✅ **Seeding twice → no changes, including the Audio Lab seed**:
  `test_seeding_twice_writes_nothing`, plus the existing
  `test_seed_local_audio.py::test_seeding_twice_changes_nothing`
- ✅ **A new exercise under an existing lesson is inserted on re-seed**:
  `test_a_new_exercise_under_an_existing_lesson_is_inserted`
- ✅ **Full suite green, lint clean, learner tests unchanged except the one
  rewritten seed test**: 640 passed

### Issues Found

- **Falsification check on the seed tests.** I ran
  `test_seed_insert_only.py` against the *old* upsert seed:
  - **2 of 6 failed**, as they should: "changes in seed code" and "admin edit
    survives". Those are the two that pin the new rule.
  - **"Seeding twice writes nothing" passes against the old code too.**
    SQLAlchemy skips assigning an unchanged value, so it is a regression
    guard, not proof of the change.
  - The other three also pass on both versions. They describe behaviour the
    two versions share: fresh insert, new-child insert, re-insert after
    delete.
- **The real `AppleTokenVerifier` has no unit test.** It returns no email by
  construction: it only ever builds `VerifiedIdentity(subject=...)`. The
  suite covers that only through the fake verifier. There were no Apple
  verifier tests before this bolt either; writing one needs a signed-JWT
  fixture, so I have left it as a follow-up.

### Notes

- **Local `dev.db` migrated to `a7d3c9e1f042`**, after a backup to
  `backend/dev.db.bak-20260922-115412`. Its one user has `email` NULL until
  the next Google sign-in.
- **The local backend is running again** against `dev.db` on port 8000:
  - `/health` is ok
  - `GET /api/v1/admin/me` with no token returns `401 missing_credentials`
- **Neon is still at `f4c2a81e7b56`.** Before this deploys:
  1. Run the migration on Neon.
  2. Set `ADMIN_EMAILS` on Vercel.

  Both need your go-ahead.
