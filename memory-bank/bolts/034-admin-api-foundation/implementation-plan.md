---
stage: plan
bolt: 034-admin-api-foundation
created: '2026-09-22T10:20:00Z'
---

## Implementation Plan: content-admin-api

### Objective

Only admins, meaning the Google-verified emails in `ADMIN_EMAILS`, can reach
`/api/v1/admin/*`, and no seed run can overwrite content any more. There is
no content endpoint yet beyond `GET /api/v1/admin/me`; that arrives in `035`.

### What the code showed (read before planning)

1. **The Google verifier returns only `sub`.** `TokenVerifier.verify()` returns a
   `str`, and `GoogleTokenVerifier` throws the rest of the claims away. The
   email is in the verified claims (`email`, `email_verified`); it just is
   not passed on.
2. **The admin site needs no new Google audience.** The Flutter app signs in
   with `serverClientId` = the web client id, which is the backend's
   `GOOGLE_OAUTH_CLIENT_ID` (`lib/shared/config/auth_config.dart`). A Google
   Identity Services button on the admin site uses that same web client id,
   so `GoogleTokenVerifier` stays single-audience. `system-context.md`
   finding 2 is resolved with no change.
3. **CORS needs no code.** `cors_allowed_origins` already takes extra origins,
   and local `http://localhost:<port>` is already allowed. The deployed admin
   origin is added to that variable on Vercel in bolt `037`.
4. **Admin edits already refresh offline packs.** `lessons.updated_at` and
   `exercises.updated_at` have `onupdate`, and they drive `content_version`
   (bolt 008). An admin edit will make the app refetch a downloaded lesson
   without any extra work.
5. **The seed upserts in one place.** `seed_content()` in
   `seed_lesson_content.py` is the only loop. All three seeds (lesson,
   course/category content appended to it, local audio) go through it.
   Exactly one existing test asserts the upsert:
   `test_seed_lesson_content.py::test_re_running_seed_after_editing_content_updates_in_place`.

### Deliverables

**Story 001-admin-authorization**
- `VerifiedIdentity` (`subject`, `email: str | None`), returned by
  `TokenVerifier.verify()` instead of a bare `str`:
  - **Google** sets `email` only when `email_verified` is true.
  - **Apple** always returns `email=None`, because private relay emails make
    Apple users never admins in v1.
- **`User.email: str | None`:** a new domain field and a nullable `users.email`
  column.
  - Migration on head `f4c2a81e7b56`, batch mode for SQLite.
  - Not unique, not indexed. The account key stays `(provider, sub)`;
    `ProviderIdentity`'s "never derived from email" rule holds.
- **`AuthenticationService._authenticate` writes the verified email** on every
  sign-in:
  - New users are created with it.
  - For a returning user, the email is updated only when it changed. It
    becomes `None` if Google stops vouching for it.
- `Settings.admin_emails` (`ADMIN_EMAILS`, comma-separated), plus a pure
  `is_admin(email, allow_list)`:
  - case-insensitive and whitespace-trimmed
  - an empty list means nobody is an admin
- `require_admin` dependency, layered on `get_current_user`:
  - `401` when there is no token or the token is invalid; this is the
    existing behaviour
  - `403` via a new `NotAdminError` when the user is not an admin
- New `app/infrastructure/api/admin_routers.py`:
  - `APIRouter(prefix="/api/v1/admin", dependencies=[Depends(require_admin)])`,
    so a future admin endpoint cannot forget the check
  - `GET /api/v1/admin/me` → `{"email": ...}`
  - mounted in `main.py`
- `.env.example`: `ADMIN_EMAILS=` with a comment. The locally modified,
  uncommitted `.env.example` (R2 lines) is kept as is; this adds one line to
  it.

**Story 002-seed-insert-only**
- `seed_content()` becomes insert-only:
  - A row that already exists (by uuid5 id) is left untouched.
  - The loop still descends into an existing skill or lesson, so a *new*
    lesson or exercise under an old parent is still inserted.
- Docstrings of `seed()`, `seed_content()` and `seed_local_audio.py` state the
  rule and its two consequences:
  - A seeded row an admin deletes comes back on the next seed run.
  - Changing an existing row in seed code no longer reaches a database that
    already has it. From now on, fix content in the admin tool, or reset a
    local `dev.db`.
- The update-in-place test is rewritten to the new rule: edit a row in the
  database, re-seed, and the edit survives. It is not deleted.

### Dependencies

- **Existing modules:** `get_current_user`, `SessionValidationService` and
  `AuthenticationService`. They are reused, not duplicated.
- **Packages:** none new.
- **Neon:** the migration must run there before this is deployed. Running it
  is an Operations step that needs your go-ahead; this bolt does not touch
  Neon.

### Technical Approach

- `VerifiedIdentity` lives in `app/domain/value_objects.py` next to
  `ProviderIdentity`. `tests/fakes.py`'s `FakeTokenVerifier` gains an optional
  `email`, so existing tests keep working unchanged.
- **The allow-list is read per request** from `get_settings()`. It is
  `lru_cache`d, so in production it changes when Vercel redeploys on an env
  change, which is what happens on Vercel anyway. Tests override settings.
  "Revoked on the next request" therefore holds per deployment, and the story
  criterion is tested by changing the setting between two requests.
- **Error mapping:** `NotAdminError` goes into the domain exceptions, mapped
  to `403` in `error_handlers.py` in the existing JSON error shape.
- **Your account:** your existing account has `email = NULL` until your next
  Google sign-in. Signing in to the admin site (bolt `037`) calls
  `/auth/google`, which fills it in, so nothing needs a manual step.
- **A side effect to accept:** a Google user who has never used the app and
  signs in to the admin site gets a normal learner account, created with the
  default onboarding choices. That is harmless, and it is the same account
  they would get in the app.
- **Out of this bolt:** the audit log line is story `003`'s criterion and
  lands in `035` with the first write endpoint.

### ADR

**ADR-16 — Admin identity: store the Google-verified email on `users`.**
- **Alternatives rejected:**
  - **An allow-list of Google `sub` ids:** you cannot see a sub, so it is
    unusable by hand.
  - **A separate admin-sessions table:** a second auth system.
  - **Checking the email only at sign-in and baking it into the session:**
    revocation would wait for session expiry, up to 30 days.
- **Consequence:** the backend now stores an email address, the first
  personal data beyond the provider id. It is used only for the admin check.

### Acceptance Criteria

- [ ] No token → `401` on `GET /api/v1/admin/me`; a non-admin → `403`; an admin → `200` with the email
- [ ] Removing an email from `ADMIN_EMAILS` → the next request is `403`, with no re-login
- [ ] `ADMIN_EMAILS` unset or empty → `403` for everyone
- [ ] A Google token with `email_verified: false` stores no email and is never an admin
- [ ] An Apple sign-in stores no email
- [ ] A returning Google user's changed email is updated at sign-in
- [ ] The migration upgrades and downgrades cleanly on SQLite; `alembic heads` shows one head
- [ ] An empty DB + seed gives today's content, with the same ids and counts as before
- [ ] An admin-style edit in the DB + re-seed → the edit survives
- [ ] Seeding twice → no changes, including the local Audio Lab seed
- [ ] A new exercise added to seed code under an existing lesson is inserted on re-seed
- [ ] The full backend suite is green and `ruff check` / `ruff format --check` are clean; learner endpoint tests are unchanged apart from the one rewritten seed test
