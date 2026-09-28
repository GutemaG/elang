---
stage: plan
bolt: 056-exercise-import
created: '2026-09-28T20:43:39Z'
---

## Implementation Plan: exercise-import

### Objective

- **Import:** a lesson's exercises come from a `.csv` or `.json` file (or
  pasted text). You check them in a preview, then add them in one step.
- **Export:** a lesson's exercises download as CSV or JSON, so they can be
  edited and imported back.

### The user's decisions (2026-09-28)

- **U1:** Both formats.
- **U2:** One file fills one lesson. For several lessons, import into each
  lesson in turn.
- **U3:** Export is in this bolt.

### What the code says (checked before planning)

- **F1: One exercise at a time.**
  - `POST /admin/lessons/{id}/exercises` creates one exercise.
    `create_exercise` in `admin_content_use_cases.py` runs
    `validate_exercise`, appends at `next_order_index` and logs one
    `admin_write`.
  - `validate_exercise` stops at the first bad field
    (`InvalidExerciseError`, `422`, `details.field`).
- **F2: One transaction per request.** The session dependency commits at
  the end of a request and rolls back if anything raises. The repository
  never commits itself. A loop of creates in one request is therefore
  all or nothing.
- **F3: Choice order is display order.** The app shows choices, word-bank
  words and spelling tiles in the order they are stored. A converted
  spreadsheet row must not always put the answer first.
- **F4: Nothing references an exercise.** `delete_exercise` needs no guard.
  Replacing a lesson's exercises loses nothing else.
- **F5: Media must already be uploaded.** `audio_url` and picture
  `image_url` must be `https://` addresses (or local media in development).
- **F6: No file-reading library in the admin site.** Excel on Windows can
  save a plain "CSV" in the ANSI code page, which breaks Ethiopic text.
  "CSV UTF-8" keeps it.

### Decisions

- **D1: Where it lives.**
  - Each open lesson gets **Import** and **Export** buttons next to "Add
    exercise". An empty lesson's "No exercises yet." offers "Import from a
    file" too.
  - Import is a page, `/courses/:courseId/lessons/:lessonId/import`, like
    the exercise editor. A preview table needs the room, and "Back to
    lesson" returns to the open tree (bolt 055).
  - Export is a small menu (JSON, CSV) that downloads at once. It is
    disabled while an order is unsaved, like the other edits.
- **D2: CSV, one row per exercise, the same columns for every type.**

  | Column | Meaning |
  |---|---|
  | `type` | `multiple_choice`, `listening`, `gap_fill`, `sentence_construction`, `spell_tiles`, `match_pairs`, `image_choice`, `audio_image_choice`. The name shown in the admin site ("Gap fill") is accepted too. |
  | `prompt` | The question. Required. |
  | `sentence` | Gap fill only. `___` (three or more underscores) marks the gap, exactly once. |
  | `answer` | See below. |
  | `wrong` | Wrong choices, extra words or extra tiles, separated by `\|`. |
  | `audio_url` | Listening and audio image choice. |
  | `descriptions` | Picture types, optional. Descriptions for `answer`, then each `wrong` picture, separated by `\|`. |

  `answer` by type:

  - **Choice types** (multiple choice, listening, gap fill): the correct
    choice.
  - **Sentence:** the words in order, separated by `\|`. With no `\|`,
    by spaces.
  - **Spell tiles:** the tiles in order, separated by `\|`. With no `\|`,
    one tile per character (each Ethiopic letter such as ቡ is one
    character).
  - **Match pairs:** `left=right` pairs, separated by `\|`.
  - **Picture types:** the image address of the correct picture. `wrong`
    holds the other addresses.

  Other rules:

  - Header names ignore case and spaces, and columns may come in any
    order. Unknown columns are an error ("Unknown column 'answr'"), so a
    typo is not silently dropped.
  - An empty row is skipped.
  - Items are trimmed; an empty item is dropped. `\\|` is a literal `|`.
  - Parsed with **Papa Parse** (`papaparse`, MIT, no dependencies). It
    handles quotes, commas and line breaks in cells, and a byte-order
    mark.
  - A file that isn't UTF-8 (it has `U+FFFD` in it) is refused: "This
    file isn't saved as UTF-8, so Amharic text would be lost. In Excel
    choose File › Save As › CSV UTF-8."
