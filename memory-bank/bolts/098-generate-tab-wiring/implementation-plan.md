---
stage: plan
bolt: 098-generate-tab-wiring
created: '2026-10-12T17:10:00Z'
---

## Implementation Plan: generate-tab

### Objective

Story 020 (FR-20). The clip fields admins use every day get the Generate
tab, with their own words filled in:

- Workbook items;
- Sounds letters and their example words;
- listening and audio-image exercises.

### What the code says (checked before planning)

- **F1 Workbook.** `workbook/LessonPage.tsx` renders a row editor with
  `language` (the course's learning language) and `draft.text`, the
  item's learning-language words. Its `AudioField` is titled
  "Recording".
- **F2 Sounds.** `sounds/LetterPage.tsx` has two `AudioField`s.
  - "Sound" shows unless the letter plays another letter's recording
    (`sameAs`).
  - "Example word's sound" shows once `draft.example_word` has text.
  - The chart's language is `chart.language` and the letter is
    `draft.glyph`.
- **F3 Exercises.** `exercises/ExerciseForm.tsx` renders `AudioField`
  with `lessonId` for `listening` and `audio_image_choice`.
- **F4 Existing tests.** `audio.test.tsx:177` asserts a listening
  exercise has exactly three tabs. With Generate wired in it has four,
  which is the intended change. Other tests click tabs by name and are
  not affected.
- **F5 Early fetch.** `AudioField` mounts every panel straight away.
  Once wired, the Generate panel would ask for the voice settings as soon
  as any exercise, letter or Workbook page opened, even if the admin
  never opens the tab. In tests that also adds unregistered requests.

### Decisions

- **D1 Workbook.** `LessonPage`'s `AudioField` gets `voice={{ language,
  text: draft.text }}`, so the box follows the item's words as they are
  edited. The hint becomes "Said once, clearly, by a native speaker.
  Record it here, upload a file, paste a link, or generate it."
- **D2 Sound.** The letter's "Sound" field gets `voice={{ language:
  chart.language, text: draft.glyph }}`.
- **D3 Example word.** "Example word's sound" gets `voice={{ language:
  chart.language, text: draft.example_word }}`.
- **D4 Exercises.** Listening and audio-image exercises get
  `voice={{ lessonId }}`. The text starts empty, with the placeholder
  from bolt 096.
- **D5 Lazy panel.** `AudioField` mounts the Generate panel the first
  time the tab is opened, then keeps it mounted like the other panels, so
  a take still survives switching tabs. The voice settings are read only
  when someone opens Generate.
- **D6 Tests.**
  - `audio.test.tsx`: the listening exercise lists Record, Upload, Link
    and Generate.
  - A new `admin/src/audio/generate-wiring.test.tsx` uses `renderApp`
    and the existing fixtures:
    - **Workbook:** Generate is offered and the box holds the row's
      Afaan Oromo or Amharic text. Editing the item's text updates an
      untouched box.
    - **Letter:** both fields offer Generate, with the glyph and the
      example word.
    - **Exercise:** Generate is offered with an empty box. Generate posts
      `lesson_id`.
    - **Lazy panel:** opening a page without opening Generate makes no
      voice-settings request.

### Deliverables

- `admin/src/audio/AudioField.tsx` (D5)
- `admin/src/workbook/LessonPage.tsx` (D1)
- `admin/src/sounds/LetterPage.tsx` (D2, D3)
- `admin/src/exercises/ExerciseForm.tsx` (D4)
- `admin/src/audio/audio.test.tsx` (one assertion) and
  `admin/src/audio/generate-wiring.test.tsx`

### Dependencies

- Bolt 097, complete.

### Acceptance Criteria

- [ ] Workbook items, letters, example words and listening/audio-image
  exercises offer Generate, each with the right text.
- [ ] No voice request is made until Generate is opened.
- [ ] Every other admin test passes unchanged.
- [ ] `npm run lint`, `tsc -b`, `vitest` and `vite build` pass.

## Implement (2026-10-12T17:20:00Z)

- **`admin/src/audio/AudioField.tsx`:** a `generateOpened` flag is set
  the first time the Generate tab is clicked. The panel is rendered only
  after that, then stays mounted.
- **`admin/src/workbook/LessonPage.tsx`:** passes `voice={{ language,
  text: draft.text }}`. The hint now ends "…, paste a link, or generate
  it."
- **`admin/src/sounds/LetterPage.tsx`:**
  - "Sound" passes `voice={{ language: chart.language, text: draft.glyph
    }}`.
  - "Example word's sound" passes `{ language: chart.language, text:
    draft.example_word }`.
- **`admin/src/exercises/ExerciseForm.tsx`:** listening and audio-image
  exercises pass `voice={{ lessonId }}`.
- **`admin/src/audio/audio.test.tsx`:** the listening exercise's tab list
  now includes Generate. This is the intended change.

### Deviations

None.

### Checks

- `tsc -b` and `eslint` pass on the touched folders.
- `vitest run` passes: 41 files, 818 tests. The new wiring tests come in
  Stage 3.

## Test (2026-10-12T17:35:00Z)

I added 4 tests. Each one sits next to the existing tests of its page,
so it reuses that page's fake data. Each file gets a small
`serveVoices()` helper.

- **Workbook** (`src/workbook/lesson.test.tsx`):
  - Generate shows on row W002 with "Female · Loza". The box holds the
    row's words (`ቃል W002`) with `lang="am"`.
  - Editing the row's Amharic text updates the untouched box.
  - No voice settings or catalog are requested until Generate is
    opened.
- **Sounds** (`src/sounds/sounds.test.tsx`): letter ሁ, with the example
  word ሁለት, has two Generate tabs. Their boxes hold ሁ and ሁለት, and one
  settings request serves both.
- **Exercise** (`src/audio/audio.test.tsx`):
  - A listening exercise's Generate starts empty, with the placeholder.
  - Generating posts `lesson_id: lesson-1` and shows "Loza · 1.2 s · not
    stored yet".
  - The tab-list test now expects Generate as a fourth tab.

### Deviations

- **Test placement:** the wiring tests are in the pages' own test files
  rather than a new `generate-wiring.test.tsx`. Those files already
  build the Workbook, Sounds and exercise fixtures.

### Results

- `vitest run`: 41 files and 822 tests pass.
- `npm run lint` and `tsc -b` are clean.
- `vite build` succeeds.
