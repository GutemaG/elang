---
stage: plan
bolt: 093-voice-generate-api
created: '2026-10-12T13:15:00Z'
---

## Implementation Plan: voice-generation-api

### Objective

This bolt covers stories 008–011 (FR-8 to FR-11).
`POST /api/v1/admin/voice/generate` turns a text into an mp3 take for the
admin to check. The voice and speed come from the language's settings
unless they are overridden. Bad text is refused before any money is
spent, every failure has a plain message, and each generation is logged
without its text. Nothing is stored on our side.

### What the code says (checked before planning)

- **F1 Client:** `AddisVoiceClient.generate(text, voice_id=, language=,
  speed=)` returns an `AddisClip` (bolt 091).
  - It raises `VoiceServiceError` subclasses: not configured, credit,
    rate limit, failed, timeout.
  - It also raises two `InvalidContentError` subclasses:
    `VoiceTextRejectedError` and `VoiceLanguageMismatchError`.
- **F2 Settings:** `SqlAlchemyVoiceSettingsRepository.get(language)` and
  `language_names()` exist. The prefix rule `_voice()` is in
  `voice_use_cases.py`.
- **F3 Lesson language:**
  `SqlAlchemyAdminContentRepository.learning_language_of_lesson(lesson_id)`
  returns the course language, or None. Exercises use it.
  - Workbook items are curriculum rows, not `lessons`, so the Workbook
    passes `language` instead.
- **F4 CORS:** `main.py` sets up `CORSMiddleware` with no
  `expose_headers`. A browser can't read custom response headers until
  they are exposed.

### Decisions

- **D1 Request** (`GenerateVoiceRequest` in `voice_schemas.py`):
  - `text: str`;
  - `gender: Literal["male", "female"]`;
  - `language: str | None`;
  - `lesson_id: str | None`;
  - `speed: StrictInt | None`;
  - `voice_id: str | None`.
- **D2 Use case** `generate_voice(settings, lessons, source, ctx, ...)` in
  `voice_use_cases.py` runs these checks in order. All of them happen
  before Addis is called.
  1. **Language or lesson:** exactly one of `language` or `lesson_id`.
     Otherwise `InvalidContentError("language", "Give a language or a
     lesson, not both")`. With neither: "Give a language or a lesson".
  2. **Lesson lookup:** a `lesson_id` resolves through
     `learning_language_of_lesson`. If there is none:
     `ContentNotFoundError("No such lesson", entity="lesson", id=...)`.
  3. **Supported language:** the language must be supported. Otherwise
     `InvalidContentError("language", "Generated voices are not
     available for {name}")`, where the name falls back to the code.
  4. **Text:** it is trimmed. Empty gives "Type the words to say", and
     over 500 characters (`MAX_GENERATE_CHARS`) gives "Up to 500
     characters: a word, a phrase or a sentence". Both are on field
     `text`.
  5. **Speed:** if given, it must be 0–100, or the error is on `speed`.
     If not given, the language's saved speed is used.
  6. **Voice:** `voice_id`, if given, passes `_voice()`. If not given,
     the voice is the language's saved one for `gender`.
  7. **Client:** if there is none, `VoiceNotConfiguredError("Generated
     voices aren't set up on this server.")`. The source is checked
     last, so input mistakes are reported even on a server without a
     key.
- **D3 Calling Addis** with `source.generate(...)`:
  - `VoiceLanguageMismatchError` is raised again with our message,
    "That voice doesn't speak {name}".
  - Every voice error, of both families, logs `admin_voice_failed
    code={error_code} addis_code={code or -} admin={email}` and is then
    raised again.
  - A success logs `admin_write action=generate entity=voice
    language={code} voice={id} chars={n} seconds={s:.2f} admin={email}`.
  - The text is never logged.
- **D4 Route:** `POST /api/v1/admin/voice/generate` in
  `voice_routers.py` returns a raw `Response`:
  - status 200, `media_type="audio/mpeg"`, body `clip.audio`;
  - headers:
    - `X-Voice-Id`;
    - `X-Voice-Name`, percent-encoded with `urllib.parse.quote`;
    - `X-Duration-Seconds`;
    - `X-Credits-Remaining`, or an empty string when unknown;
    - `Cache-Control: no-store`.
  - It uses the optional client dependency, so no key gives a 503
    through D2.7.
- **D5 CORS:** `expose_headers=["X-Voice-Id", "X-Voice-Name",
  "X-Duration-Seconds", "X-Credits-Remaining"]` in `main.py`, as a
  module constant `VOICE_HEADERS` in `voice_routers.py`.
- **D6 Status codes:** these are already mapped in bolt 091 (FR-10).
  This bolt adds tests for each one through the route.

### Deliverables

- `app/application/voice_use_cases.py`: `MAX_GENERATE_CHARS`, the
  `VoiceGenerator` and `LessonLanguages` protocols, `GeneratedVoice` and
  `generate_voice`
- `app/infrastructure/api/voice_schemas.py`: `GenerateVoiceRequest`
- `app/infrastructure/api/voice_routers.py`: the route and
  `VOICE_HEADERS`
