---
stage: plan
bolt: 094-voices-page
created: '2026-10-12T14:05:00Z'
---

## Implementation Plan: voices-admin-page

### Objective

This bolt covers story 012 (FR-12) and story 013 (FR-13). The admin gets
a Voices page in the side menu, with one card per language. Each card
has male and female voice selects and a speed slider, plus Save and
Discard. Previews, Try it, the missing-voice warning and credit come in
bolt 095.

### What the code says (checked before planning)

- **F1 Pages:** pages follow `LanguagesPage.tsx`:
  - a `<main className="mx-auto max-w-6xl px-4 py-6 ...">` with a
    `PageHeader` (eyebrow, title, description);
  - an error strip with "Try again";
  - sections as `rounded-lg border border-line bg-surface shadow-e1`
    cards;
  - API calls through `useSession().api`, with errors read by
    `messageOf()`.
- **F2 Routes:** routes are built in `tree/levels.ts` (`routes.*`) and
  registered in `App.tsx`. The menu is `NAV_GROUPS` in
  `shell/AppShell.tsx`, where Sounds and Languages sit under
  "Workspace".
- **F3 Fields:** fields use `FIELD_CLASS` from `ui/Input.tsx`. The
  Workbook's `Field` (label, hint, error) is local to `LessonPage.tsx`,
  and ranges use `accent-forest`, as in `ClipEditor.tsx`.
