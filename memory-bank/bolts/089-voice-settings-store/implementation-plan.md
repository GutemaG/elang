---
stage: plan
bolt: 089-voice-settings-store
created: '2026-10-12T10:05:00Z'
---

## Implementation Plan: voice-settings-service

### Objective

Story 001 (FR-3). Each language that Addis AI speaks (`am`, `om`) has a
male voice, a female voice and a speed. They are stored in a new
`voice_settings` table. When a language has no row, the owner's
defaults are used.

### What the code says (checked before planning)

- **F1 Domain modules:** domain modules (`app/domain/sounds.py`,
  `curriculum.py`) hold constants and frozen dataclasses with no
  SQLAlchemy.
- **F2 Models:** models live one file per area
  (`app/infrastructure/db/sound_models.py`) on `models.Base`.
  `migrations/env.py` imports each models module so autogenerate sees
  it.
- **F3 Repositories:** each repository is a small class over an
  `AsyncSession`, for example `SqlAlchemySoundRepository` with `get`,
  `add` and `flush`. The use case commits, not the repository.
- **F4 Migrations:**
  - The Alembic head is `e2c7a9d4b6f3`.
  - Migrations are written by hand, with a comment naming the intent and
    bolt.
  - Migration tests run Alembic in a subprocess against a throwaway
    SQLite file, using `_ok` from `test_courses_migration.py`, as in
    `test_feedback_migration.py`.
- **F5 Test schema:** test databases are built with
  `Base.metadata.create_all` (`tests/conftest.py`), so a new model
  appears there once its module is imported.

### Decisions

- **D1 Domain module:** a new `app/domain/voices.py` holds:
  - `SUPPORTED_VOICE_LANGUAGES = ("am", "om")`;
  - `SPEED_MIN = 0`, `SPEED_MAX = 100` and `DEFAULT_SPEED = 50`;
  - `DEFAULT_VOICES`, which maps each language to its (male, female)
    voice IDs:
    - `am`: (`am-yohanes-calm`, `am-loza`)
    - `om`: (`om-diriba`, `om-obse`)
  - a frozen dataclass `VoiceSettings(language, male_voice_id,
    female_voice_id, speed, updated_by, updated_at)`;
  - `default_voice_settings(language)`, which returns it with
    `updated_by` and `updated_at` set to None.
- **D2 No foreign key:** `voice_settings.language` has no foreign key to
  `languages`. These are Addis language codes, and a save must not fail
  on a database whose `languages` table lacks `om`. The route in bolt
  090 checks the code against `SUPPORTED_VOICE_LANGUAGES`.
- **D3 Table:** a new `app/infrastructure/db/voice_models.py` with
  `VoiceSettingsModel` on table `voice_settings`:

  | Column | Type | Notes |
  |---|---|---|
  | `language` | String(8) | Primary key |
  | `male_voice_id` | String(80) | Not null |
  | `female_voice_id` | String(80) | Not null |
  | `speed` | Integer | Not null, with `CheckConstraint("speed BETWEEN 0 AND 100", name="ck_voice_settings_speed")` |
  | `updated_by` | String(320) | Nullable |
  | `updated_at` | DateTime(timezone=True) | Nullable |

  It is imported in `migrations/env.py`.
- **D4 Repository:** a new
  `app/infrastructure/db/voice_settings_repository.py` with
  `SqlAlchemyVoiceSettingsRepository`. It returns domain objects, never
  models:
  - `get(language)` returns the stored row, or the defaults when there is
    none;
  - `list()` returns `get` for each supported language, in order, using
    a single select;
  - `save(language, *, male_voice_id, female_voice_id, speed, admin)`
    inserts or updates the row, sets `updated_at` to now (UTC), flushes
    and returns the saved settings.

  It does no validation, because that belongs to bolt 090's use case.
  The database check constraint stops a speed outside 0–100 regardless.
- **D5 Migration:** `a3f7c2e9b1d4_create_voice_settings.py`, revising
  `e2c7a9d4b6f3`. It creates the table, and the downgrade drops it. No
  rows are inserted (FR-3: the defaults live in code).

### Deliverables

- `app/domain/voices.py`
- `app/infrastructure/db/voice_models.py`, and the import in
  `migrations/env.py`
