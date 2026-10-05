---
stage: plan
bolt: 083-curriculum-import
created: '2026-10-05T12:24:00Z'
---

## Implementation Plan: curriculum-admin

### Objective

Stories 007-010 (FR-2, FR-3 preview, FR-4, FR-10): the admin site's
place for a course's curriculum workbook: the overview with progress,
reading the workbook in the browser, the import preview and confirm, and
export to Excel. Reviewing and recording a lesson's rows is bolt 084.

### What the code says (checked before planning)

- **F1 "Curriculum" is taken.** The nav's Curriculum is the course tree
  (`/`, `/courses/:id`); `AppShell` decides the current item by path,
  with Vocabulary carved out of `/courses/...`.
- **F2 Course pages.** `CourseList` takes a `purpose` (curriculum,
  vocabulary) that sets its copy and where a course opens;
  `VocabularyPage` is the model for a course page (load, 404, retry).
- **F3 Import dialogs.** The Sounds chart's CSV import reads the file,
  shows a `Modal` with what will change and the problems, then applies.
  `saveFile` saves text only.
- **F4 Tests.** `renderApp` + `FakeServer` (routes by method and path).
- **F5 The workbook.** Tabs Plan, Words, Sentences; IDs like
  `S1-U06-L1`, `W001`, `S001`; the Section cell reads
  "Section 1 · First conversations (A1.1)"; numbers come back as numbers;
  status and confidence are labels ("Needs change", "Medium"); Oromo has
  no romanization column; one Reviewer comments column.
- **F6 Backend (bolt 082).** `GET/PUT .../curriculum` (dry run, problems
  by ref), counts per lesson, `course_title`.

### Decisions

- **D1 Name: "Workbook".** A nav item "Workbook" under Workspace
  (`/workbook`, the course list with purpose `workbook`), and a course's
  page at `/courses/:id/workbook`. Lesson pages (bolt 084) live under it.
- **D2 Libraries.** `read-excel-file` (reads every tab in the browser)
  and `write-excel-file` (writes the export), both small and built on
  `fflate`. Wrapped in `workbook/files.ts` so tests can read the real
  workbook with the Node build.
- **D3 Reading (`workbook/model.ts`, pure).** `parseWorkbook(sheets,
  language)` returns entries, rows, problems (tab, row number, message)
  and the skipped Section 0 count.
  - Headers matched by name after trimming and ignoring case; a missing
    tab or header is a problem that stops the import.
  - Columns by course language: Amharic (`am`) reads "Amharic (Fidel)",
    "Amharic romanization", "Amharic word to blank", "Other accepted
    Amharic", the Amharic confidence and status, "Grammar: Amharic";
    Afaan Oromo (`om`) reads the Oromo ones and has no romanization. Any
    other language is refused with a message.
  - Plan rows make a section (`S1`, title after "·", position = its
    number), a skill (`S1-U06`, position = Skill #) and a lesson
    (position = Lesson #). Section 0 is skipped and counted.
  - A lesson's rows are its words in file order, then its sentence.
  - Labels to keys: To do / Draft / Needs change / Reviewed, and High /
    Medium / Low (any case; blank is To do / none). Others are problems.
  - Other accepted answers split on `|`.
- **D4 Preview.** Choosing a file reads it, then sends it as a dry run.
  The dialog shows added / changed / kept / unchanged for rows and plan,
  the rows kept because reviewed or recorded, rows not in the file, and
  every problem (the reader's, and the server's mapped back to tab and
  row number by ref). "Overwrite reviewed rows" is off; turning it on
  runs the dry run again. Import sends the same request for real.
- **D5 Overview.** The page lists sections, their skills and lessons in
  order; each lesson shows filled / reviewed / recorded out of its rows
  with a bar, and needs-change when any; sections and skills add up
  their lessons. Stat cards for the totals. Filters: All, Ready to
  publish (every row reviewed and recorded), Needs change. An empty
  course shows what to do and an Import button. Publish state arrives
  with bolt 085/086.
- **D6 Export.** "Export to Excel" writes Plan, Words and Sentences with
  the workbook's headers; the course's language columns are filled, the
  other language's left empty; Audio is Y/N. Re-importing it into the same
  course changes nothing.

### Deliverables

- `admin/src/workbook/`: `model.ts`, `files.ts`, `WorkbookPage.tsx`,
  `ImportDialog.tsx`; types in `types.ts`; routes in `tree/levels.ts`;
  nav item and routes
- Tests: model (the real A1 workbook: 66 lessons in 22 skills, 268 words,
  66 sentences, 3 skipped; Oromo columns; problems; export round trip) and
  the page (overview, filters, empty state, preview, overwrite, problems,
  confirm, export)

### Dependencies

- `read-excel-file@9.3.10`, `write-excel-file@4.1.1` (npm)
- Bolt 082's endpoints

### Acceptance Criteria

- [ ] A Workbook nav item and page per course; an empty one offers the
  import
- [ ] The A1 workbook reads in under 3 s and gives the counts above
- [ ] The preview shows the dry run's answer and all problems; nothing is
  saved until Import
- [ ] Overwrite is off by default
- [ ] The overview shows counts per lesson, skill and section, and the
  filters work
- [ ] The export re-imports with no changes
- [ ] tsc, eslint, build and the admin tests pass

## Implement (2026-10-05T12:33:00Z)

- `admin/src/workbook/model.ts`: reading the Plan, Words and Sentences
  tabs for a course language (headers by name, labels to keys, Section 0
  skipped, a lesson's words then its sentence, where each ref came from),
  pointing the server's problems at rows, writing the tabs back out, the
  outline and its sums, "ready".
- `files.ts`: `readWorkbook` (read-excel-file) and `saveWorkbook`
  (write-excel-file, header row kept in view); loaded only when a file is
  chosen or saved, so the libraries are their own 120 kB chunk.
- `ImportDialog.tsx`: the dry run's tallies, kept and missing rows, the
  overwrite switch (runs the dry run again), every problem by tab and row;
  Import sends the same request for real.
- `WorkbookPage.tsx`: header with Import and Export, stat cards, filters,
  sections > skills > lessons with reviewed and recorded bars, the empty
  state. Lesson lines link to `/courses/:id/workbook/lessons/:ref`
  (bolt 084).
- Types, API routes, the Workbook nav item (`AppShell`), the course list's
  `workbook` purpose, routes in `App.tsx`. Backend: `course_title` added
  to the curriculum read.
- Dependencies: `read-excel-file@9.3.10`, `write-excel-file@4.1.1`.

## Test (2026-10-05T12:36:51Z)

- `src/workbook/model.test.ts` (9): the real A1 workbook for Amharic (2
  sections, 22 skills, 66 lessons, 268 words, 66 sentences, 3 skipped,
  under 3 s) and Afaan Oromo (no romanization); an unknown language; a
  missing tab or column; bad rows by row number; export reads back the
  same in both languages; Audio Y/N and the other language empty; file
  name; outline sums and "ready".
- `src/workbook/workbook.test.tsx` (10): the menu and course list; the
  empty state; the preview (dry run first, nothing saved, Section 0
  noted), then Import and the lessons shown; overwrite re-checks; the
  file's problems (nothing sent); the server's problems by row; a file
  that is not a workbook; progress per lesson, skill and course; filters;
  export.
- `src/test/workbook.ts`: a small curriculum, a small workbook and the
  curriculum endpoints, for this bolt and the next.

Results: `tsc -b` and `eslint .` clean; `vitest run` 753 passed; build
passes (the main chunk's size warning was there before).
