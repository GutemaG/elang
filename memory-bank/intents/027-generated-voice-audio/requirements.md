---
intent: 027-generated-voice-audio
phase: inception
status: complete
created: '2026-10-12T09:30:00Z'
updated: '2026-10-12T09:50:00Z'
---

# Requirements: Generated voice audio in the admin

## Intent Overview

Every clip in the admin comes from the admin's own voice: recorded in the
browser or uploaded as a file (a pasted link is the third way). Many
Workbook items, exercises and letters stay without audio for want of a
speaker. Lesson S1-U02-L1 is an example: W014–W016 and S004 have none.

Addis AI (addisassistant.com) turns Amharic and Afaan Oromo text into
speech. A new **Generate** tab sits beside Record, Upload and Link in
every clip field. It works in four steps:

1. The admin picks Male or Female, and can change the speed.
2. The server asks Addis AI for the clip.
3. The clip opens in the same clip editor recordings use. Silence is cut
   automatically, and the cut can be moved by hand, so a 5-second clip
   whose speech ends at 2 seconds is kept as about 2.
4. "Use this clip" stores it exactly as an uploaded file is stored.

Which voice each language uses, and its default speed, are admin
settings on a new **Voices** page, not code.

## Findings from the Addis AI API (tested 2026-10-12)

| Topic | What we saw |
|---|---|
| Auth | Header `x-api-key: sk_...`. A wrong key gives 401 `{"error":{"code":"UNAUTHORIZED",...}}`. |
| Voices | `GET /api/v1/voice/voices?language=am` lists 19 voices and `language=om` lists 9. Each has `id`, `name`, `descriptor`, `gender`, `style`, `preview_audio_url` (public CDN mp3), `is_default` and `is_available`. |
| Generation | `POST /api/v1/voice/generations` with `text`, `voice_id`, `language`, `output_format: "mp3_44100"`, `client_request_id` and `voice_settings: {speed}` returns 201. |
| `client_request_id` | **Required** for paid generation: without it Addis returns 422 `CLIENT_REQUEST_ID_REQUIRED`. The docs call it optional. Reusing an ID replays the earlier clip. |
| Audio in the response | `data.audio` is a `data:audio/mpeg;base64,...` URL. `data.audio_url` is a signed CDN link that expires within an hour. We also get `duration_seconds`, `character_count`, `voice_name` and `usage.credits_remaining`. |
| Speed | Read from `voice_settings.speed` (0–100, default 50). A value above 100 is treated as 100. A top-level `speed` field is ignored. The effect is small next to the variation between takes, because Addis samples with temperature 0.8. |
| Silence | Addis applies `trim_silence: false`, so clips can carry silence before and after the speech. |
| Errors | Empty text gives 422 `TEXT_REQUIRED` (field `text`). A voice of another language gives 422 `VOICE_LANGUAGE_MISMATCH` (field `voice_id`). |
| Usage | `GET /api/v1/voice/usage` returns `data.balance`, `data.currency` ("ETB"), `data.formatted_balance` ("Br 997.53"), `data.pricing.price_per_minute` (2.5 ETB at the time) and `data.max_tts_characters` (5000). |
| Cost | A 3-second clip costs about 0.13 ETB. |

## Business Goals

| Goal | Success Metric | Priority |
|------|----------------|----------|
| Fill audio gaps without a speaker | From a Workbook item with no clip to a saved generated clip in under a minute, with 4 clicks or fewer after the text is right | Must |
| A consistent voice per language and gender | Every generated clip uses that language's set male or female voice, unless an admin tries another on the Voices page | Must |
| Voices and speed are admin settings | Changing a voice or the speed takes effect on the next generation, with no deploy | Must |
| Generated clips are as tidy as recordings | Silence before and after the speech is cut before the clip is stored, unless the admin keeps the clip as generated | Must |
| Cost stays visible | The Voices page shows the remaining Addis credit | Should |
| Generated clips are recognisable | A generated clip says so, and names its voice | Could |

## Scope

In scope:

