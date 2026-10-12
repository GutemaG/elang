---
unit: 002-addis-voice-client
intent: 027-generated-voice-audio
unit_type: backend
default_bolt_type: simple-construction-bolt
phase: inception
status: complete
created: '2026-10-12T09:55:00Z'
updated: '2026-10-12T09:55:00Z'
---

# Unit Brief: Addis Voice Client

## Purpose

This unit is the one place where the backend talks to Addis AI. It
covers the key, the client and the read-only routes the Voices page
needs: the catalog and the credit.

## Scope

### In Scope
- **Settings:** `addis_api_key`, `addis_api_base_url` and
  `addis_timeout_seconds` in `app/config.py`, and `ADDIS_API_KEY=` in
  the env example.
- **`AddisVoiceClient`** in `app/infrastructure/external/`, with these
  methods:
  - `list_voices`
  - `usage`
  - `generate`
- **Retry policy and errors:** retries on 429 and 5xx, and typed
  exceptions defined in the domain.
- **Wiring:**
  - a FastAPI dependency that returns the client, or `None` when no key
    is set;
  - `configured` in the settings read (story 002) now reads that
    dependency.
- **Routes:**
  - `GET /api/v1/admin/voice/voices?language=` with a 10-minute cache per
    language;
  - `GET /api/v1/admin/voice/usage`.
- **Save check:** the catalog check on `PUT /admin/voice/settings`.

### Out of Scope
- The generate route (unit 003).
- Any admin UI.

---

## Assigned Requirements

| FR | Requirement | Priority |
|----|-------------|----------|
| FR-1 | Addis AI connection settings | Must |
| FR-2 | Addis AI client | Must |
| FR-5 | Catalog check on save | Must |
| FR-6 | Voice catalog | Must |
| FR-7 | Credit | Should |

---

## Stories

| Story ID | Title | Priority | Status |
|----------|-------|----------|--------|
| 004-addis-connection-settings | The server knows its Addis key and whether generation is set up | Must | Planned (bolt 091) |
| 005-addis-voice-client | One client for Addis voices, usage and generation | Must | Planned (bolt 091) |
| 006-voice-catalog | Admins can list a language's available voices | Must | Planned (bolt 092) |
| 007-addis-credit | Admins can see the remaining credit | Should | Planned (bolt 092) |

### 004-addis-connection-settings (FR-1)

**As the** owner, **I want** the Addis key kept in the server's
environment, **so that** it never leaks.

- [ ] `addis_api_key` defaults to `""`, and `ADDIS_API_KEY` sets it.
- [ ] `addis_api_base_url` defaults to `https://api.addisassistant.com`.
- [ ] `addis_timeout_seconds` defaults to 30.
- [ ] Generation counts as set up exactly when the key is not empty, so
  `GET /admin/voice/settings` returns `configured: true`.
- [ ] A test sets a fake key, runs the routes in this unit and checks
  that the key appears in no captured log record and no response body.
- [ ] `backend/.env` is not committed. Only the env example changes.

### 005-addis-voice-client (FR-2)

**As a** backend developer, **I want** a small typed client for Addis,
**so that** routes never deal with raw HTTP.

- [ ] Every request has the `x-api-key` header and uses the configured
  timeout. The client is built on `httpx.AsyncClient` and accepts an
  injected transport for tests.
- [ ] `list_voices("om")` calls `GET /api/v1/voice/voices?language=om`
  and returns its voices. Each has `id`, `name`, `descriptor`,
  `gender`, `style`, `preview_audio_url`, `is_available` and
  `sort_order`.
- [ ] `usage()` returns `balance`, `currency`, `formatted_balance`,
  `price_per_minute` and `max_characters`.
- [ ] `generate(text, voice_id, language, speed)` posts the text, the
  voice, the language, `output_format: "mp3_44100"`, `voice_settings:
  {"speed": speed}` and `client_request_id: "buna-{uuid4}"`. A new ID is
  made on every call.
- [ ] It returns the decoded bytes of `data.audio`, `duration_seconds`,
  `voice_name`, `character_count` and `usage.credits_remaining`.
- [ ] Without `data.audio`, it downloads `data.audio_url` once and
  returns those bytes. The URL itself never leaves the client.
- [ ] On 429 or 5xx it retries up to 3 more times, waiting 1, 2 and 4
  seconds, or `Retry-After` when that header is given. Tests patch the
  waits to 0.
- [ ] Errors are mapped to domain exceptions:
  - 401/403 → `VoiceNotConfigured`;
  - 402, or a credit or balance code → `VoiceCreditExhausted`;
  - `VOICE_LANGUAGE_MISMATCH` → `VoiceLanguageMismatch`;
  - `TEXT_*` → `VoiceTextRejected`;
  - 429 after retries → `VoiceRateLimited`;
  - 5xx after retries, or a broken body → `VoiceServiceFailed`;
  - a timeout → `VoiceServiceTimeout`.
  - Each exception keeps Addis's `code` for logging.
- [ ] There is a test for each mapping and for the `audio_url` fallback.
  None of the tests use the network.

### 006-voice-catalog (FR-6, FR-5 catalog check)

**As an** admin, **I want** to pick from the voices Addis offers now,
**so that** I never choose one that doesn't exist.

- [ ] `GET /api/v1/admin/voice/voices?language=om` returns `voices:
  [{id, name, descriptor, gender, style, preview_audio_url}]`. Only
  available voices are included, in `sort_order`.
- [ ] A second call within 10 minutes, on the same instance, makes no
  Addis call. A test with a fake client checks this.
- [ ] A missing or unsupported language gets 422 on `language`. No key
  gives 503 `VOICE_NOT_CONFIGURED`. An Addis failure gives 502
  `VOICE_SERVICE_FAILED`.
- [ ] With a key set, `PUT /admin/voice/settings/{language}` refuses a
  voice that is not in the cached catalog, or has the wrong gender, or
  is unavailable. It returns 422 on the field: "No available {gender}
  voice {id}".
- [ ] If the catalog can't be fetched, PUT still saves on the prefix
  rule and logs `voice_catalog_unchecked`.
- [ ] Both routes are admin-only.

### 007-addis-credit (FR-7)

**As an** admin, **I want** to see how much credit is left, **so that**
generation doesn't stop by surprise.

- [ ] `GET /api/v1/admin/voice/usage` returns `{balance, currency,
  formatted_balance, price_per_minute, max_characters}`.
- [ ] It is not cached.
- [ ] Its errors are as in story 006.
- [ ] It is admin-only.

---

## Dependencies

### Depends On
| Unit | Reason |
|------|--------|
| 001-voice-settings-service | The catalog check and `configured` extend its routes |

### Depended By
| Unit | Reason |
|------|--------|
| 003-voice-generation-api | Uses `generate` and the exceptions |
| 004-voices-admin-page | Uses the catalog and usage routes |

---

## Bolt Suggestions

| Bolt | Type | Stories | Objective |
|------|------|---------|-----------|
| 091-addis-voice-client | simple-construction-bolt | 004, 005 | Settings, client, retries and errors |
| 092-voice-catalog-and-usage | simple-construction-bolt | 006, 007 | Catalog and usage routes, and the catalog check on save |
