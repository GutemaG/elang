---
stage: plan
bolt: 095-voices-page-try-and-credit
created: '2026-10-12T14:50:00Z'
---

## Implementation Plan: voices-admin-page

### Objective

This bolt covers stories 014 (FR-14) and 015 (FR-15). On the Voices
page, the admin can:

- hear each voice's preview;
- try the current, unsaved choices on a sample sentence;
- see when a saved voice is no longer offered;
- see the Addis credit left.

### What the code says (checked before planning)

- **F1 API client:** `ApiClient` (`src/api.ts`) only returns JSON. A
  generated take is an mp3 body with `X-Voice-*` headers, so it needs a
  binary request. Error bodies would still be JSON, read by `toApiError`.
- **F2 Fake server:** `FakeServer` replies with JSON only (`json(status,
  body)`), so a test cannot serve an mp3 or headers yet.
- **F3 Playback:** `UploadFilesPage` plays through one shared `<audio>`
  ref with `audio.play()` and a `.catch()`. Tests stub
  `HTMLMediaElement.prototype.play` and `pause` with `vi.spyOn`.
- **F4 Generate route:** `POST /admin/voice/generate` (bolt 093) takes
  `{language, text, gender, voice_id, speed}` and returns the mp3 with
  `X-Voice-Id`, `X-Voice-Name` (percent-encoded), `X-Duration-Seconds` and
  `X-Credits-Remaining`. The headers are exposed through CORS.

### Decisions

- **D1 Binary requests:** add `ApiClient.postForBlob(path, body):
  Promise<{ blob: Blob; headers: Headers }>`. It has the same token, 401
  handling and `toApiError` as the JSON requests. The request code is
  shared through a private `send()`, so the auth logic isn't duplicated.
- **D2 Generate helper:** `voices/api.ts` gets `generateClip(api, body)`.
  It returns `{ blob, voiceId, voiceName, seconds, creditsRemaining }`,
  with the voice name decoded by `decodeURIComponent`. Bolt 096 reuses
  it.
- **D3 Fake server:** a `Reply` can carry `headers` and a `Blob` body,
  sent as is. Existing JSON replies behave as before.
- **D4 One player per page:** `VoicesPage` owns one hidden `<audio>` and
  a `play(key, src)` / `stop()` pair, which it passes to the cards.
  - Starting any preview or try stops whatever was playing.
  - The button that is playing shows Stop.
  - A try's blob URL is freed when it is replaced and when the page
    unmounts.
  - A failed `play()` shows "This browser couldn't play the clip." in
    the card.
- **D5 Previews:** a play button sits next to each voice select, labelled
  "Play {voice name} preview", or "Stop" while playing. It plays that
  voice's `preview_audio_url`. When the voice has no preview, the button
  is disabled with the title "No preview for this voice".
- **D6 Try it:** each card has a "Sample" textarea with the default
  sentence for its language:
  - `am`: "ሰላም! ስሜ ሳራ ነው። እንኳን ደህና መጣህ።"
  - `om`: "Akkam! Maqaan koo Saaraa dha. Baga nagaan dhufte."

  The textarea shows a "{n} / 500" counter. Below it are the "Try male"
  and "Try female" buttons.
  - Each button posts `generateClip` with the card's **unsaved** voice
    for that gender and its unsaved speed, then plays the result.
  - While a try is running, both buttons are disabled, and the pressed
    one reads "Generating…".
  - Empty text or more than 500 characters disables both buttons.
  - An error shows its message in the card.
  - Trying never saves, so Save's state is unchanged.
- **D7 Voice no longer offered:** when the catalog is ready and a selected
  ID isn't in that gender's list, the option reads "{id} (no longer
  offered)". The warning "Addis AI no longer offers this voice. Choose
  another and save." appears under the select instead of the hint. This
  replaces bolt 094's bare-ID option.
- **D8 Credit line:** a line under the page header reads "Credit: {formatted_balance} · {price}
  {currency} per minute of audio", or just the balance when there is no
  price.
  - It loads with the catalogs, and only when the server is configured.
  - If it fails, it is hidden and the rest of the page works.
  - It refreshes after each successful try.

### Deliverables

- `admin/src/api.ts`: `postForBlob` and the shared `send()`
- `admin/src/test/fakeServer.ts`: `Reply.headers` and Blob bodies
- `admin/src/voices/api.ts`: `generateClip` and `SAMPLE_TEXT`
- `admin/src/voices/VoicesPage.tsx`: the player, the credit line and the
  usage reload
- `admin/src/voices/VoiceCard.tsx`: previews, Sample, Try male and Try
  female, and the missing-voice warning
