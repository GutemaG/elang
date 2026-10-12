---
unit: 005-generate-tab
intent: 027-generated-voice-audio
unit_type: frontend
default_bolt_type: simple-construction-bolt
phase: inception
status: complete
created: '2026-10-12T09:55:00Z'
updated: '2026-10-12T09:55:00Z'
---

# Unit Brief: Generate Tab

## Purpose

Add a fourth way to get a clip in every clip field. The admin types or
keeps the text, chooses a voice, generates, trims and uses the clip.

## Scope

### In Scope
- **`AudioField`:** a `voice?: { language?; lessonId?; text? }` prop and
  a Generate tab, shown only when `voice` is given.
- **`GeneratePanel`** in `admin/src/audio/`, with:
  - text, a counter, the voice choice, speed and Generate;
  - the take in `ClipEditor`;
  - Generate again, Discard and Use this clip.
- **Helpers:**
  - a `generateClip(api, body)` helper that returns `{blob, voiceId,
    voiceName, seconds}`;
  - a hook that reads `configured` and the language settings once per
    page load, shared by every field on the page;
  - the gender choice remembered in `localStorage`, inside try/catch.
- **Callers:** the Workbook item recording, the Sounds letter fields
  (both), and the listening and audio-image exercise audio.
- Tests in `admin/src/audio/audio.test.tsx`, or a new `generate.test.tsx`
  next to it.

### Out of Scope
- Changes to `ClipEditor`, cleaning or effects themselves.
- The generated-clip label (unit 006).

---

## Assigned Requirements

| FR | Requirement | Priority |
|----|-------------|----------|
| FR-16 | The tab | Must |
| FR-17 | Generate controls | Must |
| FR-18 | Check and trim the take | Must |
| FR-19 | Use the take | Must |
| FR-20 | Fields that offer Generate | Must |

---

## Stories

| Story ID | Title | Priority | Status |
|----------|-------|----------|--------|
| 016-generate-tab | A Generate tab beside Record, Upload and Link | Must | Planned (bolt 096) |
| 017-generate-controls | Text, voice, speed and Generate | Must | Planned (bolt 096) |
| 018-trim-generated-take | A take opens in the clip editor with silence cut | Must | Planned (bolt 097) |
| 019-use-generated-take | Keep a take as the clip, like an upload | Must | Planned (bolt 097) |
| 020-generate-in-every-field | Workbook, Sounds and exercises offer Generate with their text | Must | Planned (bolt 098) |

### 016-generate-tab (FR-16)

**As an** admin, **I want** Generate next to the ways I already know,
**so that** I can choose it for any clip.

- [ ] With a `voice` prop, the tablist shows Record, Upload, Link and
  Generate, the last with icon `record_voice_over`. Without the prop
  there are three tabs, as today, and the existing tests pass unchanged.
- [ ] The Generate panel stays mounted when the admin switches tabs, so
  a take survives a trip to Record and back.
- [ ] For a language other than `am` or `om`, the panel shows only
  "Generated voices are not available for {language}."
- [ ] With `configured: false`, the panel shows only "Generated voices
  aren't set up on this server. Record or upload instead."
- [ ] `configured` and the settings are fetched once per page load, even
  when the page has two clip fields, such as a letter and its example
  word.

### 017-generate-controls (FR-17)

**As an** admin, **I want** the text filled in and the voice chosen,
**so that** most clips need just one press.

- [ ] The Text box starts with `voice.text` and has `lang` set to the
  field's language. It shows "{n} / 500", and the counter turns red over
  500.
- [ ] If `voice.text` changes while the box is untouched, the box
  follows it. Once the admin has typed in the box, it keeps their text.
- [ ] There are two voice buttons, for example "Male · Diriba" and
  "Female · Obse". The names come from the settings plus the catalog,
  and fall back to the voice ID.
- [ ] The voice choice is kept in `localStorage` under
  `buna.admin.voiceGender`, with Female as the default. A blocked
  storage still works, with Female as the default.
- [ ] The Speed slider starts at the language's saved speed, runs 0–100
  in steps of 5, and has a Reset button. It changes only this field's
  takes.
- [ ] Generate is disabled when the text is empty or over 500 characters,
  or while a take is running, when it reads "Generating…".
- [ ] Generate posts `{language | lesson_id, text, gender, speed}` and
  receives the blob and the `X-` headers.

### 018-trim-generated-take (FR-18)

**As an** admin, **I want** a generated take trimmed like a recording,
**so that** a 5-second take whose speech ends at 2 seconds is kept as
about 2 seconds.

- [ ] The take is passed to `useCleaning` and `ClipEditor`, the same as
  in `RecordPanel` and `UploadPanel`:
  - the silence is cut automatically;
  - the handles and sliders move the cut;
  - volume evening and effects are offered.
- [ ] The editor's original option reads "As generated" in this panel.
  Record and Upload keep their own wording.
- [ ] Below the editor: "{voice name} · {duration} · not stored yet".
- [ ] Generate again replaces the take and resets the cut. Cleaned or
  not, and the chosen effects, carry over.
- [ ] Discard clears the take and keeps the text, voice and speed.
- [ ] A failed Generate again shows the error and keeps the previous
  take.

### 019-use-generated-take (FR-19)

**As an** admin, **I want** to keep a take as the item's clip,
**so that** it is saved like everything else.

- [ ] "Use this clip" runs the same `useClipUpload` path as Upload, with
  the cleaned or as-generated clip, the 5 MB check and the same
  messages.
- [ ] On success the current clip shows the new address with "Not saved
  yet", and the take is cleared.
- [ ] While uploading, the button reads "Uploading…" and the page's busy
  state holds Save.
- [ ] Generating never changes a Workbook item's status field.

### 020-generate-in-every-field (FR-20)

**As an** admin, **I want** Generate in every place I add audio,
**so that** I can fill words, letters and exercises the same way.

- [ ] Workbook `LessonPage` passes `voice={{ language, text: draft.text
  }}`.
- [ ] `LetterPage`, "Sound", passes `voice={{ language: chart.language,
  text: <the letter as written> }}`.
- [ ] `LetterPage`, "Example word's sound", passes `voice={{ language:
  chart.language, text: <the example word> }}`.
- [ ] `ExerciseForm`, for listening and audio-image exercises, passes
  `voice={{ lessonId }}`. The text starts empty, with the placeholder
  "Type the words the learner should hear".
- [ ] An English (A–Z) chart's letters show the not-available note.
- [ ] A test per caller checks that the Generate tab is present and the
  text box is filled in correctly.

---

## Dependencies

### Depends On
| Unit | Reason |
|------|--------|
| 001-voice-settings-service | `configured`, the voices and the speed |
| 003-voice-generation-api | Generate |
| 004-voices-admin-page | Reuses `admin/src/voices/api.ts`. If unit 005 is built first, it creates that file and 004 extends it. |

### Depended By
| Unit | Reason |
|------|--------|
| 006-generated-clip-label | Passes the source tag on "Use this clip" |

---

## Bolt Suggestions

| Bolt | Type | Stories | Objective |
|------|------|---------|-----------|
| 096-generate-tab-controls | simple-construction-bolt | 016, 017 | The tab and its controls, up to a playable take |
| 097-generate-tab-editor-and-use | simple-construction-bolt | 018, 019 | Editor, Generate again, Discard and Use this clip |
| 098-generate-tab-wiring | simple-construction-bolt | 020 | The Workbook, Sounds and exercise callers |
