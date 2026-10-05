---
intent: 025-curriculum-workspace
phase: inception
status: complete
created: 2026-10-05T10:00:00Z
updated: 2026-10-05T10:30:00Z
---

# Requirements: Curriculum workspace

## Intent Overview

Prepare a course's curriculum inside the admin site instead of in a
spreadsheet and a separate recording step. The first load comes from the
curriculum Excel file (`curriculum/a1-english-speakers.xlsx`); from then
on the words and sentences are reviewed, corrected and recorded in the
admin, and a lesson is published from there into the app once every row
in it is reviewed and has audio.

Today this is two processes: the text is collected in a spreadsheet
(locally or in Google Sheets), the audio is recorded elsewhere and
uploaded, and the lesson's exercises are then built by hand or through
the lesson CSV import. Doing it in one place removes the copying between
them.

## Business Goals

| Goal | Success Metric | Priority |
|------|----------------|----------|
| One place to prepare a lesson | A lesson goes from imported rows to published in the app without leaving the admin | Must |
| Start from the existing spreadsheet | Every Section 1 and 2 row of the A1 workbook loads for a chosen course in one import | Must |
| Nothing reaches learners early | A lesson cannot be published until each of its rows is Reviewed and has audio | Must |
| See how far a course is | The admin shows filled / reviewed / recorded counts per section and lesson | Should |

## Scope

In scope:

- Draft curriculum storage per course, separate from the live lessons.
- Import from the curriculum Excel file, with a preview; re-import by row ID.
- Review and record screen: edit text and status, record or upload audio.
- Progress per section and lesson.
- Generate a lesson's exercises from its rows, edit them, and publish one lesson at a time.
- Export back to Excel.

Out of scope:

- Section 0 (sounds and writing): the Sounds tab already covers it.
- A reviewer login or role. For now only admins (the `ADMIN_EMAILS`
  allowlist) use the workspace. Admin accounts moving from the env
  variable to a database table is a later intent, and a reviewer role
  can be added on top of it then.
- Machine translation or text-to-speech.

---

## Functional Requirements

### FR-1: Draft curriculum per course
- **Description**: The backend stores a course's curriculum as a draft,
  in its own tables, apart from the live categories, skills, lessons and
  exercises. The plan is sections, skills and lessons, each with the
  spreadsheet's ID (`S1-U06-L1`), title, order and can-do goal. Each
  lesson has rows of two kinds: words (`W001`) and sentences (`S001`).
- **Acceptance Criteria**:
  - A row holds: its ID, kind, lesson, English, the target-language text,
    romanization, notes, Claude's confidence (High / Medium / Low / none),
    status (To do / Draft / Needs change / Reviewed), reviewer comment,
    audio URL, and when and by whom it was last changed.
  - A sentence row also holds the word to blank and other accepted answers.
  - Row IDs are unique within a course.
  - Nothing in the draft is returned by any learner-facing API.
- **Priority**: Must

### FR-2: Import the curriculum Excel file
- **Description**: On a course's Curriculum page the admin uploads the
  curriculum workbook. The course's language decides which columns are
  read (Amharic: Fidel and romanization; Afaan Oromo: the Oromo column).
  The file is read in the browser and a preview is shown before anything
  is saved.
- **Acceptance Criteria**:
  - The preview counts new, changed and unchanged plan entries and rows,
    and lists problems with their tab and row number; nothing is saved
    until the admin confirms.
  - Problems that block a row: a missing ID, a lesson ID not in the Plan
    tab, a word to blank that is not in its sentence, an unknown status or
    confidence value.
  - Section 0 rows are skipped and reported as skipped.
  - Importing the A1 workbook into an empty Amharic course creates 22
    skills' worth of lessons (66 lessons), 268 words and 66 sentences.
- **Priority**: Must

### FR-3: Re-import safely
- **Description**: Importing again matches plan entries and rows by ID.
- **Acceptance Criteria**:
  - Rows only in the file are added; rows only in the admin are kept and
    listed in the preview as "not in the file".
  - By default a row that is Reviewed or has audio is not overwritten; the
    preview marks it "kept", and an option allows overwriting it.
  - Importing the same file twice changes nothing the second time.