- **Tests:**
  - `voices.test.tsx`:
    - a preview plays the right URL, and a second preview stops the
      first;
    - Try female posts the unsaved voice and speed, plays a `blob:` URL
      and refreshes the credit;
    - the buttons read "Generating…" and are disabled during a try;
    - a try error shows in the card;
    - an empty sample disables both buttons;
    - a missing voice shows its warning and "(no longer offered)";
    - the credit line text;
    - a failed usage call hides the line and nothing else breaks;
    - trying doesn't save.
  - `api.test.ts`: `postForBlob` returns the blob and headers, and turns
    a JSON error into an `ApiError`.

### Dependencies

- Bolt 093 (the generate route) and bolt 094 (the page). Both are
  complete.

### Acceptance Criteria

- [ ] Each voice select has a working preview button, and only one sound
  plays at a time.
- [ ] Try male and Try female use the unsaved choices, play the take and
  save nothing.
- [ ] A voice that is no longer offered is flagged. The credit line shows
  and refreshes, and hides if it fails.
- [ ] `npm run lint`, `tsc -b`, `vitest` and `vite build` pass.

## Implement (2026-10-12T15:10:00Z)

- **`admin/src/api.ts`:** a new `postForBlob(path, body)` returns
  `{blob, headers}`. JSON requests and blob requests now share a private
  `send()`, which handles the token, network errors, 401s and
  `toApiError`.
- **`admin/src/test/fakeServer.ts`:** a `Reply` can carry `headers` and a
  `Blob` body, which is sent as is.
- **`admin/src/voices/api.ts`:**
  - `MAX_TEXT` (500) and `SAMPLE_TEXT` for `am` and `om`;
  - the `GenerateBody` and `GeneratedClip` types;
  - `generateClip()`, which reads `X-Voice-Id`, `X-Voice-Name` (decoded),
    `X-Duration-Seconds` and `X-Credits-Remaining`.
- **`admin/src/voices/usePlayer.ts`:** one `Audio` for the page, with
  `play(key, src)` and `stop()`.
  - `play()` resolves false when the browser refuses.
  - `playing` returns to null when the clip ends.
  - The last `blob:` URL is freed when it is replaced or the page
    unmounts.
- **`admin/src/voices/VoiceCard.tsx`:**
  - **Preview:** a ▶ button sits beside each select. It reads "Play
    {name} preview", or "Stop" while playing, and is disabled with a
    title when the voice has no preview.
  - **Try it:** a Sample textarea (with `lang` set), a "{n} / 500"
    counter, and Try male / Try female buttons. A try uses the card's
    unsaved voice and speed, plays the take and calls `onTried`. The
    pressed button reads "Generating…" and both are disabled while a try
    runs. Errors show under Sample.
  - **No longer offered:** a voice missing from the loaded list shows
    "{id} (no longer offered)", with the warning in place of the hint.
- **`admin/src/voices/VoicesPage.tsx`:**
  - `usePlayer()` is shared by the cards.
  - The credit line, "Credit: Br … · 2.5 ETB per minute of audio",
    loads with the catalogs when the server is configured. It is hidden
    if it fails, and reloads after each try.

### Deviations

- **Preview errors:** a preview that can't play shows its message in the
  card's general problem line, because there is no separate preview
  slot.

### Checks

- `tsc -b` and `eslint` pass on the touched files.
- The existing voices and api tests pass (19).

## Test (2026-10-12T15:35:00Z)

- **`admin/src/voices/voices.test.tsx`**, 9 new tests (19 in total):
  - **Previews:**
    - a preview plays its voice's URL, and starting a second preview
      stops the first, so only one button shows Stop;
    - a voice without a preview has its play button disabled.
  - **Try it:**
    - Try female sends the unsaved `om-hawi` at speed 35 with the
      sample, plays `blob:take-1`, and refreshes the credit from Br
      997.53 to Br 997.40;
    - no PUT is sent, and Save is still enabled;
    - while a take is pending, the pressed button shows "Generating…"
      and both buttons are disabled; they are re-enabled after it
      arrives;
    - a 402 shows "The Addis AI credit has run out." in the card, and
      nothing plays;
    - an empty sample, or one of 501 characters, disables both
      buttons, and the counter shows 0 / 500 or 501 / 500.
  - **No longer offered:** a voice Addis no longer lists shows its
    warning and the "(no longer offered)" option.
  - **Credit:** the credit line shows the balance and the price. A
    failing usage call leaves it out, shows no error, and Try still
    works.
- **`admin/src/api.test.ts`**, 2 new tests:
  - `postForBlob` returns the bytes and headers, and sends the token and
    body;
  - a 402 JSON error becomes an `ApiError`.

### Issues found and fixed

- **The fake server sent `[object Blob]` as the body.** jsdom's `Blob`
  is not the one `Response` reads, and it has no `arrayBuffer()`. The
  fake server now reads blob bodies with `FileReader` (`bytesOf`). This
  only affects tests.

### Results

- `vitest run`: 40 files and 797 tests pass.
- `npm run lint` and `tsc -b` are clean.
- `vite build` succeeds.