- `app/main.py`: `expose_headers`
- **Tests:**
  - `tests/unit/test_voice_generate.py`: the order of the checks, how the
    voice and speed are resolved, overrides, the lesson language, the
    500-character boundary, "…" sent as typed, the mismatch rewording
    and the log lines.
  - `tests/integration/test_voice_generate_api.py`, with a fake client
    and a storage-free app:
    - 200 with mp3 bytes and the headers, which a CORS preflight and the
      response expose;
    - `lesson_id` resolution, and 404 for an unknown lesson;
    - each FR-10 row: 503 without a key or with a refused key, 402,
      429, 502, 504, and 422 for text, voice and language;
    - Addis's message, the key and the text never appear in any response
      or log;
    - 401 and 403.

### Dependencies

- Bolts 089–092, all complete.

### Acceptance Criteria

- [ ] A body of `{language: "om", text: "Maqaan koo Saaraa dha.", gender:
  "female"}` returns 200 `audio/mpeg` from `om-obse` at the saved speed,
  with the four `X-` headers readable from the admin origin.
- [ ] `lesson_id` uses the lesson's course language. An unknown lesson
  gives 404.
- [ ] Empty text, text over 500 characters, a bad speed, a bad voice or
  an unsupported language each give 422 before Addis is called.
- [ ] Each FR-10 failure has its status, code and our message.
- [ ] Successes and failures are logged without the text. Nothing is
  stored.
- [ ] The route is admin-only.
- [ ] ruff and mypy report no new errors, and pytest passes.

## Implement (2026-10-12T13:35:00Z)

- **`app/application/voice_use_cases.py`:**
  - `MAX_GENERATE_CHARS = 500`.
  - The protocols `VoiceGenerator` and `LessonLanguages`.
  - `GeneratedVoice`, which holds the clip, the language and the voice
    used.
  - `generate_voice` runs the D2 checks in order (language or lesson,
    the lesson lookup, a supported language, text, speed, voice, and
    finally the client), then calls Addis.
  - A mismatch is raised again as "That voice doesn't speak {name}".
  - Both error families log `admin_voice_failed`, and a success logs
    `admin_write action=generate entity=voice ...`. Neither line
    includes the text.
- **`app/infrastructure/api/voice_schemas.py`:** `GenerateVoiceRequest`,
  with `gender` as `Literal["male", "female"]`.
- **`app/infrastructure/api/voice_routers.py`:**
  - `VOICE_HEADERS`.
  - `POST /generate` returns the mp3 bytes with the four `X-` headers
    and `Cache-Control: no-store`. The voice name is percent-encoded.
    Lessons are looked up through `SqlAlchemyAdminContentRepository` on
    the same request session.
- **`app/main.py`:** `CORSMiddleware` gets `expose_headers=VOICE_HEADERS`.

### Deviations

None.

### Checks

- ruff check and ruff format pass.
- mypy reports the same 4 errors as before this bolt.
- The existing voice and CORS tests pass (64).

## Test (2026-10-12T14:10:00Z)

- **`tests/unit/test_voice_generate.py`** (23 tests):
  - **Voice and speed:** the saved voice for each gender and the saved
    speed; the defaults for a language never saved; one-take overrides
    of speed and voice; a lesson's course language.
  - **Text:** trimmed, "…" sent as typed, and exactly 500 characters
    allowed.
  - **Refusals before Addis is called:** 9 cases with their field and
    message; an unknown lesson; a lesson in English; input still checked
    without a key, which then gives 503.
  - **Addis errors:** the mismatch is reworded with the language name;
    credit and text refusals pass through and are logged.
  - **Log:** the success line, without the text.
- **`tests/integration/test_voice_generate_api.py`** (16 tests, fake
  Addis):
  - **The take:**
    - the mp3 body with `audio/mpeg`, the four `X-` headers and
      `no-store`;
    - saved settings are used, and a two-word name is percent-encoded;
    - Try it overrides;
    - `lesson_id` gives Amharic;
    - nothing is stored.
  - **Refusals:** 7 free refusals (422 or 404) that never call Addis; a
    malformed body (gender, 40.5 speed, missing text).
  - **Addis failures:** each status code (503, 402, 429, 502, 504, 422)
    with our message; the mismatch names the language; no key gives 503.
  - **Leaks:** the key, the text and Addis's code never reach a
    response, and the text never reaches the logs.
  - **Access:** 401 and 403.
- **`tests/unit/test_cors_origins.py`** (+1): the admin origin can read
  the four `X-` headers.
- **Live check:** one real generation through `AddisVoiceClient`. It
  returned "Maqaan koo Saaraa dha." as Obse, 1.96 s, 19,793 bytes of mp3
  (`\xff\xfb` frame), with 997.45 ETB left. The clip is saved to
  `Downloads\addis-samples\client_smoke_om_obse.mp3`.

### Issues found

None.

### Results

- **Full suite:** 1880 passed.
- **ruff check and ruff format:** clean.
- **mypy (`app`):** the same 4 errors as before this bolt.