- **D3: CSV rows become exercises in the browser.**
  - New `src/import/fromCsv.ts` turns each row into the stored
    `ExerciseBody`. Ids follow the editor's own convention (`a`, `b`…,
    `w1`…, `t1`…, `l1`/`r1`).
  - Choices, the word bank and the tiles are **shuffled with a seed** from
    the row's text. The answer is not always first, and the same file
    always gives the same order. Match pairs are left in order: the app
    shuffles its two columns itself.
  - A row it cannot convert (no answer, a gap fill with no `___`, a pair
    without `=`) gets a message naming the row and column. The server
    receives only whole exercises.
- **D4: JSON is the stored shape.**
  - Either a list of `{type, prompt, content, answer_key}`, or the export
    file: `{"format": "buna-exercises", "version": 1, "lesson": "...",
    "exercises": [...]}`.
  - Taken exactly as written: no shuffling, ids kept. Extra keys such as
    `id` or `order_index` from an export are ignored.
- **D5: A new endpoint checks and saves the whole file.**
  `POST /admin/lessons/{id}/exercises/import`

  ```json
  {"exercises": [ExerciseRequest, ...], "mode": "append" | "replace", "dry_run": false}
  ```

  - Every exercise goes through `validate_exercise`, and **every** failure
    is collected, not just the first. Any failure → `422 invalid_import`
    with `details.rows: [{index, field, message}]`, and nothing is
    written.
  - Between 1 and 200 exercises, or `422`.
  - `dry_run: true` checks and returns `200 {"count": n}`, writing
    nothing. The preview uses it.
  - `append` adds after the lesson's last exercise, in file order.
    `replace` deletes the lesson's exercises first, in the same
    transaction.
  - Returns `201` with the lesson's exercises (`AdminExerciseList`).
  - One `admin_write` log line per exercise, as the single create does.
  - The one-at-a-time endpoints are unchanged.
- **D6: The import page.**
  1. Choose a file, or paste CSV or JSON. The format is picked from the
     file's extension, or for pasted text from its first character (`[`
     or `{` means JSON).
  2. The preview table: row number, type, prompt, answer, and ✓ or the
     problem.
     - Conversion problems show at once.
     - The rest come from the dry run, placed on their rows through the
       existing `plainMessage`.
     - Each row can open the existing `ExercisePreview` (the learner's
       view).
  3. "Add to the end" (the default) or "Replace the N exercises in this
     lesson". Replace asks for confirmation, naming the count.
  4. **Add 24 exercises** is enabled only when every row passes. Then it
     goes back to the lesson, open, with a banner "Added 24 exercises."
  - A help panel lists the columns with an example for each type, plus
    **Download CSV template** and **Download JSON example**.
  - The file is read in the browser and limited to 1 MB.
  - Leaving with a checked but unsaved file asks first, as the editor does.
- **D7: Export.**
  - **JSON:** the export file in D4, from
    `GET /admin/lessons/{id}/exercises`, pretty-printed.
  - **CSV:** the D2 columns, with `|` joining items and `\|` for a literal
    `|` in text. Written as UTF-8 with a byte-order mark, so Excel shows
    Amharic.
  - Files are named `<lesson-title>-exercises.json` / `.csv`.
  - **Round trip:** exporting and re-importing gives the same exercises.
    - JSON is identical.
    - CSV has the same text and answers; choice ids and order may differ.
- **D8: Templates are made in code** from the same examples the help
  panel shows, one row per type. They are not static files, so they
  cannot drift from the reader.
- **D9: Not in this bolt.**
  - Uploading pictures or audio inside an import.
  - Filling several lessons from one file (U2).
  - Linking exercises to Practice words.
  - Importing sections, skills or lessons.

### Files