- **Backend:**
  - Addis AI client: key, base URL, timeouts and retries.
  - Voice settings: table, migration and admin API.
  - Admin routes for the voice catalog, credit and generation.
- **Admin:**
  - The Voices page: settings per language, previews, "Try it" and
    credit.
  - The Generate tab in `AudioField`: in exercises, Workbook items and
    the Sounds chart's letters and example words.
- **Could:** a "Generated · {voice}" label on clips that were generated.

Out of scope:

- Generating audio in the learner app. Learners only hear stored clips.
- Bulk generation, for a whole lesson in one press. That could be a later
  intent.
- Addis speech-to-text, translation, chat and realtime.
- Languages other than Amharic (`am`) and Afaan Oromo (`om`). Elsewhere
  the Generate tab says it is not available.
- Changes to how clips are stored (R2 or local), checked or played, or to
  the clip editor's existing behaviour.
- Deleting clips from Addis's own storage after they are fetched.
- Slowing a clip down inside the clip editor (time-stretch). See the
  Assumptions table.

---

## Functional Requirements

### Backend: connection

#### FR-1: Addis AI connection settings
- **Description**: The backend reads its Addis AI connection from
  settings, and knows whether generation is set up.
- **Acceptance Criteria**:
  - New settings in `app/config.py`:
    - `addis_api_key` (env `ADDIS_API_KEY`, default `""`);
    - `addis_api_base_url` (default `https://api.addisassistant.com`);
    - `addis_timeout_seconds` (default `30`).
  - Generation is "set up" exactly when `addis_api_key` is not empty.
  - The key is never written to a log line, an error message, an API
    response or the admin bundle. A test asserts that the key does not
    appear in captured logs or response bodies.
  - `backend/.env.example` (if present) gets an empty `ADDIS_API_KEY=`
    line. The real key lives only in `backend/.env` locally, which is not
    committed, and in Vercel env in production.
- **Priority**: Must

#### FR-2: Addis AI client
- **Description**: One infrastructure class wraps the Addis REST calls
  the admin needs. Every other part of the backend uses it, never `httpx`
  directly.
- **Acceptance Criteria**:
  - Methods:
    - `list_voices(language)` returns the voices for `am` or `om`;
    - `usage()` returns the balance, currency, formatted balance, price
      per minute and maximum characters;
    - `generate(text, voice_id, language, speed)` returns the mp3 bytes,
      the duration in seconds, the voice name, the character count and
      the credit remaining.
  - `generate` sends:
    - `output_format: "mp3_44100"`;
    - `voice_settings: {"speed": speed}`;
    - a fresh `client_request_id`, `buna-{uuid4}`, on every call.
  - The audio comes from `data.audio` (data URL, base64). If that field
    is missing, as in an idempotent replay, the client downloads
    `data.audio_url` once. The signed URL is never returned to callers.
  - Every request has the `x-api-key` header and the configured timeout.
  - On 429 or 5xx, the client retries up to 3 times with waits of 1, 2
    and 4 seconds, honouring `Retry-After` when given. A 4xx other than
    429 is not retried.
  - It raises typed errors (FR-10): not set up, unauthorized, language
    mismatch, text rejected, out of credit, rate limited, upstream
    failed, timed out. Each error carries Addis's error `code` for the
    log, but not the key.
  - Tests use a fake HTTP transport (no network) for success, data-URL
    decoding, the `audio_url` fallback, retries and each error mapping.
- **Priority**: Must

### Backend: voice settings

#### FR-3: Voice settings store
- **Description**: The voice settings for each supported language are
  stored on the server and shared by every admin.
