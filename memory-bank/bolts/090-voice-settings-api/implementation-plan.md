---
stage: plan
bolt: 090-voice-settings-api
created: '2026-10-12T10:50:00Z'
---

## Implementation Plan: voice-settings-service

### Objective

Story 002 (FR-4) and story 003 (FR-5, the prefix rule). Admins read every
supported language's voices and speed, and save one language's.

### What the code says (checked before planning)

- **F1 Admin routers:** admin routers are an `APIRouter(prefix="/api/v1/admin",
  dependencies=[Depends(require_admin)])`, with an `_ctx` dependency that
  builds `AdminContext(email=...)` (`sound_routers.py`). Both the router
  and the test app in `tests/conftest.py` include them.
- **F2 Use cases:** use cases live in `app/application/*_use_cases.py`.
  They take the repository and the `AdminContext`, validate, flush, and
  log with `admin_write action=... entity=... id=... admin=...`.
  `get_db_session` commits when the request ends.
- **F3 Errors:**
  - `InvalidContentError(field, message)` gives 422 with
    `details.field`.
  - `ContentNotFoundError(message, entity=..., id=...)` gives 404 with
    `details`.
  - Both are mapped already in `error_handlers.py`.
- **F4 Language names:** a language's name is in `languages.name`
  (`LanguageModel`).

### Decisions

- **D1 Use cases:** `app/application/voice_use_cases.py` has:
  - `list_voice_settings(repo, names, *, configured)`, which returns
    `AdminVoiceSettings(configured, languages)`;
  - `update_voice_settings(repo, names, ctx, language, *, male_voice_id,
    female_voice_id, speed)`.

  `names` is a small read of `languages` (code to name). A language
  missing from that table is shown by its code.
- **D2 Checks**, in this order:
  1. The language must be in `SUPPORTED_VOICE_LANGUAGES`. Otherwise:
     `ContentNotFoundError("No voices for this language",
     entity="voice_settings", id=language)`, a 404.
  2. Speed must be 0–100. Otherwise: `InvalidContentError("speed",
     "Speed is a whole number from 0 to 100")`.
  3. Each voice ID is trimmed and must start with `{language}-`.
     Otherwise: `InvalidContentError("male_voice_id" or
     "female_voice_id", "That is not a voice for {name}")`.
  4. Each voice ID must be at most 80 characters, the column width.

  A non-whole speed such as `40.5` or `"40"` is refused by the request
  model (`StrictInt`), which gives the standard 422.
- **D3 `configured`:** the router reads it from a `voice_generation_configured()`
  dependency that returns `False` for now. Bolt 091 makes it read
  `ADDIS_API_KEY`, and tests can override it.
- **D4 Routes:** `app/infrastructure/api/voice_routers.py` has
  `admin_router`, with:
  - `GET /api/v1/admin/voice/settings`, which returns
    `AdminVoiceSettingsResponse {configured, languages: [AdminVoiceLanguage]}`;
  - `PUT /api/v1/admin/voice/settings/{language}`, whose body is
    `UpdateVoiceSettingsRequest {male_voice_id: str, female_voice_id: str,
    speed: StrictInt}` and which returns `AdminVoiceLanguage`.

  `AdminVoiceLanguage` has `language`, `language_name`, `male_voice_id`,
  `female_voice_id`, `speed`, `updated_by` and `updated_at`. The schemas
  are in `app/infrastructure/api/voice_schemas.py`.
- **D5 Wiring:** the router is included in `app/main.py` and in the
  `tests/conftest.py` app.
- **D6 Log:** a save logs `admin_write action=update entity=voice_settings
  id={language} admin={email}`, using `_log` from
  `admin_content_use_cases`.

### Deliverables

