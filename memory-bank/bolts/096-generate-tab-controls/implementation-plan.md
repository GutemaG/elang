---
stage: plan
bolt: 096-generate-tab-controls
created: '2026-10-12T15:40:00Z'
---

## Implementation Plan: generate-tab

### Objective

This bolt covers stories 016 (FR-16) and 017 (FR-17). Every clip field
that is given a `voice` prop gets a fourth tab, **Generate**. The tab has
a text box, a choice of male or female voice, a speed slider and a
Generate button, and produces a playable take.

Bolt 097 then passes the take through the clip editor and adds "Use this
clip". Bolt 098 wires the real fields.

### What the code says (checked before planning)

- **F1 Tabs:** `AudioField` (`admin/src/audio/AudioField.tsx`) has a
  `TABS` array, currently Record, Upload and Link. It keeps every panel
  mounted (`hidden` when not selected), so a take survives a tab switch.
  Its props are `lessonId`, `upload`, `title`, `hint`, `url`, `savedUrl`
  and `onChange`.
- **F2 Existing tests:** the `AudioField` tests in `audio.test.tsx` go
  through the exercise editor via `renderApp`. They expect three tabs,
  and must pass unchanged.
- **F3 Voice helpers:** `voices/api.ts` (bolt 095) has `generateClip`,
  `voiceRoutes`, `MAX_TEXT`, the speed constants and the types.
  `VoicesPage`'s card has a speed slider (`SpeedField`), but that is
  private to `VoiceCard.tsx`.
- **F4 No language for exercises:** exercise fields only know `lessonId`.
  The backend resolves that lesson's language (bolt 093), so the field
  can't show voice names until it has generated a take.

### Decisions

- **D1 Prop:** `AudioField` takes `voice?: { language?: string;
  lessonId?: string; text?: string }`. With the prop, the tabs are
  Record, Upload, Link and Generate (icon `record_voice_over`). Without
  it, the three tabs stay as they are today.
- **D2 Shared setup:** `voices/useVoiceSetup.ts` reads
  `GET /voice/settings` once per page load, as a promise cached at module
  level for each `ApiClient`. Several fields on one page share one
  request.
  - It also reads the field language's catalog once, through the same
    cache, so voice names can be shown.
  - `forgetVoiceSetup()` clears the cache. `VoiceCard` calls it after a
    save, so the next field picks up the new voices.
  - A failed catalog only costs the names. The buttons then show the
    voice IDs.
- **D3 Panel states** (`audio/GeneratePanel.tsx`), checked in this order:
  1. The setup is still loading: the panel shows "Loading voices…".
  2. `configured` is false: the panel shows only "Generated voices aren't
     set up on this server. Record or upload instead."
  3. The language is known and isn't `am` or `om`: the panel shows only
     "Generated voices are not available for {language}." The name
     comes from the settings when present, and falls back to the code.
  4. Otherwise, the controls (D4) are shown. With only a `lessonId`, the
     controls still show and the server decides; its 422 for a language
     without voices appears as an error.
- **D4 Controls:**
  - **Text:** a textarea with `lang` set to the field's language. It
    starts as `voice.text`, with a "{n} / 500" counter that turns red
    when the text is too long.
    - An untouched box follows changes to `voice.text`. Once the admin
      types, the box keeps their text.
    - The placeholder is "Type the words the learner should hear".
  - **Voice:** two buttons in a `radiogroup`, "Male · {name}" and
    "Female · {name}". The name comes from the catalog, then the ID, then
    nothing, so a field with only a lesson shows "Male" and "Female".
    - The choice is remembered in `localStorage` under
      `buna.admin.voiceGender`, and the default is female. Reads and
      writes are wrapped in try/catch.
  - **Speed:** a slider, 0–100 in steps of 5. It starts at the
    language's saved speed, or 50 when that is unknown, and has a Reset
    button. The speed applies to this field only.
    - `SpeedField` moves from `VoiceCard.tsx` to `voices/SpeedField.tsx`,
      so both use the same control.
  - **Generate:** disabled when the text is empty or over 500
    characters, or while a take is running. While running it reads
    "Generating…".
    - It posts `{language | lesson_id, text, gender, speed}`. It never
      sends `voice_id`, so the saved voice for that gender is used.
- **D5 Take, until bolt 097:** after a successful generation, the panel
  shows:
  - an `<audio controls>` element playing a blob URL, which is freed
    when replaced or when the field unmounts;
  - the line "{voice name} · {seconds} s · not stored yet";
  - a **Discard** button.

  An error shows under the controls, and the previous take stays.

### Deliverables

- `admin/src/voices/useVoiceSetup.ts`
- `admin/src/voices/SpeedField.tsx`, moved out of `VoiceCard.tsx`, with
  `VoiceCard` importing it and calling `forgetVoiceSetup()` after a save
- `admin/src/audio/GeneratePanel.tsx`
- `admin/src/audio/AudioField.tsx`: the `voice` prop and the fourth tab
- **Tests:** `admin/src/audio/generate.test.tsx` renders `AudioField`
  directly inside `MemoryRouter` and `SessionProvider` with a stored
  session.
  - **Tabs:** there are four tabs only with the `voice` prop.
  - **Panel states:** not set up; a language without voices; loading.
  - **Text:** filled in from `voice.text`; follows it while untouched and
    keeps the admin's edit after.
  - **Voice:** buttons named from the catalog, falling back to bare
    "Male" and "Female" with only a lesson. The gender is remembered,
    and a storage that throws still works.
  - **Speed:** starts at the saved speed, and Reset works.
  - **Generate:** disabled while empty or over the limit; the body is
    sent for a language and for a lesson; "Generating…" shows while a
    take runs; the take plays with its line; an error keeps the last
    take; Discard clears it.
  - **Caching:** two fields on one page make one settings request.