- **Acceptance Criteria**:
  - Supported languages are a constant in the domain: `am` and `om`.
  - New table `voice_settings` with these columns:
    - `language` (PK, the language code);
    - `male_voice_id` and `female_voice_id` (text, not null);
    - `speed` (integer, not null, 0–100 with a check constraint);
    - `updated_by` (admin email, nullable);
    - `updated_at` (timestamp, nullable).
  - An Alembic migration creates the table. It runs on SQLite (dev) and
    Postgres (Neon).
  - With no row for a language, reads return the defaults:

    | Language | Male | Female | Speed |
    |---|---|---|---|
    | `am` | `am-yohanes-calm` | `am-loza` | 50 |
    | `om` | `om-diriba` | `om-obse` | 50 |

    A row is written only on the first save, so no seed step is needed.
  - Repository: `get(language)` returns the stored row or the defaults;
    `list()` returns both languages; `save(language, male, female,
    speed, admin)` upserts the row.
- **Priority**: Must

#### FR-4: Read the voice settings
- **Description**: `GET /api/v1/admin/voice/settings` tells the admin
  what is set.
- **Acceptance Criteria**:
  - The response has `configured` (bool, from FR-1) and `languages`.
    Each language has `language`, `language_name` (from the languages
    table, falling back to the code), `male_voice_id`,
    `female_voice_id`, `speed`, `updated_by` and `updated_at` (null for
    the defaults).
  - `languages` lists `am` then `om`.
  - It works when generation is not set up, so the page can say so.
  - Admin-only: 401 without a session, 403 for a non-admin.
- **Priority**: Must

#### FR-5: Change the voice settings
- **Description**: `PUT /api/v1/admin/voice/settings/{language}` saves
  one language's voices and speed.
- **Acceptance Criteria**:
  - The body is `{male_voice_id, female_voice_id, speed}`. The response
    is the saved language in the same shape as in FR-4.
  - A language outside `am` and `om` gets 404 with
    `entity: "voice_settings"`.
  - `speed` must be a whole number from 0 to 100. Otherwise the response
    is 422 with field `speed`.
  - Each voice ID must start with `{language}-`. Otherwise the response
    is 422 with field `male_voice_id` or `female_voice_id`, and the
    message "That is not a voice for {language name}".
  - When generation is set up, each voice ID must also be in the Addis
    catalog for that language with the right gender and
    `is_available: true`. Otherwise the response is 422 on that field,
    with the message "No available {male|female} voice {id}". If the
    catalog cannot be reached, the save goes ahead on the prefix check
    alone, and the log notes it.
  - The save is logged: `admin_write action=update entity=voice_settings
    id={language} admin={email}`.
  - Admin-only, as in FR-4.
- **Priority**: Must

### Backend: catalog and credit

#### FR-6: Voice catalog
- **Description**: `GET /api/v1/admin/voice/voices?language={am|om}`
  lists the voices an admin can choose.
- **Acceptance Criteria**:
  - It returns `voices: [{id, name, descriptor, gender, style,
    preview_audio_url}]`. Only voices with `is_available: true` are
    included, in Addis's `sort_order`.
  - The result is cached in memory per language for 10 minutes, so
    opening the Voices page twice makes one Addis call.
  - Errors:
    - a missing or unsupported `language` gives 422 on field `language`;
    - generation not set up gives 503 `VOICE_NOT_CONFIGURED`;
    - Addis failing gives 502 `VOICE_SERVICE_FAILED`.
  - Admin-only.
- **Priority**: Must

#### FR-7: Credit
- **Description**: `GET /api/v1/admin/voice/usage` shows what is left to
  spend.
- **Acceptance Criteria**:
  - It returns `{balance, currency, formatted_balance, price_per_minute,
    max_characters}`, mapped from Addis `GET /voice/usage`.
  - It is not cached.
  - Errors are as in FR-6.
  - Admin-only.
- **Priority**: Should

### Backend: generation

#### FR-8: Generate a clip
- **Description**: `POST /api/v1/admin/voice/generate` returns a new clip
  for the admin to check. It stores nothing of ours.
