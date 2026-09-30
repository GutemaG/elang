---
stage: plan
bolt: 071-settings-store-backend
created: '2026-09-30T20:18:05Z'
---

## Implementation Plan: settings-store-backend

### Objective

Stories 007 (FR-8) and 008 (FR-9): account settings as one JSON column on
`users`, and app-wide configuration in an `app_config` table, each read
through a registry in code that gives every key its type and default. A
new setting becomes one registry line: no migration, no seed, no backfill.
Then the migration runs on production Neon (the owner's go-ahead, given
2026-09-30).

### What the code says (checked before planning)

- **F1: Migrations** are Alembic
  (`app/infrastructure/db/migrations/versions/`), head `b5e9d2c7a4f1`.
  **Neon is at that head too** (read-only `alembic current`, 2026-09-30).
- **F2: The `users` table** has `selected_language`, `daily_xp_target`,
  `notification_enabled`, `active_course_id` and `email`; the `User`
  aggregate lists its invariants, and `PATCH /api/v1/users/me`
  (`user_routers.py`) is the preferences path.
- **F3: The session check** (`routers.py`) returns the user as
  `SessionUserResponse` (`schemas.py`); the app already reads it on every
  launch.
- **F4: Both databases.** Tests and `dev.db` are SQLite, production is
  Neon Postgres; SQLAlchemy's `JSON` type maps to each (NFR-6).
- **F5: Production URL** is in `backend/.env copy`; it is read from the
  file into the command's environment and never printed.

### Decisions

- **D1: One migration** adds `users.settings` (`JSON`, not null, server
  default `'{}'`, so existing rows need no backfill) and creates
  `app_config` (`key` string primary key, `value` JSON not null,
  `updated_at` timestamp). Both are additive: the running backend ignores
  them, so the migration can go first and the code after. It has a
  `downgrade`.
- **D2: Registries** in the domain (`app/domain/settings.py`): a `Setting`
  is a key, a type (`bool`, `int`, `str`, or one of a fixed list) and a
  default. `ACCOUNT_SETTINGS` and `APP_CONFIG` are two registries. Each
  reads a stored map into every registered key (stored value if valid,
  else the default; stored keys no longer registered are dropped) and
  validates a partial update (an unknown key or a wrong type is refused,
  and nothing is saved).