- **Priority**: Must

### FR-4: Curriculum overview with progress
- **Description**: A Curriculum page per course lists sections, skills and
  lessons in order, each with counts of rows filled, reviewed and recorded,
  and its publish state (Not published / Published / Changed since publish).
- **Acceptance Criteria**:
  - Counts match the rows: a row is filled when its target text is not
    empty, recorded when it has audio.
  - The page can be filtered to lessons that are ready to publish, or that
    have rows needing change.
- **Priority**: Must

### FR-5: Review a lesson's rows
- **Description**: A lesson's page lists its words and its sentence. The
  admin edits any text field, the status and the reviewer comment, and
  saves.
- **Acceptance Criteria**:
  - Rows are sorted with Low, then Medium confidence first, unless sorted
    by ID.
  - Saving a sentence whose word to blank is not in the sentence is
    refused with a message that names the field.
  - Changing the target text or romanization of a row that has audio warns
    that the recording may no longer match, and sets the row back to Draft.
  - Each row shows who last changed it and when.
- **Priority**: Must

### FR-6: Record or upload a row's audio
- **Description**: Each row can be recorded in the browser or given an
  uploaded file, using the admin's existing recorder and clean-up (the same
  as the Sounds tab), and stored like other exercise audio.
- **Acceptance Criteria**:
  - Record, hear the take, record again, and save; or choose a file.
  - The cleaned file's size is shown before it uploads.
  - A saved recording can be played and replaced.
  - "Next unrecorded" moves to the next row without audio in the lesson,
    then on to the next lesson.
- **Priority**: Must

### FR-7: Generate a lesson's exercises
- **Description**: From a lesson's rows, the admin generates the lesson's
  exercises with the same building rules as the lesson CSV import:
  multiple choice, listening, sentence construction, match pairs, gap fill
  and spell from tiles, with romanization and audio from the rows, and
  each word linked to a vocabulary item.
- **Acceptance Criteria**:
  - Wrong options are drawn from other words in the same skill or section,
    in an order that is the same each time it is generated.
  - The generated exercises are shown in the existing exercise preview.
  - Generating is only possible when every row of the lesson is Reviewed
    and has audio.
- **Priority**: Must

### FR-8: Edit generated exercises
- **Description**: After generating, each exercise can be changed in the
  existing exercise editor before or after publishing.
- **Acceptance Criteria**:
  - Generating again after a row changes updates only the exercises that
    were not edited by hand; edited ones are listed, with an option to
    reset them to the generated version.
- **Priority**: Must

### FR-9: Publish a lesson
- **Description**: The admin publishes one lesson at a time into the
  course. Publishing creates the lesson's category (from its section) and
  skill if they do not exist yet, and creates or updates the lesson and
  its exercises, beside the course's existing content.
- **Acceptance Criteria**:
  - Publish is disabled, with the reason shown, unless every row is
    Reviewed and has audio and the lesson's exercises are generated.
  - Existing hand-made categories, skills and lessons are never changed or
    removed by publishing.
  - Publishing a lesson again replaces only the exercises it published
    before; the lesson keeps its ID, so learners' progress is kept.
  - The published lesson's content version changes, so phones fetch it.
  - A lesson whose rows changed after publishing shows "Changed since
    publish" until it is published again.
- **Priority**: Must

### FR-10: Export to Excel
- **Description**: The admin downloads the course's curriculum as an Excel
  file in the same layout as the import, including review status,
  comments and an Audio Y/N column.
- **Acceptance Criteria**:
  - Exporting and importing the file back changes nothing.
- **Priority**: Should

---

## Non-Functional Requirements

### Performance
| Requirement | Metric | Target |
|-------------|--------|--------|
| Import preview | Time to preview the A1 workbook (≈330 rows) | < 3 s in the browser |
| Lesson page | Time to load a lesson's rows | < 500 ms p95 |
| Recording | Time from Save to the row showing its audio | < 5 s for a 5 s take |