- `app/infrastructure/db/voice_settings_repository.py`
- `migrations/versions/a3f7c2e9b1d4_create_voice_settings.py`
- **Tests:**
  - `tests/unit/test_voice_settings_domain.py`: the defaults and the
    supported languages;
  - `tests/integration/test_voice_settings_repository.py`: defaults when
    empty, insert then update, `list` order, one language untouched by
    another's save, and the speed check constraint;
  - `tests/integration/test_voice_settings_migration.py`: the upgrade
    adds an empty table and the downgrade removes it.

### Dependencies

- None. The routes and `configured` come in bolt 090.

### Acceptance Criteria

- [ ] The defaults are `am` (`am-yohanes-calm` / `am-loza` / 50) and
  `om` (`om-diriba` / `om-obse` / 50).
- [ ] With no row, `get` returns the defaults, with null `updated_by` and
  `updated_at`.
- [ ] `save` inserts the first time and updates after that, and `get`
  then returns the stored values.
- [ ] `list()` returns `am` then `om`.
- [ ] A speed outside 0–100 is refused by the database.
- [ ] The migration upgrades and downgrades on SQLite. It creates a
  table only, so it is safe for Postgres.
- [ ] ruff and mypy report no new errors, and the whole pytest suite
  passes.

## Implement (2026-10-12T10:15:00Z)

- `app/domain/voices.py`: the supported languages, the speed range and
  default, `DEFAULT_VOICES`, `VoiceSettings` and `default_voice_settings`.
- `app/infrastructure/db/voice_models.py`: `VoiceSettingsModel` on
  `voice_settings`, with `ck_voice_settings_speed`.
- `app/infrastructure/db/voice_settings_repository.py`:
  `SqlAlchemyVoiceSettingsRepository`, with `get`, `list_all` (one
  select) and `save` (upsert, then flush).
- `migrations/versions/a3f7c2e9b1d4_create_voice_settings.py`: creates
  and drops the table. It is the new head.
- `voice_models` is imported in `migrations/env.py` and
  `tests/conftest.py`, so Alembic and the test schema see the table.

### Deviations

- **`list()` is named `list_all()`.** A method called `list` hides the
  builtin inside the class, which makes the `list[VoiceSettings]` return
  type ambiguous to mypy.

### Checks

- ruff check and ruff format pass on the touched files.
- mypy reports no issues in the new modules.
- `alembic heads` is `a3f7c2e9b1d4`.

## Test (2026-10-12T10:40:00Z)

- `tests/unit/test_voice_settings_domain.py` (6 tests):
  - supported languages and their order;
  - the speed scale;
  - the owner's default voices;
  - defaults have no `updated_*`;
  - each default voice belongs to its language;
  - an unsupported language has no defaults.
- `tests/integration/test_voice_settings_repository.py` (9 tests):
  - defaults while there is no row;
  - the first save inserts;
  - a later save updates the same row;
  - one language's save leaves the other alone;
  - `list_all` is `am` then `om` in one SQL statement;
  - the table refuses speeds -1 and 101;
  - speeds 0 and 100 are allowed.
- `tests/integration/test_voice_settings_migration.py` (4 tests):
  - a single head, `a3f7c2e9b1d4`;
  - the upgrade adds an empty table;
  - the migrated table refuses speed 101;
  - the downgrade removes the table and keeps the curriculum tables.

### Issues found and fixed

- **Timestamps without a zone.** SQLite returns `updated_at` without a
  zone, so a reread no longer equalled the saved value. The repository
  now normalises it to UTC (`_utc`), as `league_repository.py` and
  `admin_learner_repository.py` do.
- **The single-head check failed.** `test_there_is_a_single_head` still
  expected `e2c7a9d4b6f3`. Like earlier bolts, the check moves to the
  newest migration's test: it is removed from
  `test_curriculum_publish_migration.py` and added to
  `test_voice_settings_migration.py`.

### Results

- **Full suite:** 1736 passed and 1 failed (the head check above). After
  the move, the 4 affected files pass (20 tests).
- **ruff check and ruff format:** clean.
- **mypy:** 4 errors, all from before this bolt, in `services.py`,
  `lesson_repositories.py`, `audio_link_checker.py` and
  `admin_routers.py`. None are in the new files.
