---
stage: plan
bolt: 092-voice-catalog-and-usage
created: '2026-10-12T12:30:00Z'
---

## Implementation Plan: addis-voice-client

### Objective

- **Story 006** (FR-6, and the catalog check of FR-5): admins list a
  language's available voices, and saving settings refuses a voice Addis
  doesn't offer.
- **Story 007** (FR-7): admins see the remaining Addis credit.

### What the code says (checked before planning)

- **F1 The client:** `AddisVoiceClient.list_voices` and `usage` exist,
  from bolt 091. `get_addis_voice_client()` returns None without a key.
  Its errors are mapped, for example 503 for `voice_not_configured` and
  502 for `voice_service_failed`.
- **F2 Saving settings:** `update_voice_settings` (bolt 090) checks the
  language, then the speed, then each voice's prefix and length.
- **F3 Application layer:** application modules already take
  infrastructure services through a parameter. For example,
  `admin_audio_use_cases.check_audio_link` takes the
  `AudioLinkChecker`.

### Decisions

- **D1 Catalog use cases** in `voice_use_cases.py`:
  - **`VoiceCatalogSource`:** a protocol with `list_voices(language)`.
  - **`VoiceCatalog`:** a per-process cache, language to (fetched at,
    voices). It has a 10-minute TTL and an injectable `clock`
    (`time.monotonic`), and a module-level instance lives in
    `voice_routers.py`. `available(source, language)` returns that
    language's voices with `is_available`, sorted by `sort_order`, then
    name. It calls Addis at most once per language per 10 minutes. A
    failed fetch is not cached.
  - **`list_voice_options(source, catalog, language)`:**
    - an unsupported language raises `InvalidContentError("language",
      "Generated voices are not available for {code}")`;
    - with no client, the router raises `VoiceNotConfiguredError(
      "Generated voices aren't set up on this server.")`.
  - **`get_voice_usage(source)`:** passes the usage through, with no
    cache.
- **D2 The catalog check on save.** `update_voice_settings` gets an
  optional `voices: Callable[[], Awaitable[list[AddisVoice]]] | None`.
  The router passes it when a client exists.
  - It runs after the prefix rule.
  - The male voice must be in the list with `gender == "male"`, and the
    female voice with `gender == "female"`. Otherwise:
    `InvalidContentError(field, "No available {male|female} voice
    {id}")`.
  - If the fetch raises a `VoiceServiceError`, the save goes ahead on the
    prefix rule alone, with a log line: `voice_catalog_unchecked
    language=.. code=..`. This covers Addis being down, rate limits and
    a refused key. Credit doesn't matter for listing.
  - With no client there is no check, the same as before.
- **D3 Routes** in `voice_routers.py`:
  - `GET /api/v1/admin/voice/voices?language=om` returns
    `AdminVoiceCatalogResponse {language, voices: [AdminVoiceOption
    {id, name, descriptor, gender, style, preview_audio_url}]}`.
    `language` is a required query parameter.
  - `GET /api/v1/admin/voice/usage` returns `AdminVoiceUsageResponse
    {balance, currency, formatted_balance, price_per_minute,
    max_characters}`.
  - A `_client` dependency wraps `get_addis_voice_client()` and raises
    `VoiceNotConfiguredError` when it is None. The settings PUT reads the
    optional client directly, so a server without a key can still save.
- **D4 Schemas** in `voice_schemas.py`.

### Deliverables

- `app/application/voice_use_cases.py`: the protocol, `VoiceCatalog`,
  `list_voice_options`, `get_voice_usage`, and the catalog check in
  `update_voice_settings`
- `app/infrastructure/api/voice_schemas.py`: the three response models
- `app/infrastructure/api/voice_routers.py`: the two GET routes, the
  shared catalog and the catalog check on PUT
- **Tests:**
  - `tests/unit/test_voice_catalog.py`:
    - the cache within the TTL, and expiry after it;
    - a failure is not cached;
    - each language is cached separately;
    - only available voices are kept, sorted.
  - `tests/unit/test_voice_use_cases.py`:
    - the catalog check passes, and fails on an unknown voice, the wrong
      gender or an unavailable voice;
    - the check is skipped and logged when the fetch fails;
    - the check is never reached when the prefix rule fails.
  - `tests/integration/test_voice_catalog_api.py`, with a fake client
    through `dependency_overrides`:
    - voices for `om`, available only and in order;
    - 422 for `ti` and for a missing language;
    - 503 without a key;
    - 502 when Addis fails;
    - two calls make one fetch;
    - usage is passed through;
    - PUT refuses a voice that isn't in the catalog, and saves when the
      catalog is down;
    - 401 and 403.

