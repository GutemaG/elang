---
stage: plan
bolt: 084-curriculum-review-and-record
created: '2026-10-05T12:38:00Z'
---

## Implementation Plan: curriculum-admin

### Objective

Stories 011-012 (FR-5, FR-6): a lesson's page in the Workbook, where the
admin and a native speaker correct each word and sentence, set its status
and comment, and record it (or upload a file), moving on with "Next
unrecorded".

### What the code says (checked before planning)

- **F1 `AudioField`** (`admin/src/audio`) already records (with the
  clean-up and the size before upload), uploads a file or checks a pasted
  link, and takes an `upload` function for audio outside lessons — the
  Sounds letter page uses it that way.
- **F2 The Sounds letter page** is the model for one item's editor: a
  draft, the changes worked out on Save, previous and next, "Saved."
- **F3 Backend (bolt 082).** `PATCH .../rows/{ref}` with `version`
  (`409 content_changed` when stale), `reset_to_draft` in the answer;
  `POST .../audio/uploads` with `row_ref`.
- **F4 Overview (bolt 083)** links each lesson to
  `/courses/:id/workbook/lessons/:ref`.

### Decisions

- **D1 One page per lesson, one row at a time.** The page shows the
  lesson's goal and grammar note, a list of its rows (ref, English, text,
  status, recorded or not), and the chosen row's editor below; the chosen
  row is in the address (`?row=W001`) so a reload keeps it.
- **D2 Order.** "Check first" (Low, then Medium, then the rest, then by
  position) by default, or "In order" (position).
- **D3 The editor.** English, text, romanization (when the course has
  it), and for a sentence the word to blank and other accepted answers (one
  per line); notes; status; reviewer comment; who changed it last and
  when. The word to blank is checked as you type.
- **D4 Saving.** Save sends only what changed, with the row's version.
  Changing the text or romanization of a recorded row shows a warning
  that saving sends it back to Draft; the answer's `reset_to_draft` is
  reported. A `409` says someone else saved it and offers Reload; a 422
  names the field.
- **D5 Recording.** `AudioField` with an `upload` that asks for a link from
  `.../curriculum/audio/uploads` for this row. A new clip goes into the
  draft; Save stores it.
- **D6 Moving on.** Previous and next row; "Save and next unrecorded" goes
  to the next row without audio in this lesson's order, then the first in
  the following lessons; when none is left it says so.
- **D7 Back.** A breadcrumb to the Workbook and the course's workbook.

### Deliverables

- `admin/src/workbook/LessonPage.tsx`, `rows.ts` (draft, changes, order,
  next unrecorded); route in `App.tsx`
- Tests for the page and the helpers

### Dependencies

- Bolt 082's row edit and upload endpoints; bolt 083's overview

### Acceptance Criteria

- [ ] Rows listed Low then Medium first, or in order
- [ ] Every field, status and comment can be saved; only changes are sent,
  with the version
- [ ] Word-to-blank and the server's 409 / 422 shown in words
- [ ] A recorded row's text change warns, then reports going back to Draft
- [ ] Each row shows who changed it last and when
- [ ] Record, play, record again, save; or choose a file; size before upload
- [ ] "Next unrecorded" goes on through the lesson, then the next lessons
- [ ] tsc, eslint and the admin tests pass

## Implement (2026-10-05T12:42:00Z)

- `admin/src/workbook/rows.ts`: the draft of a row, the changes Save
  sends, whether they send a recorded row back to Draft, the word-to-blank
  check, the "check first" order, and the next unrecorded row (this
  lesson, then later lessons, then any skipped earlier here).
- `LessonPage.tsx` (route `/courses/:id/workbook/lessons/:ref`): the
  lesson's goal and grammar, its rows (status, Low / Medium, recorded),
  the chosen row in the address, the row editor (words, recording through
  `AudioField` with the curriculum upload link, review), previous / next
  row and lesson, Save and "Save and next unrecorded", the Draft warning,
  409 with Reload, 422 naming the field, a notice kept across the
  editor's restart after each save.
- `App.tsx`: the route.
- Deviation: none. The recording goes into the draft and Save stores it,
  as on the Sounds letter page.

## Test (2026-10-05T12:43:53Z)

- `src/workbook/lesson.test.tsx` (10): order (least sure first, or in
  order); save sends only the changes with the version, and shows who
  changed it; the Draft warning and the reset notice; 409 then Reload; the
  word-to-blank check disables Save; uploading a file for the row (link
  asked with `row_ref`) then saving it; "Next unrecorded" into the next
  lesson; previous / next lesson and the breadcrumb; a lesson not in the
  workbook; `nextUnrecorded` and `ordered`.
- `src/test/workbook.ts`: the row edit (version check, reset) and upload
  endpoints added.

Results: `tsc -b` and `eslint .` clean; `vitest run` 763 passed; build
passes.