### Dependencies

- Bolts 093 and 095 (the generate route and `generateClip`), both
  complete.

### Acceptance Criteria

- [ ] The Generate tab appears only with `voice`. Existing fields and
  tests are unchanged.
- [ ] The text, the voice choice (remembered), the speed and Generate
  work as in D4. A take plays with its voice name and length.
- [ ] The not-set-up and language-without-voices states show their
  messages and nothing else.
- [ ] Settings are fetched once per page load.
- [ ] `npm run lint`, `tsc -b`, `vitest` and `vite build` pass.

## Implement (2026-10-12T16:05:00Z)

- **`admin/src/voices/useVoiceSetup.ts`:**
  - It caches, per `ApiClient`, one settings promise and one catalog
    promise per language. `forgetVoiceSetup()` clears the cache by
    starting a new generation of entries, and failed reads are not
    kept.
  - `useVoiceSetup(api, language)` returns one of:
    - `loading`;
    - `failed` with a message;
    - `ready`, with `{configured, language settings or null, languages,
      names}`.
  - Each answer is stored with the api and language it belongs to, so
    there is no `setState` inside an effect body (the React hooks lint
    rule).
- **`admin/src/voices/SpeedField.tsx`:** `SpeedField` and `Field` moved
  here from `VoiceCard.tsx`. `SpeedField` gained `defaultValue`, the
  value Reset goes to, and a `hint`. `VoiceCard` imports both and calls
  `forgetVoiceSetup()` after a save.
- **`admin/src/audio/GeneratePanel.tsx`:**
  - It exports `VoiceSource` `{language?, lessonId?, text?}`.
  - **States:** loading, failed, not set up, a language without voices,
    and the controls.
  - **Words to say:** a textarea with `lang`, the placeholder and a
    "{n} / 500" counter. The text is `edited ?? voice.text`, so an
    untouched box follows the item.
  - **Voice:** a radiogroup, "Male · {name}" / "Female · {name}", where
    each name comes from the catalog, then the ID, then nothing. The
    choice is stored under `buna.admin.voiceGender` inside try/catch,
    with Female as the default.
  - **Speed:** starts at the saved speed, or 50, and resets to it.
  - **Generate:** posts the language or `lesson_id`, the text, the
    gender and the speed, and never `voice_id`. It reads "Generating…"
    while running and "Generate again" once there is a take.
  - **The take:** an `<audio controls>` on a blob URL, freed when it is
    replaced or unmounted. The line under it reads "{name} · {s} s · not
    stored yet", with Discard. An error keeps the last take.
- **`admin/src/audio/AudioField.tsx`:** the new `voice?: VoiceSource`
  prop. With it, the tabs are Record, Upload, Link and Generate.
  Without it, they are as before.

### Deviations

- **`Field` moved too:** it went to `SpeedField.tsx` with `SpeedField`,
  because both the card and the panel need it.
- **Wording:**
  - The text box is labelled "Words to say".
  - After the first take, Generate reads "Generate again", which comes
    from FR-18 and fits here already.
- **A failed settings read** shows its own message, an extra state the
  plan didn't list.

### Checks

- `tsc -b` and `eslint` pass on `src/audio` and `src/voices`.
- The existing audio and voices tests pass (114).

## Test (2026-10-12T16:25:00Z)

`admin/src/audio/generate.test.tsx` has 14 tests. They render
`AudioField` directly inside `MemoryRouter` and `SessionProvider`,
against the fake server.

- **Tabs:** Record, Upload and Link only without `voice`; four tabs with
  it.
- **Prefill and labels:**
  - the item's words, with `lang="om"`;
  - the 16 / 500 counter;
  - "Female · Obse", the default, and "Male · Diriba";
  - the saved speed of 40.
- **Generate:** sends `{language: om, text, gender: male, speed: 30}`,
  plays `blob:take-1`, shows "Obse · 2.0 s · not stored yet", and the
  button then reads "Generate again".
- **Lesson only:**
  - bare "Female" and "Male", the placeholder and speed 50;
  - it posts `lesson_id` instead of `language`.
- **Remembered voice:**
  - a choice is stored, and the next field opens on it;
  - when storage is blocked, only for the voice key so the session
    still works, it opens on Female and choosing still works.
- **Words box:** an untouched box follows the item's words, and the
  admin's typing is kept.
- **Limits:** the button is disabled when the text is empty or 501
  characters long, and the counter turns red.
- **Busy state:** "Generating…" is disabled while the take is pending,
  then "Generate again" is enabled.
- **Errors:** a 429 shows its message and keeps the last take, and
  Discard clears it.
- **No key:** only the note shows, with no Generate.
- **English:** "Generated voices are not available for en." and no
  controls.
- **Shared reads:** two fields on a page make one settings request and
  one catalog request.

### Issues found and fixed

- **Blocking storage broke the session.** The first storage test
  blocked all of `Storage`, which also blocked the session token. It now
  blocks only the voice key. This affected the test only.

### Results

- `vitest run`: 41 files and 811 tests pass. All the existing
  `AudioField` tests pass unchanged.
- `npm run lint` and `tsc -b` are clean.
- `vite build` succeeds.