- **Backend**
  - `app/application/admin_content_use_cases.py`: `import_exercises(repo,
    ctx, lesson_id, items, *, mode, dry_run)`.
  - `app/domain/lesson/exceptions.py`: `InvalidImportError` (422,
    `invalid_import`), mapped in `error_handlers.py`.
  - `app/infrastructure/api/admin_schemas.py`: `ExerciseImportRequest`,
    `ExerciseImportCheck`.
  - `app/infrastructure/api/admin_routers.py`: the route.
  - Tests: new `tests/unit/test_exercise_import.py` and
    `tests/integration/test_exercise_import_api.py`.
    - All or nothing; several failures reported at once.
    - Limits; append and replace; dry run writes nothing.
    - Order indexes; non-admin refused.
- **Admin site**
  - `package.json` and the lock file: `papaparse`, `@types/papaparse`.
  - New `src/import/`:
    - `csvFormat.ts`: columns, splitting and joining, seeded shuffle.
    - `fromCsv.ts`: rows → exercises.
    - `toCsv.ts`: exercises → rows.
    - `json.ts`: read and write the JSON file.
    - `templates.ts`: the examples.
    - `download.ts`: saves a file.
    - `ImportPage.tsx`: the page.
    - `ExportMenu.tsx`: the menu.
    - Tests for each.
  - `src/App.tsx`: the import route.
  - `src/tree/CourseTree.tsx` and `src/tree/ExerciseList.tsx`: the Import
    and Export buttons, the empty-lesson link, the "Added n exercises"
    banner.
  - `src/tree/levels.ts`: the import route.
  - `src/types.ts`: request and response types.
- **Docs**
  - `database-schema.md`: no change (no new tables).
  - Unit 001 and 002 briefs: import and export are in scope.
  - Both construction logs.

### Acceptance criteria

- **A. CSV import**
  - [ ] A CSV with one row of each of the 8 types imports into a lesson,
    and each exercise plays as written (checked through the preview).
  - [ ] Choices, word-bank words and tiles are not always in answer order,
    and the same file gives the same order every time.
  - [ ] Problems are shown on their row before anything is saved:
    - An unknown type or column, or a missing prompt or answer.
    - A gap fill without exactly one `___`, a pair without `=`.
    - A server rule, e.g. an answer that isn't `https://`.
  - [ ] A non-UTF-8 file is refused with the "CSV UTF-8" advice.
  - [ ] Quoted cells with commas and line breaks, a byte-order mark, and
    columns in any order all read correctly.
- **B. JSON import**
  - [ ] A list of stored exercises, or an export file, imports exactly
    (ids and order kept).
  - [ ] Invalid JSON, or an object that isn't one of the two shapes, gets
    a clear message.
- **C. Saving**
  - [ ] Nothing is saved if any row fails, on the server too (all or
    nothing).
  - [ ] "Add to the end" keeps the existing exercises and adds after them,
    in file order.
  - [ ] "Replace" asks first, then leaves exactly the imported exercises.
  - [ ] More than 200 exercises, or a file over 1 MB, is refused.
  - [ ] After saving, the lesson is open in the tree with "Added n
    exercises."
- **D. Export**
  - [ ] JSON and CSV download with the lesson's name.
  - [ ] Re-importing an exported JSON gives identical exercises. An
    exported CSV gives the same prompts, answers and choices.
  - [ ] The CSV opens in Excel with Amharic intact (byte-order mark).
- **E. Help**
  - [ ] The CSV template and JSON example download, and import cleanly
    as they are.
- **F. Checks**
  - [ ] Admin lint, build and tests pass; backend tests and ruff pass.
  - [ ] The import page works at 360 px wide: the table scrolls inside
    its own box, not the page.

### Deploy

Backend and admin site. There is no database change and nothing on Neon,
and the app is unchanged.

---

## Implementation Notes (Stage 2)

Plan approved 2026-09-28, as written, except where noted below.

### Backend