- **Acceptance Criteria**:
  - Body fields:
    - `language` (`am` or `om`) **or** `lesson_id`. With `lesson_id`,
      the language is that lesson's learning language, read through
      `learning_language_of_lesson`.
    - `text` (string).
    - `gender` (`male` or `female`).
    - Optional `speed` (0–100). Without it, the language's saved speed
      is used.
    - Optional `voice_id`. Without it, the language's voice for that
      gender is used. It must pass the prefix rule of FR-5. It is used
      by "Try it" on the Voices page.
  - It answers 200 with `Content-Type: audio/mpeg` and the mp3 bytes,
    plus these headers:
    - `X-Voice-Id`;
    - `X-Voice-Name` (percent-encoded);
    - `X-Duration-Seconds`;
    - `X-Credits-Remaining`.
    - The headers are exposed to the admin origin through CORS
      `expose_headers`.
  - Generation never writes to R2, local media or the database. The
    clip lives only in the admin's browser until "Use this clip".
  - Admin-only. A lesson that does not exist gives 404, as other admin
    routes do.
- **Priority**: Must

#### FR-9: Text rules
- **Description**: The text is checked before any money is spent.
- **Acceptance Criteria**:
  - The text is trimmed. Empty text after trimming gives 422 on `text`:
    "Type the words to say".
  - More than 500 characters gives 422 on `text`: "Up to 500
    characters: a word, a phrase or a sentence". Addis allows 5000, but
    clips over 60 seconds fail and lesson audio is short.
  - The text is sent as typed otherwise, ellipsis included. W014
    "Maqaan koo … dha." gave a 1.8-second clip with a pause where "…"
    is.
  - Text is not logged (FR-11).
- **Priority**: Must

#### FR-10: Error mapping
- **Description**: The admin is told in plain words why generation
  failed. All errors use the project's standard error body.
- **Acceptance Criteria**:

  | Situation | HTTP | Code | Message |
  |---|---|---|---|
  | No `ADDIS_API_KEY` | 503 | `VOICE_NOT_CONFIGURED` | Generated voices aren't set up on this server. |
  | Key refused by Addis (401/403) | 503 | `VOICE_NOT_CONFIGURED` | The voice service refused this server's key. |
  | Language not `am` or `om` | 422 | field `language` | Generated voices are not available for {language name}. |
  | Text empty or too long | 422 | field `text` | See FR-9 |
  | Addis `TEXT_REQUIRED` or another text rejection | 422 | field `text` | The voice service couldn't read this text. |
  | Addis `VOICE_LANGUAGE_MISMATCH` | 422 | field `voice_id` | That voice doesn't speak {language name}. |
  | Out of credit (Addis 402, or a credit or balance error code) | 402 | `VOICE_CREDIT_EXHAUSTED` | The Addis AI credit has run out. |
  | Still rate limited after retries | 429 | `VOICE_RATE_LIMITED` | Too many requests. Try again in a minute. |
  | Addis 5xx after retries, or a broken response | 502 | `VOICE_SERVICE_FAILED` | The voice service failed. Try again. |
  | No answer within the timeout | 504 | `VOICE_SERVICE_TIMEOUT` | The voice service didn't answer. Try again. |

  - Addis's own message text is never shown to the admin. Only its code
    goes to the log.
- **Priority**: Must

#### FR-11: Audit log
- **Description**: Each generation leaves a trace, without the text.
- **Acceptance Criteria**:
  - A success logs: `admin_write action=generate entity=voice
    language={code} voice={voice_id} chars={n} seconds={duration}
    admin={email}`.
  - A failure logs: `admin_voice_failed code={our code}
    addis_code={addis code or -} admin={email}`.
- **Priority**: Must

### Admin: the Voices page

#### FR-12: Voices page and navigation
- **Description**: A new page at `/voices`, listed in the side
  navigation.
- **Acceptance Criteria**:
  - The nav item is labelled "Voices" with icon `record_voice_over`,
    placed after Sounds. It is current on `/voices`.
  - The page header reads "Voices", with this description: "The
    generated voices for each language, and how fast they speak."
  - The page loads FR-4 settings. For each language, it also loads the
    FR-6 catalog and FR-7 credit at the same time.
  - When `configured` is false, a note says: "Generated voices aren't set
    up on this server. Add ADDIS_API_KEY to the backend's environment."
    The settings are shown read-only, and Save and Try it are hidden.
  - Loading shows the shell's usual skeleton. A load error shows the
    usual error with Retry.
