---
unit: 002-curriculum-admin
intent: 025-curriculum-workspace
unit_type: frontend
default_bolt_type: simple-construction-bolt
phase: inception
status: complete
created: '2026-10-05T10:30:00Z'
updated: '2026-10-05T10:30:00Z'
---

# Unit Brief: Curriculum Admin

## Purpose

Give the admin one place to load a course's curriculum, review and record
it with a native speaker, and publish each lesson when it is ready.

## Scope

### In Scope
- A Curriculum tab for each course, with the overview and progress
- Reading the curriculum workbook in the browser (library chosen at the
  plan stage of bolt 083), the import preview and confirm, and export
- A lesson's page: edit rows, status and comment; record (the existing
  recorder and clean-up) or upload; next unrecorded
- Generating a lesson's exercises with the lesson CSV import's rules,
  preview, editing in the existing exercise editor, and publishing
- Tests

### Out of Scope
- Google Sheets
- A reviewer login
- Section 0 (the Sounds tab)

---

## Assigned Requirements

| FR | Requirement | Priority |
|----|-------------|----------|
| FR-2 | Import the workbook | Must |
| FR-3 | Re-import preview | Must |
| FR-4 | Overview with progress | Must |
| FR-5 | Review a lesson's rows | Must |
| FR-6 | Record or upload audio | Must |
| FR-7 | Generate exercises | Must |
| FR-8 | Edit generated exercises | Must |
| FR-9 | Publish (UI) | Must |
| FR-10 | Export to Excel | Should |

---

## Stories

| Story ID | Title | Priority | Status |
|----------|-------|----------|--------|
| 007-curriculum-tab-and-overview | The Curriculum tab and its progress | Must | Complete (bolt 083) |
| 008-read-the-workbook | Read the workbook in the browser | Must | Complete (bolt 083) |
| 009-import-preview-and-confirm | Preview an import, then confirm | Must | Complete (bolt 083) |
| 010-export-to-excel | Download the curriculum as Excel | Should | Complete (bolt 083) |
| 011-review-a-lessons-rows | Review and correct a lesson's rows | Must | Complete (bolt 084) |
| 012-record-a-row | Record or upload a row's audio | Must | Complete (bolt 084) |
| 013-generate-exercises | Generate a lesson's exercises | Must | Complete (bolt 086) |
| 014-edit-generated-exercises | Edit the generated exercises | Must | Complete (bolt 086) |
| 015-publish-from-the-admin | Publish a lesson from its page | Must | Complete (bolt 086) |

### 007-curriculum-tab-and-overview (FR-4)

**As an** admin, **I want** to see a course's curriculum and how far it
is, **so that** I know what to review and record next.

- [x] Each course has a Curriculum page, reached from the course; an empty
  one offers the import.
- [x] Sections, skills and lessons are listed in order, each with filled,
  reviewed and recorded counts out of its rows, and its publish state.
- [x] Filters: ready to publish; has rows needing change.

### 008-read-the-workbook (FR-2)

**As an** admin, **I want** to pick the workbook file, **so that** I do
not have to convert it first.

- [x] An `.xlsx` with Plan, Words and Sentences tabs is read in the
  browser; headers are matched by name, and a missing tab or header is
  named.
- [x] The course's language picks the columns (Amharic: Fidel and
  romanization; Afaan Oromo: the Oromo column and its blank and accepted
  answers).
- [x] Section 0 rows are skipped and counted as skipped.
- [x] The A1 workbook reads in under 3 s.

### 009-import-preview-and-confirm (FR-2, FR-3)

**As an** admin, **I want** to see what an import will do, **so that** a
wrong file never overwrites the draft.

- [x] The preview (the backend's dry run) shows added, changed, kept and
  unchanged counts, rows not in the file, and problems by tab and row.
- [x] "Overwrite reviewed rows" is off by default.
- [x] Nothing is saved until Confirm; after it, the overview shows the
  new counts.

### 010-export-to-excel (FR-10)

**As an** admin, **I want** to download the curriculum, **so that** I
have a backup and a copy for offline work.

- [x] The download has the import's tabs and headers, with status,
  comments and Audio Y/N.
- [x] Importing the downloaded file into the same course changes nothing.

### 011-review-a-lessons-rows (FR-5)

**As an** admin sitting with a native speaker, **I want** to correct each
word and sentence and mark it reviewed, **so that** the lesson is right.

- [x] A lesson's page lists its rows, Low then Medium confidence first, or
  by ID.
- [x] Every text field, status and comment can be edited and saved; the
  word-to-blank check and the server's `409` are shown in words.
- [x] Editing the text of a recorded row warns before saving that it goes
  back to Draft.
- [x] Each row shows who changed it last and when.

### 012-record-a-row (FR-6)

**As an** admin, **I want** to record each row right where I review it,
**so that** text and audio are done in one sitting.

- [x] Record, play the take, record again, save; or choose a file; the
  existing clean-up runs and the file size shows before upload.
- [x] A saved recording plays and can be replaced.
- [x] "Next unrecorded" goes to the next row without audio, then to the
  next lesson.

### 013-generate-exercises (FR-7)

**As an** admin, **I want** a lesson's exercises made from its rows,
**so that** I do not build them by hand.

- [x] Generate is enabled only when every row is Reviewed with audio.
- [x] It builds multiple choice, listening, sentence construction, match
  pairs, gap fill and spell from tiles with the CSV import's rules, using
  the rows' romanization and audio; wrong options come from the same
  skill or section, in a fixed order.
- [x] The result is shown in the exercise preview and saved as the
  lesson's draft exercises.

### 014-edit-generated-exercises (FR-8)

**As an** admin, **I want** to adjust a generated exercise, **so that** I
can fix what the rules got wrong.

- [x] Each draft exercise opens in the existing exercise editor; saving
  marks it edited.
- [x] Generating again replaces only unedited exercises; edited ones are
  listed with "Reset to generated".

### 015-publish-from-the-admin (FR-9)

**As an** admin, **I want** to publish a finished lesson from its page,
**so that** learners get it as soon as it is ready.

- [x] Publish shows why it is disabled when it is.
- [x] After publishing, the lesson links to its place in the course tree,
  and the overview shows Published; a later change shows Changed since
  publish.

---

## Dependencies

### Depends On
- `001-curriculum-service`

### Depended On By
None.