- **F4 "Last changed":** the Workbook shows "Last changed by {email},
  {when}" with `toLocaleString('en-GB', {day, month: 'short', hour,
  minute})`, not a relative time.
- **F5 Tests:** tests use `FakeServer` (`test/fakeServer.ts`) with
  `renderApp` and `withStoredSession`, and mock `GoogleButton`
  (`languages.test.tsx`).
- **F6 Formatting:** prettier is not run in `admin/`. The style is
  matched by hand, and `npm run lint`, `tsc -b` and `vitest` are the
  checks.

### Decisions

- **D1 Files:** `admin/src/voices/`:
  - `api.ts`, with the types `VoiceSettingsList`, `VoiceLanguage`,
    `VoiceOption`, `VoiceCatalog` and `VoiceUsage`, and the routes
    `voiceSettings`, `voiceLanguage(code)`, `voiceVoices(code)`,
    `voiceUsage` and `voiceGenerate`;
  - `VoicesPage.tsx`;
  - `VoiceCard.tsx`;
  - `voices.test.tsx`.

  The types stay in `voices/api.ts` rather than the shared `types.ts`,
  so unit 005 can import them from one place.
- **D2 Route and menu:** the route is `/voices`. The menu item is
  "Voices", icon `record_voice_over`, after Sounds and current on
  `/voices`.
- **D3 Loading:**
  1. `GET /admin/voice/settings` loads first.
  2. When it returns `configured`, the catalogs of both languages load
     at the same time. A failed catalog does not fail the page: that
     card shows "The voice list couldn't be loaded" with Retry, and its
     selects fall back to the saved IDs only.
  3. Without `configured`, no catalog is requested.

  While loading, the page shows "Loading…" in the card area, the same
  idiom as LanguagesPage. A settings error shows the error strip with
  "Try again".
- **D4 Not set up:** when `configured` is false, a note reads "Generated
  voices aren't set up on this server. Add ADDIS_API_KEY to the
  backend's environment." Each card then shows its saved male and female
  voice IDs and its speed as read-only text, with no Save.
- **D5 Card:** each card has:
  - the title "{language_name} · {code}";
  - a **Male voice** and a **Female voice** `<select>`, listing that
    gender's catalog voices as "{name} · {style}", with the chosen
    voice's descriptor as hint text;
  - a **Speed** `<input type="range" min=0 max=100 step=5>` with
    "Slower" and "Faster" labels, the number beside it, a "Reset to 50"
    button, and the help text "Small changes are hard to hear; each take
    also varies a little.";
  - a line reading "Last changed by {email}, {when}", using the
    Workbook's format, or "Default voices" before the first save;
  - **Discard** and **Save**. Save is enabled only when the card has
    changed. While saving it reads "Saving…", then "Saved" for 3 seconds.
- **D6 Errors:** a 422 with `details.field` shows the message under that
  field: male, female or speed. Other errors show in the card. Each card
  keeps its own draft, so saving one card never resets the other.
- **D7 Saved voice not in the catalog:** if the saved ID isn't in the
  catalog, the select still shows it as an option labelled with the bare
  ID, so nothing is silently changed. Bolt 095 adds the warning.
- **D8 Phone width:** the two selects sit side by side from `sm` up and
  stack below it. There is no horizontal scroll.

### Deliverables

- `admin/src/voices/api.ts`, `VoicesPage.tsx` and `VoiceCard.tsx`
- `admin/src/App.tsx` (the route) and `admin/src/shell/AppShell.tsx` (the
  menu item)
- `admin/src/voices/voices.test.tsx`:
  - the menu link opens the page;
  - the defaults and names are shown, with "Default voices";
  - the selects list only their gender, in order;
  - Save is disabled until a change;
  - saving sends PUT with the draft, shows "Saved", and shows the new
    "Last changed" line;
  - Discard restores the saved values;
  - a server field error shows under the speed or a voice;
  - saving Amharic keeps Afaan Oromo's unsaved edit;
  - when not configured, the page shows the note, no Save, and no
    catalog request;
  - a failed catalog shows its own message;
  - a failed settings load shows "Try again".

### Dependencies

- Bolts 090 and 092, for the settings, catalog and usage routes. Both are
  complete.

### Acceptance Criteria

- [ ] "Voices" is in the menu after Sounds and opens `/voices`.
- [ ] There is one card per language, with gender-filtered selects, the
  speed slider, Reset, "Last changed" or "Default voices", and Save and
  Discard.
- [ ] Save sends `PUT /admin/voice/settings/{code}` and shows field
  errors in place. Cards save independently.
- [ ] The not-configured state is read-only and asks for no catalog.
- [ ] `npm run lint`, `tsc -b` and `npm test` pass.

### Deviation from the unit brief

- **"Last changed" time:** it uses the Workbook's absolute format (for
  example "12 Oct, 14:05") instead of a relative time, to match the rest
  of the admin.

## Implement (2026-10-12T14:30:00Z)

- `admin/src/voices/api.ts`:
  - `voiceRoutes`: settings, language, voices, usage and generate.
  - Types: `VoiceLanguage`, `VoiceSettingsList`, `VoiceOption`,
    `VoiceCatalog` and `VoiceUsage`.
  - Constants: the speed range and the default speed.
- `admin/src/voices/VoicesPage.tsx`:
  - loads the settings first, then each language's catalog in parallel,
    but only when `configured` is true;
  - keeps a catalog state per language (loading, ready or failed), with
    its own Retry;
  - shows the error strip with "Try again", the not-set-up note and
    "Loading…";
  - updates a card's settings after it saves.
- `admin/src/voices/VoiceCard.tsx`:
  - keeps one draft per card;
  - **Voices:** a gender-filtered select for each voice, labelled
    "{name} · {style}", with the chosen voice's descriptor as a hint. A
    saved ID missing from the list stays as its own option.
  - **Speed:** the slider runs 0–100 in steps of 5, with Slower and
    Faster labels, the value, and "Reset to 50".
  - **Last changed:** "Last changed by …" in the Workbook's date format,
    or "Default voices".
  - **Discard and Save:** Save sends PUT and shows "Saved" for 3 s. A
    422 error appears under its field, and other errors appear in the
    card.
  - **Not set up:** a read-only facts view when the server can't
    generate.
- `admin/src/App.tsx`: the `/voices` route.
- `admin/src/shell/AppShell.tsx`: the "Voices" menu item after Sounds.

### Deviations

- **Save button name:** it reads "Save {language name}", for example
  "Save Afaan Oromo", so each card's button has its own accessible name.
- **"Last changed" time:** absolute, as noted in the plan.

### Checks

- `tsc -b` passes.
- `eslint` on the touched files passes.

## Test (2026-10-12T14:45:00Z)

`admin/src/voices/voices.test.tsx` has 10 tests, run against the fake
server:

- The menu link opens the page. Each language shows its default voices
  and descriptor, speed 50 and "Default voices".
- Each select lists only its gender's voices, as "{name} · {style}", in
  Addis's order.
- Save is disabled until something changes. Saving sends PUT with the
  draft (`om-hawi`, speed 40), then shows "Saved" and "Last changed by
  admin@example.com, 12 Oct, …", and Save is disabled again.
- Discard restores the saved values, and "Reset to 50" resets the speed.
- A 422 on `female_voice_id` shows its message on that card, without
  "Saved".
- Saving Amharic keeps Afaan Oromo's unsaved edit.
- A saved voice that is missing from the list is kept, not changed.
- With no key, the note is shown, the cards are read-only with no Save,
  and no catalog request is made.
- A failed voice list shows its message and Retry on its own card only,
  and Retry recovers.
- A failed settings load shows "Try again", which recovers.

### Issues found and fixed

- **Speed slider in jsdom:** jsdom doesn't move a range input with the
  arrow keys, so those tests set the slider with `fireEvent.change`. The
  component code is unchanged.

### Results

- `vitest run`: 40 files and 786 tests pass.
- `npm run lint` and `tsc -b` are clean.
- `vite build` succeeds. The chunk-size warning was already there before
  this bolt.