- **Priority**: Must

#### FR-13: One card per language
- **Description**: Each supported language has a card where its voices
  and speed are chosen.
- **Acceptance Criteria**:
  - The card title is the language name and code, for example "Afaan
    Oromo · om".
  - **Male voice** and **Female voice** selects list that gender's
    voices as "{name} · {style}", for example "Diriba · Narration", with
    the descriptor as hint text below.
  - A play button next to each select plays that voice's
    `preview_audio_url`. Only one preview plays at a time.
  - The **Speed** slider runs 0–100 in steps of 5, with "Slower" and
    "Faster" at the ends, the number beside it, and a "Reset to 50" link.
    Help text: "Small changes are hard to hear; each take also varies a
    little."
  - "Last changed by {email}, {relative time}" appears, or "Default
    voices" when the language has never been saved.
  - **Save** is enabled only when something changed. It sends FR-5 and
    shows "Saved" for 3 seconds. Field errors from the server appear
    under their control.
  - **Discard** returns the card to its saved values.
  - Each card saves on its own, so changing one language never touches
    the other.
- **Priority**: Must

#### FR-14: Try it
- **Description**: The admin hears the current choices before saving
  them.
- **Acceptance Criteria**:
  - Each card has a sample text box. It starts with:
    - `am`: "ሰላም! ስሜ ሳራ ነው። እንኳን ደህና መጣህ።"
    - `om`: "Akkam! Maqaan koo Saaraa dha. Baga nagaan dhufte."
  - It can be edited, up to 500 characters.
  - "Try male" and "Try female" call FR-8 with the card's **unsaved**
    voice for that gender (`voice_id`) and its unsaved speed, then play
    the result.
  - Nothing is stored. A busy state disables both buttons while a try
    is running.
  - Errors use the FR-10 messages, shown in the card.
- **Priority**: Must

#### FR-15: Missing voices and credit
- **Description**: The page warns about voices that are gone, and shows
  the money left.
- **Acceptance Criteria**:
  - If a saved voice ID is not in the language's catalog, its select
    shows "{id} (no longer offered)" as the current choice, with a
    warning: "Addis AI no longer offers this voice. Choose another and
    save."
  - A credit line at the top of the page shows the formatted balance and
    price, for example "Credit: Br 997.53 · 2.5 ETB per minute of
    audio". If the usage call fails, the line is left out and the page
    still works.
  - The credit line refreshes after every Try it.
- **Priority**: Should

### Admin: the Generate tab

#### FR-16: The tab
- **Description**: `AudioField` gets a fourth tab, Generate, with icon
  `record_voice_over`, after Link.
- **Acceptance Criteria**:
  - `AudioField` takes a new optional prop: `voice?: { language?:
    string; lessonId?: string; text?: string }`. A field without it
    shows no Generate tab, so existing callers are unchanged until they
    are wired up (FR-20).
  - Like the other panels, the Generate panel stays mounted while the
    admin switches tabs, so a generated take is not lost.
  - If the field's language is known and is not `am` or `om`, the panel
    says "Generated voices are not available for {language}" and offers
    nothing else.
  - If the server reports generation is not set up, through FR-4
    `configured` (read once per page load and shared between fields),
    the panel says so and points to Record and Upload.
- **Priority**: Must

#### FR-17: Generate controls
- **Description**: What the admin sets before generating.
- **Acceptance Criteria**:
  - **Text** is a textarea using the field's language `lang`. It starts
    with `voice.text` and can be edited, with a character counter
    "{n} / 500". When `voice.text` changes, for example because the item
    text was edited, an untouched box follows it and an edited box keeps
    the admin's text.
  - **Voice** is a two-button choice, "Male · {name}" and "Female ·
    {name}", using the names from the language's settings and catalog,
    for example "Female · Obse".
  - The voice choice is remembered in this browser under
    `buna.admin.voiceGender`, defaulting to Female. Storage failures are
    ignored.
  - **Speed** is a slider like the one in FR-13. It starts at the
    language's saved speed and applies to this clip only. "Reset" returns
    it to the saved speed.
  - **Generate** is disabled while the text is empty or over 500
    characters, or a generation is running. While running, it reads
    "Generating…".