### Dependencies

- Bolt 091: the client, the errors and the dependency, all complete.

### Acceptance Criteria

- [ ] The voice list shows only available voices of the language, in
  Addis's order, with no more than one Addis call per language per 10
  minutes.
- [ ] Usage shows the balance, currency, formatted balance, price and
  character limit.
- [ ] 422 for an unsupported or missing language, 503 without a key and
  502 when Addis fails.
- [ ] With a key, PUT refuses an unknown voice, a voice of the wrong
  gender or an unavailable voice. If the catalog can't be reached, PUT
  saves on the prefix rule and logs `voice_catalog_unchecked`.
- [ ] Every route is admin-only.
- [ ] ruff and mypy report no new errors, and pytest passes.

## Implement (2026-10-12T12:45:00Z)

- **`app/application/voice_use_cases.py`:**
  - `VoiceSource`, a protocol with `list_voices` and `usage`.
  - `VoiceCatalog`, a per-process cache with a 10-minute TTL and an
    injectable clock. It keeps only available voices, sorted by
    `sort_order` and then name, and does not cache failures.
  - `list_voice_options`, which gives 422 on `language` for an
    unsupported code, and `get_voice_usage`.
  - `update_voice_settings` takes an optional `voices` callable. After
    the prefix rule, `_offered` checks the male voice, then the female
    voice, by (id, gender). A `VoiceServiceError` while fetching logs
    `voice_catalog_unchecked` and lets the save go ahead.
- **`app/infrastructure/api/voice_schemas.py`:** `AdminVoiceOption`,
  `AdminVoiceCatalogResponse` and `AdminVoiceUsageResponse`.
- **`app/infrastructure/api/voice_routers.py`:**
  - the module-level `voice_catalog`;
  - `_client`, which gives a 503 `voice_not_configured` without a key;
  - `GET /voices?language=` and `GET /usage`;
  - PUT `/settings/{language}` passes the catalog check when a client
    exists.

### Deviations

None.

### Checks

- ruff check and ruff format pass.
- mypy reports the same 4 errors as before this bolt.
- The existing voice settings tests still pass (28).

## Test (2026-10-12T13:10:00Z)

- **`tests/unit/test_voice_catalog.py`** (7 tests):
  - only available voices, ordered by `sort_order` and then name;
  - one fetch within 10 minutes, and another at 600 s;
  - each language cached on its own;
  - a failed fetch is not kept;
  - options refuse `ti` without asking Addis;
  - usage is passed through.
- **`tests/unit/test_voice_use_cases.py`** (6 new tests, 13 in total):
  - offered voices are saved;
  - an unknown voice, a female voice in the male slot, and a male voice
    in the female slot are each refused with their field and message,
    and nothing is saved;
  - when Addis is busy the save goes ahead and logs
    `voice_catalog_unchecked ... code=voice_rate_limited`;
  - the catalog is not asked when the prefix rule fails.
- **`tests/integration/test_voice_catalog_api.py`** (17 tests, fake
  Addis client through `dependency_overrides`, fresh cache per test):
  - **Voices:**
    - available voices in order, with every field;
    - two requests make one Addis call;
    - 422 for `ti` and for a missing `language`;
    - 503 `voice_not_configured` without a key;
    - 502 `voice_service_failed`.
  - **Usage:** the full response, 503 without a key, and 502.
  - **Saving:**
    - offered voices are saved;
    - an unknown, unavailable or wrong-gender voice gives 422 on its
      field;
    - when Addis is down the save goes ahead and is logged;
    - without a key, only the prefix rule is checked and Addis is never
      called.
  - **Access:** 401 and 403 on both routes.

### Issues found

None.

### Results

- **Full suite:** 1830 passed.
- **ruff check and ruff format:** clean.
- **mypy (`app`):** the same 4 errors as before this bolt.