- `app/application/voice_use_cases.py`
- `app/infrastructure/api/voice_schemas.py`
- `app/infrastructure/api/voice_routers.py`
- `app/main.py` and `tests/conftest.py`, to include the router
- **Tests:**
  - `tests/integration/test_voice_settings_api.py`:
    - GET returns the defaults with names, `configured` false, and null
      `updated_*`;
    - PUT saves and returns, and GET then shows the new values with
      `updated_by`;
    - unsupported language gives 404;
    - speed 101 and -1 give 422 on `speed`;
    - speed 40.5 gives 422;
    - a wrong-language voice gives 422 on its field;
    - saving `am` leaves `om` unchanged;
    - the log line is written;
    - 401 without a session, 403 for a non-admin;
    - `configured` follows the dependency when it is overridden.
  - `tests/unit/test_voice_use_cases.py`: the check order and the name
    fallback, with an in-memory repository.

### Dependencies

- Bolt 089: the repository and domain, which are complete.

### Acceptance Criteria

- [ ] GET returns `am` then `om`, with names, defaults, `configured` and
  `updated_*`.
- [ ] PUT saves one language and returns it. A later GET shows it.
- [ ] 404 for a language without voices.
- [ ] 422 on `speed` outside 0–100, and on a voice of another language.
- [ ] Each save is logged.
- [ ] Admin-only: 401 without a session, 403 for a non-admin.
- [ ] ruff and mypy report no new errors, and pytest passes.

## Implement (2026-10-12T11:05:00Z)

- **`app/application/voice_use_cases.py`:**
  - `VoiceSettingsStore`, the protocol the use cases need;
  - `list_voice_settings` and `update_voice_settings`;
  - the checks, in order: language, then speed, then each voice's prefix
    and length;
  - the module's own `_log`, as `sound_use_cases.py` has.
- **`app/infrastructure/api/voice_schemas.py`:**
  `AdminVoiceLanguageResponse`, `AdminVoiceSettingsResponse`, and
  `UpdateVoiceSettingsRequest`, whose `speed` is a `StrictInt`.
- **`app/infrastructure/api/voice_routers.py`:**
  - `admin_router` (`/api/v1/admin/voice`, `require_admin`), with GET and
    PUT on `/settings`;
  - `voice_generation_configured()`, which returns false until bolt 091.
- **`voice_settings_repository.py`:** `language_names()`, one select of
  the supported languages' names from `languages`.
- **Wiring:** the router is included in `app/main.py` and the
  `tests/conftest.py` app. Both routes appear in the OpenAPI schema.

### Deviations

- The language names are read by the voice settings repository, not a
  separate read. It is one small select, and the use case's protocol
  stays in one place.
- `_log` is defined in the module, matching the other use case modules,
  instead of importing the private helper.

### Checks

- ruff check and ruff format pass on the touched files.
- mypy reports the same 4 errors as before this bolt, none in the new
  files.

## Test (2026-10-12T11:30:00Z)

- **`tests/integration/test_voice_settings_api.py` (17 tests):**
  - **Reading:**
    - defaults with names, `configured` false and null `updated_*`;
    - a language missing from `languages` shows its code;
    - `configured` follows the overridden dependency.
  - **Saving:**
    - a save is returned and read back, trimmed, with `updated_by`;
    - saving `am` leaves `om` on its defaults;
    - the `admin_write ... entity=voice_settings` log line.
  - **Refusing:**
    - `ti` gives 404 with details;
    - speeds -1 and 101 give 422 on `speed`;
    - 40.5 and "40" give 422;
    - wrong-language, bare-prefix and empty voices give 422 on their
      field;
    - nothing is saved when a request is refused.
  - **Access:** 401 without a session, 403 for a non-admin.
- **`tests/unit/test_voice_use_cases.py` (7 tests):**
  - the name fallback;
  - the check order: language, then speed, then the male voice, then the
    female voice;
  - a voice ID over 80 characters is refused;
  - a refused save stores nothing;
  - voices are trimmed and the admin recorded.

### Issues found and fixed

- **"A" before a vowel.** The message "That voice is not a {name} voice"
  read "not a Afaan Oromo voice". It is now "That is not a voice for
  {name}", in the code, the requirements, the unit brief and this plan.

### Results

- **Full suite:** 1761 passed.
- **ruff check and ruff format:** clean.
- **mypy (`app`):** the same 4 errors as before this bolt.
