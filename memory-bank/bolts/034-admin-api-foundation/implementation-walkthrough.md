---
stage: implement
bolt: 034-admin-api-foundation
created: '2026-09-22T10:15:00Z'
---

## Implementation Walkthrough: content-admin-api

### Summary

Sign-in now keeps the Google-verified email on the user. A router-level
`require_admin` check lets only emails in `ADMIN_EMAILS` reach
`/api/v1/admin/*`; its first endpoint, `GET /api/v1/admin/me`, returns the
signed-in admin's email. The content seed is now insert-only, so the database
is the source of truth and a re-seed never overwrites an edit.

### Structure Overview

The email flows **provider → verifier → authentication service → user
repository**:
- Verifiers return a `VerifiedIdentity` (subject + optional email) instead of
  a bare subject.
- The authentication service stores the email on new users and rewrites it
  for returning users only when it changed. It does this through a dedicated
  repository method, so sign-in still writes no other user field.
- The admin rule is a pure domain function. The API applies it through one
  dependency on the admin router.

The seed loop keeps its shape: it looks each row up by its deterministic id,
inserts it if absent, and otherwise leaves it alone while still visiting its
children.

### Completed Work

**Admin identity and the admin check**
- [x] `backend/app/domain/value_objects.py` - new `VerifiedIdentity`, what a
  provider vouches for
- [x] `backend/app/domain/entities.py` - `User.email` (optional), plus a new
  invariant: authentication is its only writer, and it is only for the admin
  check
- [x] `backend/app/domain/repositories.py` - `UserRepository.set_email`,
  separate from `update`
- [x] `backend/app/domain/services.py` - `TokenVerifier` returns
  `VerifiedIdentity`; sign-in records the verified email on create and on
  change
- [x] `backend/app/domain/admin.py` - new: parses `ADMIN_EMAILS` and decides
  `is_admin`, failing closed
- [x] `backend/app/domain/exceptions.py` - new `NotAdminError`
  (`not_admin`)
- [x] `backend/app/infrastructure/external/google_verifier.py` - passes the
  email on only when `email_verified` is true
- [x] `backend/app/infrastructure/external/apple_verifier.py` - never passes
  an email

**Storage**
- [x] `backend/app/infrastructure/db/models.py` - nullable `users.email`
- [x] `backend/app/infrastructure/db/repositories.py` - maps `email`; new
  `set_email`
- [x] `backend/app/infrastructure/db/migrations/versions/a7d3c9e1f042_add_email_to_users.py` -
  new migration on `f4c2a81e7b56`, adding and dropping the column in batch
  mode

**API and configuration**
- [x] `backend/app/config.py` - `admin_emails` setting (`ADMIN_EMAILS`)
- [x] `backend/app/infrastructure/api/dependencies.py` - new `require_admin`,
  layered on `get_current_user`
- [x] `backend/app/infrastructure/api/error_handlers.py` - `NotAdminError` →
  403
- [x] `backend/app/infrastructure/api/admin_routers.py` - new admin router
  with `require_admin` at router level, and `GET /me`
- [x] `backend/app/infrastructure/api/admin_schemas.py` - new response schema
  for `/me`
- [x] `backend/app/main.py` - mounts the admin router
- [x] `backend/.env.example` - documents `ADMIN_EMAILS`

**Insert-only seeds**
- [x] `backend/app/infrastructure/db/seed_lesson_content.py` - `seed` and
  `seed_content` are insert-only; the docstrings state both consequences
- [x] `backend/app/infrastructure/db/seed_local_audio.py` - docstring states
  that it is insert-only too

**Tests changed to keep the suite honest**
- [x] `backend/tests/fakes.py` - `FakeTokenVerifier` takes an optional
  `email`; `FakeUserRepository.set_email`
- [x] `backend/tests/integration/test_seed_lesson_content.py` - the upsert
  test is rewritten to assert the new rule: a database edit survives a
  re-seed

**Decision record**
- [x] `memory-bank/bolts/034-admin-api-foundation/adr-16-admin-identity-verified-email.md` -
  ADR-16, indexed in `standards/decision-index.md`

### Key Decisions

- **`set_email` rather than `update`**: `update` writes every preference
  field. Using it on sign-in would break User invariant 2, which says no
  authentication path may write `daily_xp_target`.
- **The email is rewritten only when it changed**: this avoids a write on
  every sign-in. The email is set back to `None` if Google stops verifying it,
  so a lost verification also loses admin access.
- **Router-level dependency**: `require_admin` sits on the `APIRouter`
  itself, so no future admin endpoint can be added without it.
- **The seed builds new rows in one constructor**: this replaces "get or
  create, then assign every field", so there is no code path left that could
  write to an existing row.

### Deviations from Plan

None.

### Dependencies Added

None.

### Developer Notes

- **Suite status after this stage:** the full backend suite is green (594
  passed), with `ruff check` and `ruff format --check` clean. The migration
  upgrades and downgrades on SQLite, and there is a single head,
  `a7d3c9e1f042`.
- **Local `dev.db` needs the migration** before the local backend can serve
  the new code. The earlier background server has already stopped. Back up
  `dev.db` first, then run `alembic upgrade head`. This has not been done.
- **Neon is untouched.** The migration must run there before deploy, and that
  needs your go-ahead.
- **The R2 comments in `.env.example` are now out of date.** They say "never
  on Vercel", but bolt `036` will put the R2 keys on the backend. Correct them
  in `036`.