- **Priority**: Must

#### FR-18: Check and trim the take
- **Description**: A generated take opens in the existing clip editor.
- **Acceptance Criteria**:
  - The returned mp3 goes into the same editor recordings and uploads use
    (`useCleaning`, `ClipEditor`). Silence is cut automatically, the
    start and end handles and sliders move the cut, volume is evened,
    and the existing effects are offered.
  - "Cleaned" and "As generated" can be compared, and either one kept.
    The "original" choice is labelled "As generated" in this panel.
  - Below the editor: "{voice name} · {duration} · not stored yet".
  - **Generate again** makes a fresh take with the current text, voice
    and speed, and replaces the take in the editor. The cut resets for
    the new take; cleaned or not, and the effects, carry over, as they do
    for recordings.
  - **Discard** clears the take.
  - Errors show under the controls with the FR-10 message, and the last
    good take stays.
- **Priority**: Must

#### FR-19: Use the take
- **Description**: The kept take is stored like any other clip.
- **Acceptance Criteria**:
  - **Use this clip** sends the final clip (cleaned or as generated)
    through the field's existing `ClipUploader`, the same path Upload
    uses, with the same 5 MB check and messages.
  - On success the clip becomes the current clip, marked "Not saved yet",
    and the take is cleared. The page's own Save stores the address, as
    it does today.
  - A Workbook item's status is not changed by generating. Saving follows
    the existing rules: a new recording on a Reviewed item behaves
    exactly as a recorded one does.
  - While uploading, the button reads "Uploading…" and the page's busy
    state holds Save, as for uploads.
- **Priority**: Must

#### FR-20: Fields that offer Generate
- **Description**: The clip fields that get the Generate tab, and what
  each fills in.
- **Acceptance Criteria**:

  | Field | `voice` passed | Text filled in |
  |---|---|---|
  | Workbook item recording (`workbook/LessonPage.tsx`) | `language` = the course's learning language | The item's learning-language text (`draft.text`) |
  | Sounds letter, "Sound" (`sounds/LetterPage.tsx`) | `language` = chart language | The letter as written, for example "ሀ" |
  | Sounds letter, "Example word's sound" | `language` = chart language | The example word |
  | Listening and audio-image exercise audio (`exercises/ExerciseForm.tsx`) | `lessonId` | Empty, with placeholder "Type the words the learner should hear" |

  - Languages other than `am` and `om`, such as English letters A–Z,
    show the not-available note from FR-16.
- **Priority**: Must

### Could

#### FR-21: Generated-clip label
- **Description**: A stored clip shows that it was generated, and by
  whom.
- **Acceptance Criteria**:
  - "Use this clip" passes a source tag, `gen-{voice_id}`, for example
    `gen-om-obse`, with the upload.
  - Each presign endpoint (lesson audio, Workbook, Sounds) accepts an
    optional `source` matching `^gen-(am|om)-[a-z0-9-]{1,40}$`, and
    names the object `.../{source}-{hex}.{ext}`. Anything else is
    refused with 422. Without it, names are unchanged.
  - The current-clip panel recognises such a name and shows a pill
    "Generated · {Name}", where the name is the voice ID's first word
    after the language, capitalised: `om-obse` → "Obse",
    `am-yohanes-calm` → "Yohanes". The tooltip reads "Made with Addis
    AI".
  - No database change.
- **Priority**: Could

---

## Non-Functional Requirements

### Performance

| Requirement | Metric | Target |
|-------------|--------|--------|
| Generation for under 100 characters | Press Generate to a take in the editor | < 5 s p95 (Addis answered in about 1–2 s in tests) |
| Voices page | First render with settings and catalogs | < 2 s on the admin's normal connection |
| Catalog cache | Addis calls per language per 10 minutes, per server instance | ≤ 1 |