### Security
| Requirement | Standard | Notes |
|-------------|----------|-------|
| Access | Existing admin session and allowlist | All curriculum endpoints are admin-only, like the rest of the admin API |
| Uploads | Existing presigned R2 upload | No storage keys in the browser |

### Reliability
| Requirement | Metric | Target |
|-------------|--------|--------|
| Import | Atomic | A failed import saves nothing |
| Publish | Atomic | A failed publish leaves the live lesson as it was |
| Edits | No lost work | Saving over a row someone else changed since it was loaded is refused with a message |

### Compatibility
| Requirement | Metric | Target |
|-------------|--------|--------|
| App | No app release needed | Published lessons use the existing lesson and exercise formats |
| Migrations | Backward compatible | New tables only; the running backend and app keep working before and after |

---

## Constraints

### Technical Constraints

**Project-wide standards**: loaded from the memory-bank standards folder by
the Construction Agent.

**Intent-specific constraints**:
- Reuse the admin's recorder, clean-up and upload (`admin/src/audio`,
  `/admin/audio/uploads`) rather than adding a second audio path.
- Exercise building reuses the lesson CSV import's rules
  (`admin/src/import/fromCsv.ts`) so generated and imported lessons match.
- The Excel file is read in the browser; the backend receives JSON.
- The curriculum workbook's layout (tabs, headers) is the import format;
  headers are matched by name, not position.

### Business Constraints
- Native speakers review and record with the admin present, until a
  reviewer role exists.

---

## Assumptions

| Assumption | Risk if Invalid | Mitigation |
|------------|-----------------|------------|
| One curriculum per course | A course needs two plans (e.g. A1 and A2) | Plan entries carry their section; A2 is more sections in the same plan |
| The A1 workbook's headers stay as they are | Import cannot find a column | Match headers by name and list missing ones in the preview |
| A section maps to a category and a skill to a skill | The course tree wants a different grouping | The mapping is set at publish, not stored in the rows |

---

## Open Questions

| Question | Owner | Due Date | Resolution |
|----------|-------|----------|------------|
| Who logs in to review and record? | Product owner | Checkpoint 1 | Resolved: admins only for now; admin accounts move to a DB table in a later intent |
| Do published lessons sit beside existing ones or replace them? | Product owner | Checkpoint 1 | Resolved: beside them |
| Can generated exercises be edited? | Product owner | Checkpoint 1 | Resolved: yes, in the existing editor |
| Publish one lesson or a whole skill? | Product owner | Checkpoint 1 | Resolved: one lesson |

---

## System Context

To keep the file count small, the system context is held here, and the
unit briefs hold their stories (as in intents 021 to 024).

- **Actors:** the admin; a native speaker who reviews and records with the
  admin present.
- **Admin site:** a Curriculum tab per course: reading the workbook in the
  browser, the import preview, export, the overview with progress, a
  lesson's rows with editing and recording, generating, editing and
  publishing its exercises.
- **Backend:** draft curriculum tables (plan entries, rows, a lesson's
  draft exercises and what it published), admin-only endpoints to import,
  list, edit, set audio, save draft exercises and publish; publishing writes
  the existing category, skill, lesson, exercise and vocab item tables.
- **R2:** row audio, through the existing presigned audio upload.
- **Mobile app:** unchanged; it sees a published lesson like any other.
- **Out of the picture:** Google Sheets, the Sounds tab, learners' data.

```text
 workbook.xlsx --(read in browser)--> admin: Curriculum tab
                                        |  preview, confirm
                                        v
                     backend: curriculum_* tables (draft)  <-- edit, status
                                        ^                      |
    mic / file -> clean-up -> R2 -------+ audio_url             |
                                                                v
                     generate (fromCsv rules) -> draft exercises -> edit
                                                                |
                                                          publish (one lesson)
                                                                v
                  categories / skills / lessons / exercises / vocab_items (live)
                                                                |
                                                                v
                                                    mobile app (unchanged)
```