- **D3: What goes in the registries now: nothing real.** Both start empty.
  No setting exists yet that needs them (Appearance stays on the phone,
  the intent's D3), and the intent keeps beans and the refill cost in
  code. Tests register their own keys. So `GET /api/v1/config` returns
  `{}` and the session check returns `"settings": {}` until the first
  real setting is added. The registry file says what may never go in
  `APP_CONFIG`: nothing secret, since the endpoint is public.
- **D4: Account settings.**
  - The `User` aggregate carries `settings` (the resolved map); the
    repository reads and writes the column.
  - `PATCH /api/v1/users/me/settings` takes a partial map, validates it
    against the registry, merges and saves, and returns the full map.
    Refusals are `422` in the existing error shape.
  - `SessionUserResponse` gains `settings`, the full map.
- **D5: App config.** An `AppConfigRepository` reads all rows;
  `GET /api/v1/config` (no sign-in) returns every registered key with its
  row's value or the default. A row with a value of the wrong type falls
  back to the default and is logged, so a bad hand edit can't break the
  app. Writing a row is by hand or script for now (the intent's open
  admin-screen question stays open).
- **D6: Production (Neon), after Test is approved:**
  1. Check Neon is still at `b5e9d2c7a4f1` and count `users` rows.
  2. `alembic upgrade head` against Neon, with the URL from `.env copy`.
  3. Check: `alembic current` is the new head; `users.settings` exists and
     every row reads `{}`; `app_config` exists and is empty; the user
     count is unchanged.
  **Nothing is seeded**: that is the point of the registries (the
  intent's D7). The new endpoints go live when the backend is next
  deployed (pushing to GitHub). Because the migration is additive, it is
  safe to run before that deploy, and it must be: the new code reads the
  column.
- **D7: Local.** `dev.db` is backed up (`dev.db.bak-<time>`) before
  `alembic upgrade head` runs on it.

### Out of scope

- The app reading settings and config (bolt 072).
- Moving the existing preference columns or the bean constants into the
  registries (the intent keeps them where they are).
- An admin screen for `app_config`.

### Tests

- Registry: resolving fills defaults, keeps valid stored values, drops
  unregistered keys, and treats a wrong-typed stored value as the
  default; validating refuses unknown keys, wrong types, bools passed as
  ints and values outside a fixed list.
- A key added to the registry is read for an existing account with no
  migration (story 007's last criterion).
- `PATCH /api/v1/users/me/settings`: merges; `422` on an unknown key or a
  wrong type with nothing saved; sign-in required.
- The session check includes `settings`.
- `GET /api/v1/config`: defaults with no rows; a written row changes the
  value; no sign-in needed; a bad row falls back to the default.
- The migration: upgrade and downgrade on a copy of `dev.db`; existing
  rows read `{}`. On Postgres, the migration uses only portable operations
  (`add_column` with a server default, `create_table`). The only Postgres
  check is D6 on Neon: `scripts/verify_postgres.py` needs an empty
  database and seeds it, so it must never point at Neon, and no other
  Postgres is available here.
- The whole backend suite, `ruff` and `mypy`.

---

## Implementation Notes

### What changed

- **`app/domain/settings.py`** (new): `Setting` (key, type `bool`/`int`/
  `str`, default, optional `choices`; a bad default or duplicate key fails
  at import) and `SettingsRegistry` (`resolve`, `invalid_keys`,
  `validate`). `ACCOUNT_SETTINGS` and `APP_CONFIG` are both empty (D3). The
  module header says how to add a setting and that nothing secret may go
  in `APP_CONFIG`.
  - A bool is not accepted as an int.
  - Refusals name every problem at once in plain words ("theme: expected
    one of system, light, dark", "reminder_hour: expected a whole number").
- **Domain**:
  - `InvalidSettingError` (`invalid_setting`, 422);
  - `User.settings`, the stored map (the resolved map is built where it
    is returned, not kept on the aggregate);
  - `UserRepository.set_settings` and an `AppConfigRepository` protocol.
- **Use cases**:
  - `update_account_settings` validates first, merges, saves, logs the
    keys and returns the resolved map;
  - `read_app_config` resolves the rows and logs any bad one.
- **Database**:
  - `UserModel.settings` (`JSON`, not null, default `{}`) and
    `AppConfigModel`;
  - `SqlAlchemyUserRepository.set_settings` assigns a new dict so the
    change is seen;
  - `SqlAlchemyAppConfigRepository.get_all`.
- **Migration `c8e1f4a7b2d5`** (after `b5e9d2c7a4f1`): `add_column` with
  server default `'{}'` and `create_table("app_config")`. The downgrade
  drops the table and uses batch mode to drop the column on SQLite.
- **API**:
  - `PATCH /api/v1/users/me/settings` (body: a JSON object) returns
    `{"settings": {...}}`;
  - `GET /api/v1/config` (`config_router`, no sign-in) returns
    `{"config": {...}}`;
  - `SessionUserResponse.settings`.
  - Both routers are registered in `main.py` and in the test app
    (`tests/conftest.py`).
- **Tests**: `FakeUserRepository.set_settings`. The single-head check
  moved from `test_image_choice_migration.py` to the new migration test,
  as each new head does.
- **Local**: `dev.db` backed up to `backend/dev.db.bak-20260930T203700Z`,
  then upgraded to `c8e1f4a7b2d5`. Its 1 user reads `{}`, and
  `app_config` is empty.

### Checks

- Backend suite: 1373 passed. `ruff check` and `ruff format --check`:
  clean.
- `mypy app`: 4 errors, all in files this bolt doesn't touch
  (`lesson/services.py`, `lesson_repositories.py`,
  `audio_link_checker.py`, `admin_routers.py`); none in the new or
  changed code.

### Not done yet

- Neon (D6) runs after Test is approved.

---

## Test Report

- **Backend suite** (`uv run pytest`): 1373 passed, 0 failed (+33 this
  bolt: 17 registry unit tests, 13 endpoint tests, 3 migration tests).
- **Targeted** (registry, settings endpoints, settings migration, user
  preferences, auth endpoints): 57 passed, 3 runs out of 3.
- **The app** (`flutter test --exclude-tags e2e`): 1792 passed. The extra
  `settings` field in the session check doesn't disturb its parsing.
- **`ruff`**: clean. **`mypy`**: the 4 errors noted above, none in this
  bolt's code.
- **Story 007**:
  - `users.settings` defaults to `{}`, existing rows need no backfill
    (migration test);
  - every registry key reads as its stored value or default, and dropped
    keys are ignored;
  - PATCH merges, and refuses with 422 while saving nothing;
  - the session check and PATCH return the full map;
  - a key added later reads for an existing account with no migration.
- **Story 008**:
  - no row reads as the default, and `GET /api/v1/config` needs no
    sign-in;
  - a written row changes the value with no code change;
  - a bad row falls back to the default;
  - the "nothing secret" rule is documented in the registry file.
- **Not tested here**: the migration on Postgres. It runs in the Neon step
  (D6), with checks before and after.

---

## Production (Neon), 2026-09-30

Run with the owner's go-ahead, after Test was approved. The URL was read
from `backend/.env copy` into the command's environment and never printed.

- **Before**: revision `b5e9d2c7a4f1`, 3 users, no `users.settings`, no
  `app_config`.
- **`alembic upgrade head`**: `b5e9d2c7a4f1 -> c8e1f4a7b2d5` in one
  transaction.
- **After**:
  - revision `c8e1f4a7b2d5 (head)`, 3 users (unchanged);
  - `users.settings` is `json`, not null, default `'{}'::json`, and all 3
    users read `{}`;
  - `app_config` exists with 0 rows.
- **Nothing was seeded**, by design (the intent's D7).
- **Still to do**: deploy the backend (push to GitHub), so the new
  endpoints and the session check's `settings` go live. The running
  backend is unaffected by the new column and table in the meantime.

