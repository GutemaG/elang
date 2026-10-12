---
stage: plan
bolt: 091-addis-voice-client
created: '2026-10-12T11:40:00Z'
---

## Implementation Plan: addis-voice-client

### Objective

- **Story 004 (FR-1):** the server reads its Addis AI key and knows
  whether generation is set up.
- **Story 005 (FR-2):** one typed client for Addis voices, usage and
  generation, with retries and plain domain errors. Its tests never touch
  the network.

### What the code says (checked before planning)

- **F1 Settings:** settings are fields on `Settings` in `app/config.py`
  (pydantic-settings, read from `.env`). Placeholders are documented in
  `backend/.env.example`. `.env*` is git-ignored, and only `.env.example`
  is tracked.
- **F2 External clients:** these live in `app/infrastructure/external/`.
  `AudioLinkChecker` takes an optional `httpx.AsyncBaseTransport` so
  tests can stub HTTP, and the router reaches it through an overridable
  dependency (`get_audio_link_checker`). `httpx>=0.28.1` is already a
  dependency.
- **F3 Errors:**
  - Admin errors subclass `AdminContentError`, in
    `app/domain/lesson/exceptions.py`. Their HTTP status comes from
    `_LESSON_STATUS_BY_EXCEPTION` in `error_handlers.py`, and `details`
    is sent to the client.
  - `error_code` values are lower snake case, for example
    `audio_storage_not_configured` (503).
- **F4 Configured flag:** `voice_generation_configured()` in
  `voice_routers.py` returns False for now (bolt 090).

### Decisions

- **D1 Settings:** add `addis_api_key: str = ""`,
  `addis_api_base_url: str = "https://api.addisassistant.com"` and
  `addis_timeout_seconds: float = 30.0`, with a comment in the R2 style:
  the key is server-side only and never sent to a browser. Add an empty
  `ADDIS_API_KEY=` block to `.env.example`. The real `.env` is not
  touched by code; the owner adds the key there.
