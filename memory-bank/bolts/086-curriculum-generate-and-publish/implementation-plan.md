---
stage: plan
bolt: 086-curriculum-generate-and-publish
created: '2026-10-05T13:04:00Z'
---

## Implementation Plan: curriculum-admin

### Objective

Stories 013-015 (FR-7, FR-8, FR-9 UI): on a lesson's Workbook page,
generate its exercises from its reviewed and recorded rows with the lesson
CSV import's rules, preview and edit them, and publish the lesson; show
each lesson's publish state on the overview.

### What the code says (checked before planning)

- **F1 `rowToBody(row: CsvRow)`** (`import/fromCsv.ts`) turns one CSV row
  into an `ExerciseBody` for every type, with seeded shuffles; the columns
  are `type, prompt, pronunciation, sentence, answer, answer_pronunciation,
  wrong, wrong_pronunciation, audio_url, descriptions`; `|` separates items.
- **F2 `ExerciseForm({ body, saved, lessonId, onChange })`** edits any body;
  `ExercisePreview({ body })` shows it as the learner sees it.
- **F3 Backend (bolt 085).** `GET` / `PUT .../lessons/{ref}/exercises`
  (409 until ready, 422 by index), `POST .../lessons/{ref}/publish`, and
  the entry's `publish_state`, `published_id`, `exercise_count`.

### Decisions

- **D1 The recipe (`workbook/generate.ts`, pure).** For each word: a
  multiple choice ("How do you say “hello”?") and a listening (its
  recording), each practising the word; a spelling for a word of 2 to 10
  letters. For the lesson: match pairs of its words (2 to 5). For the
  sentence: a sentence construction ("Translate: …"), a gap fill (the word
  to blank) and a listening when another sentence exists for the wrong
  options. Each is a CSV row given to `rowToBody`, so the import's rules
  and shuffles apply; romanizations fill the pronunciation columns.
- **D2 Wrong options** come from the lesson's other words, then the
  skill's, then the section's (3 at most), ordered by a seeded shuffle of
  the row's ref, so generating again gives the same exercises.
- **D3 Keys.** Each generated exercise has a key (`mc:W001`,
  `listen:W001`, `spell:W001`, `pairs`, `build:S001`, `gap:S001`,
  `listen:S001`) kept in `generated`. Generating again replaces only
  unedited exercises; edited ones stay and are listed, each with "Reset to
  generated".
- **D4 The page.** Under the rows, an Exercises section: until every row
  is reviewed and recorded it says what is left; then Generate (or
  Generate again), the list with type, prompt, Edited badge, Preview,
  Edit (a dialog with `ExerciseForm` and the preview), Reset, and Publish
  with the state (Not published / Published / Changed since publish) and
  why it is disabled. After publishing, a link to the course tree.
- **D5 Overview.** Each lesson line shows Published or Changed.

### Deliverables

- `generate.ts`, the Exercises section on `LessonPage`, the overview badge,
  types and routes
- Tests: the recipe on the real workbook's first lesson (every body valid
  in shape, stable, wrong options from the skill), keys and regenerate
  keeping edits; the page (not ready, generate, preview, edit marks
  edited, regenerate keeps it, reset, publish and states)

### Dependencies

- Bolt 085's endpoints; bolt 084's lesson page

### Acceptance Criteria

- [ ] Generate only when every row is reviewed and recorded
- [ ] Built with the CSV import's rules; same result each time
- [ ] Shown in the preview and saved as the lesson's draft exercises
- [ ] Edits mark an exercise edited; regenerating keeps it; Reset undoes it
- [ ] Publish says why it is disabled; after it, the lesson links to the
  tree and the overview shows Published, then Changed after an edit
- [ ] tsc, eslint, build and the admin tests pass

## Implement (2026-10-05T13:08:00Z)

- `admin/src/workbook/generate.ts`: the recipe as CSV rows built by
  `rowToBody` (per word a multiple choice and a listening, a spelling for
  a one-word answer of 2 to 10 letters; the lesson's match pairs; for the
  sentence a sentence construction, a gap fill and a listening), wrong
  options from the lesson, then skill, then section, seeded by ref; keys;
  `regenerate` (keeps edited ones), `reset`, `edited` (compares with
  the generated body, keys sorted).
- `ExercisesPanel.tsx` on the lesson page: what is left until ready;
  Generate / Generate again (saved at once); the list with type, prompt,
  Edited, Preview, Edit (a dialog with `ExerciseForm` and the preview),
  Reset to generated; Publish / Publish again with the state badge and why
  it is disabled; the result with a link to the course tree; every
  exercise's problem from a 422.
- Overview: Published and Changed since publish on each lesson.
- Types (`DraftExercise`, `PublishLessonResult`, publish fields on an
  entry) and routes.
- Checked by hand: the 475 exercises generated for Section 1's 30
  lessons all pass the backend's `validate_exercise` (124 multiple
  choice, 154 listening, 30 match pairs, 107 spelling, 30 sentence
  construction, 30 gap fill).
- Deviation: re-recording a listening clip inside the exercise dialog
  uses the published lesson's upload (none before the first publish); the
  row's own recording is the place to change it.

## Test (2026-10-05T13:11:00Z)

- `src/workbook/generate.test.ts` (5): the real workbook's first lesson
  (every key, prompts, answer with pronunciation, 2-4 choices, the clip,
  the gap); the same result each time; wrong options from the section;
  every Section 1 lesson gives 6 or more; edit, regenerate keeps it, reset.
- `src/workbook/exercises.test.tsx` (5): not ready (no Generate, Publish
  disabled with the reason); generate, save, list and preview; edit marks
  it, regenerate keeps it, reset clears it; publish and the state after;
  the overview badges.
- `src/test/workbook.ts`: the draft exercise and publish endpoints.

Results: `tsc -b` and `eslint .` clean; `vitest run` 773 passed; build
passes.