### Security

| Requirement | Standard | Notes |
|-------------|----------|-------|
| API key | Server-side only | `ADDIS_API_KEY` is in `backend/.env` and Vercel env. It is never committed, sent to the browser or logged. |
| Access | Existing admin auth | The `/api/v1/admin/voice/*` routes need an admin session (401/403 as for other admin routes). |
| Untrusted data | Response handling | Addis responses are parsed defensively. A broken body gives 502, not a 500 with a stack trace. |

### Cost

| Requirement | Metric | Target |
|-------------|--------|--------|
| No accidental spend | Generations without a press | 0. Nothing generates on page load, on typing, or by itself. |
| Rough cost | ETB | About 2.5–5 ETB per minute of audio, so a 3-second word costs about 0.13–0.25 ETB. |

### Reliability

| Requirement | Metric | Target |
|-------------|--------|--------|
| Addis down | Impact | Only Generate, Try it, the catalog and credit fail. Record, Upload, Link, saving and the learner app are unaffected. |
| Retries | Attempts on 429/5xx | At most 4 attempts in total. The whole request stays under the timeout plus about 7 s. |

---

## Constraints

### Technical Constraints

**Project-wide standards**: Required standards will be loaded from the
memory-bank standards folder by the Construction Agent.

**Intent-specific constraints**:

- **Addis API:** the REST shapes are as listed in "Findings", including
  the required `client_request_id`. A signed `audio_url` is never saved
  as a clip's address.
- **Audio limits:** Addis limits audio to 60 seconds and 10 MB. Our own
  limit is 5 MB per stored clip.
- **Free tier:** 60 requests a minute, 1,000 a day and 3 at a time.
- **Code reuse:** the Generate panel reuses `ClipEditor`, `clean.ts`,
  `codec.ts`, `effects.ts` and the field's `ClipUploader`, with no
  second editing or upload path.
- **Admin code style:** prettier is not run in `admin/`. Match the
  surrounding style by hand.

### Business Constraints

- Setting `ADDIS_API_KEY` on Vercel is a production change and needs the
  owner's go-ahead.
- The key pasted into chat on 2026-10-12 must be replaced with a new one
  before production.
- Check Addis AI's terms on publishing generated audio in a commercial
  app before generated clips ship to learners.

---

## Assumptions

| Assumption | Risk if Invalid | Mitigation |
|------------|-----------------|------------|
| Addis voice IDs stay stable | A saved voice disappears | FR-15 flags it, and the admin picks another. |
| The speed setting audibly changes pace | Admins can't slow clips for learners | Takes vary anyway, so the admin generates again and picks. A later intent could add "slower" to the clip editor. |
| Generated pronunciation is good enough for teaching | Learners copy mistakes | A generated clip doesn't change a Workbook item's status. Marking Reviewed stays a human step, and the FR-21 label makes generated clips easy to spot. |
| Decoding mp3 in the browser works for the clip editor | The editor can't open a take | Chrome, Edge, Safari and Firefox all decode mp3. If decoding fails, the editor's existing fallback keeps the take as generated. |
| A response of about 100 KB of mp3 fits Vercel's limits | Generation fails in production | Vercel allows 4.5 MB responses. Phrases are 20–100 KB. |

---

## Decisions (2026-10-12)

| Question | Decision |
|---|---|
| Default speed | 50, Addis's normal pace. The owner can change it per language on the Voices page. |
| Remembering Male or Female | Per browser (`buna.admin.voiceGender`), not per item. Per item could come later with dialogue lines. |
| Where the voice choice lives | A new Voices page, not the Languages page, because only `am` and `om` have voices and it needs its own catalog and credit. |

## Open Questions

| Question | Owner | Due Date | Resolution |
|----------|-------|----------|------------|
| Do Addis AI terms allow generated audio in a commercial app? | Owner | Before production | Pending |
| Should a generated clip later also be checked with Addis speech-to-text against its text? | Owner | Later intent | Pending |