- **D2 Voice exceptions** go in `app/domain/lesson/exceptions.py`, under
  a "Generated voices (intent 027)" section. They are mapped in
  `error_handlers.py` now, because bolts 092 and 093 both raise them.
  Codes follow the project's lower snake case, not the upper case
  written in FR-10, which only described their meaning.

  | Exception | Base | HTTP | `error_code` |
  |---|---|---|---|
  | `VoiceNotConfiguredError` | `AdminContentError` | 503 | `voice_not_configured` |
  | `VoiceCreditExhaustedError` | `AdminContentError` | 402 | `voice_credit_exhausted` |
  | `VoiceRateLimitedError` | `AdminContentError` | 429 | `voice_rate_limited` |
  | `VoiceServiceFailedError` | `AdminContentError` | 502 | `voice_service_failed` |
  | `VoiceServiceTimeoutError` | `AdminContentError` | 504 | `voice_service_timeout` |
  | `VoiceTextRejectedError` | `InvalidContentError` | 422 | field `text` |
  | `VoiceLanguageMismatchError` | `InvalidContentError` | 422 | field `voice_id` |

  Each has an `addis_code` attribute (Addis's own `error.code`, or None)
  for logs. It is never put in `details`, so it never reaches the
  client. Messages are ours, from the FR-10 table, never Addis's text.
- **D3 The client:** a new
  `app/infrastructure/external/addis_voice_client.py`.
  - **Construction:** `AddisVoiceClient(api_key, *, base_url, timeout,
    transport=None, sleep=asyncio.sleep)`. `sleep` is injected so tests
    don't wait.
  - **Frozen result types:**
    - `AddisVoice(id, name, descriptor, gender, style,
      preview_audio_url, is_available, sort_order)`;
    - `AddisUsage(balance, currency, formatted_balance,
      price_per_minute, max_characters)`;
    - `AddisClip(audio: bytes, duration_seconds, voice_id, voice_name,
      character_count, credits_remaining)`.
  - **Methods:**
    - `list_voices(language)` calls `GET /api/v1/voice/voices?language=`.
    - `usage()` calls `GET /api/v1/voice/usage`.
    - `generate(text, *, voice_id, language, speed)` calls
      `POST /api/v1/voice/generations` with `output_format:
      "mp3_44100"`, `voice_settings: {"speed": speed}` and
      `client_request_id: "buna-" + uuid4().hex`. The ID is new on every
      call, and the same ID is reused across retries of that call, so a
      retry never pays twice.
  - **Audio:**
    - `data.audio` is decoded from its `data:...;base64,` URL.
    - If that field is absent, the client does one GET of
      `data.audio_url`. The key is sent only when that host is
      `addisassistant.com` or one of its subdomains, because playback
      says it `requires_auth`.
    - The signed URL is never returned or logged.
  - **Retries:** on 429 or 5xx, up to 3 retries, waiting 1, 2 and 4
    seconds. A `Retry-After` header in seconds is used instead, capped at
    10. Timeouts and connection errors are retried the same way. Other
    4xx are not retried.
  - **Error mapping:**
    - 401/403 → `VoiceNotConfiguredError("The voice service refused
      this server's key")`;
    - 402, or a code containing `CREDIT`, `BALANCE` or `INSUFFICIENT` →
      `VoiceCreditExhaustedError`;
    - `VOICE_LANGUAGE_MISMATCH` → `VoiceLanguageMismatchError`;
    - `TEXT_*` → `VoiceTextRejectedError`;
    - 429 after retries → `VoiceRateLimitedError`;
    - 5xx after retries, other 4xx, a body that isn't JSON, or missing
      fields → `VoiceServiceFailedError`;
    - a timeout after retries → `VoiceServiceTimeoutError`.
- **D4 Dependencies in `voice_routers.py`:**
  - `get_addis_voice_client()` returns an `AddisVoiceClient` built from
    settings, or None when the key is empty. It can be overridden in
    tests.
  - `voice_generation_configured()` now returns
    `bool(get_settings().addis_api_key.strip())`.
- **D5 Logging:** the client logs only `addis_voice_retry status=...
  attempt=...` at INFO and nothing else. The key, text and URLs are
  never logged.

### Deliverables

- `app/config.py` and `backend/.env.example`
- `app/domain/lesson/exceptions.py` and `error_handlers.py`, for the
  seven exceptions and their statuses
- `app/infrastructure/external/addis_voice_client.py`
- `app/infrastructure/api/voice_routers.py`: the two dependencies
- **Tests:**
  - `tests/unit/test_addis_voice_client.py`, using `httpx.MockTransport`:
    - **Requests:** the voices are parsed and the header is sent; usage
      is parsed; generate posts the right body with a fresh request ID
      each call, and the same ID on a retry.
    - **Audio:** the data URL is decoded; the `audio_url` fallback is
      used when the data URL is missing.
    - **Retries:** 429 then 201 succeeds; `Retry-After` is honoured and
      capped; 500 four times fails; 400 is not retried; a timeout is
      retried and then mapped.
    - **Errors:** each mapping in D3, and invalid JSON.
    - **Key safety:** a key-leak check over captured logs and the text of
      every exception raised.
  - `tests/integration/test_voice_settings_api.py`: `configured` is true
    when `ADDIS_API_KEY` is set and false when it is blank.

### Dependencies

- Bolt 090: `voice_routers.py` and `configured`, which are complete.
- No new packages.

### Acceptance Criteria

- [ ] `ADDIS_API_KEY` sets `configured`. A blank key means not set up.
- [ ] The three client methods work against the shapes recorded in the
  requirements' Findings.
- [ ] Each generate call has its own `client_request_id`, kept across its
  retries.
- [ ] Retries follow the policy, and every failure is a typed voice
  error with our own message.
- [ ] The key never appears in a log record or an error message.
- [ ] No test uses the network.
- [ ] ruff and mypy report no new errors, and pytest passes.

## Implement (2026-10-12T11:55:00Z)

- **`app/config.py`:** adds `addis_api_key` (empty by default),
  `addis_api_base_url` and `addis_timeout_seconds` (30), with a comment
  that the key is server-side only.
- **`backend/.env.example`:** an empty `ADDIS_API_KEY=` with a short
  note.
- **`app/domain/lesson/exceptions.py`:** `VoiceServiceError`, which
  carries `addis_code` and not `details`, and six subclasses:
  - not configured;
  - credit exhausted;
  - rate limited;
  - service failed;
  - timeout;
  - text rejected and language mismatch, which subclass
    `InvalidContentError` with fields `text` and `voice_id`.
- **`error_handlers.py`:** maps those to 503, 402, 429, 502, 504 and 422.
- **`app/infrastructure/external/addis_voice_client.py`:**
  - `AddisVoiceClient`, with `list_voices`, `usage` and `generate`;
  - the frozen result types `AddisVoice`, `AddisUsage` and `AddisClip`;
  - `_send`, which retries on 429, 5xx, timeouts and dropped
    connections (waits 1, 2, 4 s, or `Retry-After` capped at 10 s);
  - `_refusal`, which maps every other answer;
  - data-URL decoding, and the one-shot `audio_url` download, which
    sends the key only to `*.addisassistant.com`.
  - Its only log line is `addis_voice_retry status=... attempt=...`.
- **`voice_routers.py`:** `voice_generation_configured()` now reads the
  key, and the new `get_addis_voice_client()` returns the client, or
  None without a key. Both can be overridden in tests.

### Deviations

- None from the plan.
- Note for testing: `Settings` reads `backend/.env`, so tests that expect
  "not configured" set the settings explicitly rather than relying on the
  developer's `.env`.

### Checks

- ruff check and ruff format pass.
- mypy reports the same 4 errors as before this bolt.

## Test (2026-10-12T12:25:00Z)

- **`tests/unit/test_addis_voice_client.py` (35 tests, all through
  `httpx.MockTransport`):**
  - **Reading:** voices are parsed and the key is sent; usage is parsed.
  - **Generation request:** the body has the voice, speed and output
    format; each call has a new `client_request_id`; a retry keeps the
    same ID.
  - **Audio:**
    - the inline data URL is decoded;
    - the `audio_url` fallback downloads once with the key;
    - the key is not sent to another host;
    - five unreadable shapes, and a body that isn't JSON, are failures.
  - **Retries:**
    - 429 waits 1 s;
    - `Retry-After` of 3 and 120 gives waits of 3 and 10;
    - still 429 after 3 retries is rate limited, after 4 requests;
    - 500 four times is a failure;
    - 400 is not retried;
    - a timeout is retried then reported, and timeout-then-success
      works;
    - a dropped connection is retried then a failure.
  - **Refusals:**
    - 10 refusals each map to their voice error, and none carries
      Addis's message;
    - the `field` of the text and voice errors;
    - `addis_code` is kept, with empty `details`.
  - **Secrecy:** the key, the text and the signed link are never logged
    or in an error, including httpx's own request log.
- **`tests/integration/test_voice_settings_api.py`, now 21 tests:**
  - `configured` is true with `ADDIS_API_KEY` set and false when it is
    blank or spaces;
  - the key never appears in the response;
  - `get_addis_voice_client()` returns None without a key;
  - the fixture pins `Settings(_env_file=None)`, so the developer's
    `.env` never changes the results.
- **Live check** with the owner's key, using only the free calls:
  - `list_voices` returns 19 Amharic and 9 Afaan Oromo voices;
    `am-yohanes-calm`, `am-loza`, `om-diriba` and `om-obse` are all
    available, and all are Narration;
  - `usage` returns Br 997.53 at 2.5 ETB per minute, with a 5000
    character limit;
  - a wrong key gives `VoiceNotConfiguredError` (`UNAUTHORIZED`).

### Issues found and fixed

- **The signed link reached the logs.** httpx logs each request's full
  URL at INFO, so the fallback download would have logged Addis's signed
  `?token=`. The client now adds a filter to the `httpx` logger that keeps
  the line but replaces the query with `?…`. A test covers it.

### Results

- **Full suite:** 1800 passed.
- **ruff check and ruff format:** clean.
- **mypy (`app`):** the same 4 errors as before this bolt.
