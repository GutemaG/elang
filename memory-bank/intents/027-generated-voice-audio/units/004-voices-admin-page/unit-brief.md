---
unit: 004-voices-admin-page
intent: 027-generated-voice-audio
unit_type: frontend
default_bolt_type: simple-construction-bolt
phase: inception
status: complete
created: '2026-10-12T09:55:00Z'
updated: '2026-10-12T09:55:00Z'
---

# Unit Brief: Voices Admin Page

## Purpose

Let the owner choose, hear and save each language's voices and speed in
the admin.

## Scope

### In Scope
- The `/voices` route and a "Voices" nav item after Sounds.
- `admin/src/voices/`:
  - the page;
  - one card per language;
  - API helpers and types for settings, voices, usage and generate.
- In each card:
  - the selects, the preview play buttons and the speed slider;
  - Save and Discard, with field errors shown under their controls;
  - the "last changed" line.
- The sample text and Try it buttons, the missing-voice warning and the
  credit line.
- Tests in the admin's test setup (Vitest and Testing Library), with
  the API mocked as in the other pages' tests.

### Out of Scope
- The Generate tab (unit 005).
- The Languages page, which is unchanged.

---

## Assigned Requirements

| FR | Requirement | Priority |
|----|-------------|----------|
| FR-12 | Voices page and navigation | Must |
| FR-13 | One card per language | Must |
| FR-14 | Try it | Must |
| FR-15 | Missing voices and credit | Should |

---

## Stories

| Story ID | Title | Priority | Status |
|----------|-------|----------|--------|
| 012-voices-page-and-nav | A Voices page in the admin's navigation | Must | Planned (bolt 094) |
| 013-language-voice-card | Choose and save each language's voices and speed | Must | Planned (bolt 094) |
| 014-try-voices | Hear the unsaved choices before saving | Must | Planned (bolt 095) |
| 015-missing-voices-and-credit | See voices that are gone, and the credit left | Should | Planned (bolt 095) |

### 012-voices-page-and-nav (FR-12)

**As an** admin, **I want** a Voices page I can reach from the menu,
**so that** I know where the voice settings live.

- [ ] A "Voices" nav item with icon `record_voice_over` sits after
  Sounds, and is marked current on `/voices`.
- [ ] The page header reads "Voices", with the description "The
  generated voices for each language, and how fast they speak."
- [ ] The page loads the settings first, then both languages' catalogs
  and the credit at the same time.
- [ ] While loading, the usual skeleton shows. A failure shows the usual
  error with Retry.
- [ ] With `configured: false`:
  - a note says "Generated voices aren't set up on this server. Add
    ADDIS_API_KEY to the backend's environment.";
  - the cards show the saved IDs read-only;
  - there is no Save and no Try it, and the catalog is not called.

### 013-language-voice-card (FR-13)

**As an** admin, **I want** to pick a male voice, a female voice and a
speed per language, **so that** every generated clip in that language
sounds consistent.

- [ ] There is one card per language, titled "{language name} · {code}",
  for example "Afaan Oromo · om".
- [ ] The Male voice and Female voice selects list only that gender's
  voices as "{name} · {style}", with the selected voice's descriptor as
  hint text.
- [ ] The Speed slider goes from 0 to 100 in steps of 5:
  - it has "Slower" and "Faster" labels and shows the number;
  - "Reset to 50" sets it back to 50;
  - its help text reads "Small changes are hard to hear; each take also
    varies a little."
- [ ] The last-changed line reads "Last changed by {email},
  {relative time}", or "Default voices" when the language has never
  been saved.
- [ ] Save is disabled until a value changes:
  - it sends PUT, then shows "Saved" for 3 seconds;
  - a server field error shows under its select or the slider;
  - while saving, the button reads "Saving…".
- [ ] Discard returns the card to its saved values.
- [ ] Saving the Amharic card does not reset the Afaan Oromo card's
  unsaved edits.
- [ ] It works at phone width: the controls stack, with no sideways
  scroll.

### 014-try-voices (FR-14)

**As an** admin, **I want** to hear a voice and speed before saving,
**so that** I choose by ear.

- [ ] Each card has a "Sample" textarea that starts with the language's
  sample sentence and allows up to 500 characters.
- [ ] Each voice select has a play button that plays its
  `preview_audio_url`. Starting one preview or try stops any other that
  is playing.
- [ ] "Try male" and "Try female" post generate with `{language, text,
  gender, voice_id: <unsaved select>, speed: <unsaved slider>}` and play
  the returned mp3 from a blob URL. The URL is freed when replaced or
  when the page unmounts.
- [ ] While a try is running, both Try buttons are disabled, and the one
  pressed reads "Generating…".
- [ ] Errors show the server's message in the card.
- [ ] Nothing is saved by trying. A test checks that the settings are
  unchanged.

### 015-missing-voices-and-credit (FR-15)

**As an** admin, **I want** to know when a saved voice is gone, and how
much credit is left, **so that** generation keeps working.

- [ ] If a saved ID is not in the catalog:
  - the select shows "{id} (no longer offered)";
  - a warning reads "Addis AI no longer offers this voice. Choose
    another and save."
- [ ] A credit line shows "Credit: {formatted_balance} · {price} ETB per
  minute of audio". It refreshes after each try.
- [ ] If the usage call fails, the credit line is hidden and nothing
  else breaks.

---

## Dependencies

### Depends On
| Unit | Reason |
|------|--------|
| 001-voice-settings-service | GET and PUT settings |
| 002-addis-voice-client | Catalog and usage |
| 003-voice-generation-api | Try it |

### Depended By
None. Unit 005 reuses this unit's API helpers in `admin/src/voices/api.ts`.

---

## Bolt Suggestions

| Bolt | Type | Stories | Objective |
|------|------|---------|-----------|
| 094-voices-page | simple-construction-bolt | 012, 013 | Page, nav, cards and Save |
| 095-voices-page-try-and-credit | simple-construction-bolt | 014, 015 | Previews, Try it, missing voices and credit |