- **`import_exercises` and `check_import`** in `admin_content_use_cases.py`.
  - `check_import` runs `validate_exercise` on every exercise and collects
    each failure as `{index, field, message}`. Any failure raises
    `InvalidImportError` (`422 invalid_import`, message "2 of 4 exercises
    cannot be saved", `details.rows`).
  - Fewer than 1 or more than `IMPORT_MAX` (200) exercises is
    `InvalidContentError` on the field `exercises`.
  - `import_exercises` checks first. With `replace` it deletes the
    lesson's exercises, then adds the new ones from `next_order_index` in
    file order, touches the lesson (`content_version`) and returns the
    list.
  - One `admin_write` line per deleted and per created exercise; content
    never goes in the log.
- **The route** `POST /admin/lessons/{id}/exercises/import`: `201` with
  `AdminExerciseList`, or `200 {count}` for `dry_run`.
  - `ExerciseImportRequest` (`exercises`, `mode`: `append` | `replace`,
    `dry_run`) and `ExerciseImportCheck`.
  - The router-level admin check covers it, and the existing "every admin
    endpoint refuses a non-admin" test picks it up automatically.
- **Known:** an exercise linked to a Practice word (`vocab_item_id`, from
  the seed) loses that link when a Replace deletes it. A single delete
  already does the same.

### Admin site

- **New `src/import/`:**
  - `csvFormat.ts`: the columns; `columnOf` and `typeOf` for loose header
    and type names; `splitItems` and `joinItems` (`|`, with `\|` for a
    literal bar); `charactersOf` (grapheme clusters through
    `Intl.Segmenter`); `seededShuffle` (FNV-1a seed into mulberry32, then
    Fisher-Yates); `writeCsv` (byte-order mark, CRLF, every column).
  - `fromCsv.ts`: `readCsv`, `rowToBody` and the per-type rules.
    - The seed is every cell of the row, so editing the row may reorder
      its choices and nothing else does.
    - A type refuses a cell it doesn't use ("Multiple choice doesn't use
      "audio_url"; leave it empty.") rather than dropping it.
    - Rows are labelled as a spreadsheet numbers them (header = row 1);
      blank rows are skipped but still counted.
  - `toCsv.ts`: `bodyToRow` and `exercisesToCsv`. Sequences and pairs
    are always joined with `|`, so tiles of several letters survive.
  - `json.ts`: `readJson` (a list, or any object with an `exercises`
    list) and `exercisesToJson`. Each item's type is left to the server,
    so an unknown type shows on its row like any other server problem.
  - `templates.ts`: `EXAMPLES` (one row per type), `csvTemplate()` and
    `jsonExample()`, which is the CSV rows converted.
  - `download.ts`: `fileName`, `saveFile`, and `readText`. `readText` uses
    `FileReader`, which decodes as UTF-8 and turns bad bytes into U+FFFD
    for the UTF-8 check.
  - `ImportPage.tsx`: the page (D6).
  - `LessonTools.tsx`: Import, Export CSV and Export JSON.
- **Change from D1:**
  - The three buttons sit at the top of the open lesson, above its
    exercises, not beside "Add exercise" in the row. The row has no room
    for three more buttons on a phone.
  - Export is two buttons rather than a menu: one tap, nothing to
    position.
- **Import page details:**
  - A file's format comes from its extension (`.json`, anything else is
    CSV). Pasted text is JSON if it starts with `[` or `{`.
  - Rows that became exercises are dry-run together. The server's row
    indexes are mapped back to the file's rows. A CSV row shows the
    server message without its field path (`plainMessage`); a JSON row
    shows it whole, since its writer knows the fields.
  - A check that returns after a newer file was chosen is ignored.
  - Replace is offered only when the lesson has exercises. It asks in a
    dialog naming both counts and suggests exporting first.
  - After adding, it goes to `/courses/:id?open=<lesson>` with router
    state `{imported: n}`. The tree shows "Added n exercises." once, then
    clears the state so a reload or a later Back doesn't repeat it.
- **Dependency:** `papaparse` 5.7 (and `@types/papaparse`). The bundle is
  463 kB (142 kB gzip), up from 416 kB.
- **Formatting:** the site has no Prettier config. New files are formatted
  with `--single-quote --no-semi --print-width 120`. Existing files were
  edited by hand only.

### Docs

- Unit 001 and 002 briefs: import and export are in scope.
- `database-schema.md`: no change (no new tables or columns).

## Checks (Stage 2)

- **Admin:** `tsc` and `eslint .` clean. `vitest run` 611 passed (21
  files), 77 of them new in `src/import/`. `npm run build` clean.
  After the review below: 612 passed.
- **Backend:** the new `test_exercise_import_api.py` has 16 tests, and it
  passes with `test_admin_content_endpoints.py` (72 passed). `ruff check`
  and `ruff format` clean. Full suite: 1299 passed (1282 before, plus 17 new).

### Review at the Implement checkpoint (2026-09-28)

The user approved Implement and asked for two things to be easy to find:
previewing the file's questions before submitting, and downloading a
sample file.

- **Samples:** "Sample CSV" and "Sample JSON" now sit in the file card at
  the top of the page ("Start from a sample, one exercise of each type"),
  not inside the collapsed help. The files are `exercises-sample.csv` and
  `exercises-sample.json`. The help keeps the column guide and the example
  table.
- **Preview:** each checked row has a labelled "Preview" button (it was an
  eye icon alone). It opens the learner's view of that exercise. Nothing
  is sent to be saved.

---

## Test Report (Stage 3)

Implement approved 2026-09-28.

### Runs

| Suite | Result |
|---|---|
| Admin `vitest run` | 612 passed, 22 files; 78 in `src/import/` |
| Admin `tsc`, `eslint .`, `npm run build` | clean (bundle 463 kB, 142 kB gzip) |
| Backend `pytest` (full) | 1299 passed |
| Backend `ruff check`, `ruff format` | clean |

### Acceptance criteria

- **A. CSV import**
  - [x] One row of each of the 8 types converts, and each reads back to
    the same meaning (`csv.test.ts`, "reading a CSV file" and the round
    trips). The sample CSV imports with no problems (`json.test.ts`).
  - [x] Choices, words and tiles are not always in answer order; the same
    row gives the same order (`csv.test.ts`).
  - [x] Problems show on their row before saving: unknown type or column,
    missing prompt or answer, a gap fill without exactly one `___`, a pair
    without `=`, and a server rule mapped back to its row
    (`importPage.test.tsx`, "shows every problem on its row").
  - [x] A non-UTF-8 file is refused with the "CSV UTF-8" advice.
  - [x] Quoted cells with commas, quotes and line breaks, a byte-order
    mark, and columns in any order read correctly.
- **B. JSON import**
  - [x] A list, or an export file, is taken exactly; extra keys dropped.
  - [x] Invalid JSON, or the wrong shape, gets a clear message.
- **C. Saving**
  - [x] All or nothing on the server: a refused import or replace leaves
    the lesson as it was (`test_exercise_import_api.py`).
  - [x] Add goes after the existing exercises, in file order, numbered
    1..n.
  - [x] Replace asks first, then leaves exactly the imported exercises.
  - [x] More than 200 exercises is refused, on the page and by the API.
    Over 1 MB is refused on the page (not tested: jsdom can't make a
    large file cheaply; the check is one comparison).
  - [x] Back in the tree with the lesson open and "Added n exercises."
- **D. Export**
  - [x] CSV and JSON download, named after the lesson.
  - [x] A JSON export reads back identical; a CSV export gives the same
    prompts, answers and choices.
  - [x] The CSV starts with a byte-order mark (checked by its bytes).
- **E. Samples and preview**
  - [x] Sample CSV and Sample JSON download from the top of the page, and
    both import cleanly.
  - [x] A row's Preview shows the learner's view before anything is
    saved.
- **F. Checks**
  - [x] Admin lint, build and tests; backend tests and ruff.
  - [ ] The page at 360 px wide: the table scrolls inside its own box
    (`overflow-x-auto`). Not seen in a browser yet.

### Left for a person

- Import a real spreadsheet saved from Excel as **CSV UTF-8**, and one
  saved as plain **CSV**, to see the refusal.
- Open an exported CSV in Excel and check the Amharic.
- The page at 360 px wide.
