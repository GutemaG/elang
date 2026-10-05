---
unit: 001-curriculum-service
intent: 025-curriculum-workspace
unit_type: backend
default_bolt_type: simple-construction-bolt
phase: inception
status: complete
created: '2026-10-05T10:30:00Z'
updated: '2026-10-05T10:30:00Z'
---

# Unit Brief: Curriculum Service

## Purpose

Keep a course's curriculum as a draft the admin can review and record, and
publish one finished lesson at a time into the live course.

## Scope

### In Scope
- Tables, in backward-compatible migrations (rows in bolt 082, draft
  exercises and publish records in bolt 085):
  - plan entries: course, ID (`S1`, `S1-U06`, `S1-U06-L1`), kind (section,
    skill, lesson), parent, title, order, can-do goal, grammar note
  - rows: course, ID (`W001`, `S001`), kind (word, sentence), lesson ID,
    English, target text, romanization, word to blank, other accepted
    answers, notes, confidence, status, reviewer comment, audio URL,
    `version`, `updated_at`, `updated_by`
  - per lesson: draft exercises (JSON bodies, each with a generated flag
    and the generated body it came from), and what it published (lesson
    ID, category ID, skill ID, exercise IDs, published at)
- Admin-only endpoints under `/api/v1/admin/courses/{course_id}/curriculum`:
  import (atomic merge), read (plan, rows, counts, publish state), edit a
  row, set a row's audio, save a lesson's draft exercises, publish a lesson
- Publishing into the existing tables: category from the section, skill,
  lesson, exercises, vocab items
- Tests; the API notes

### Out of Scope
- Reading Excel (the admin sends JSON)
- Building exercises (the admin does, with the CSV import's rules)
- A reviewer role or admin accounts in the database

---

## Assigned Requirements

| FR | Requirement | Priority |
|----|-------------|----------|
| FR-1 | Draft curriculum per course | Must |
| FR-3 | Re-import safely (merge rules) | Must |
| FR-4 | Overview counts | Must |
| FR-5 | Row validation | Must |
| FR-6 | Row audio | Must |
| FR-7, FR-8 | Draft exercises | Must |
| FR-9 | Publish a lesson | Must |

---

## Stories

| Story ID | Title | Priority | Status |
|----------|-------|----------|--------|
| 001-draft-curriculum-tables | Draft plan and rows per course | Must | Complete (bolt 082) |
| 002-import-the-curriculum | Atomic import that merges by ID | Must | Complete (bolt 082) |
| 003-edit-a-row | Edit a row, with checks | Must | Complete (bolt 082) |
| 004-a-rows-audio | Set and replace a row's audio | Must | Complete (bolt 082) |
| 005-draft-exercises | Keep a lesson's draft exercises | Must | Complete (bolt 085) |
| 006-publish-a-lesson | Publish one lesson into the course | Must | Complete (bolt 085) |

### 001-draft-curriculum-tables (FR-1)

**As an** admin, **I want** a course's plan and rows kept apart from the
live lessons, **so that** nothing reaches learners before it is ready.

- [x] One migration adds the tables; it upgrades and downgrades on SQLite
  and Postgres, and the running backend and app keep working.
- [x] Plan entry IDs and row IDs are unique within a course; a row's
  lesson must be a lesson entry of the same course.
- [x] Status is one of To do, Draft, Needs change, Reviewed; confidence is
  High, Medium, Low or none; kind is word or sentence.
- [x] No learner-facing endpoint returns any of it.

### 002-import-the-curriculum (FR-2, FR-3)

**As an** admin, **I want** to send the whole workbook at once, **so
that** the course's draft matches the file without losing reviewed work.

- [x] One request carries plan entries and rows; it is applied in one
  transaction, and any invalid item rejects all of it with each problem
  listed (ID and field).
- [x] Entries and rows are matched by ID: new ones are added, changed ones
  updated, ones not in the request kept.
- [x] A row that is Reviewed or has audio is not changed unless the
  request says `overwrite_reviewed: true`.
- [x] A dry run returns what would change (added, changed, kept,
  unchanged) without saving.
- [x] Sending the same request twice changes nothing the second time.

### 003-edit-a-row (FR-5)

**As an** admin, **I want** to correct a row and set its status, **so
that** the reviewed text is what the lesson teaches.

- [x] `PATCH` changes only the fields sent, and needs the row's current
  `version`; an older version is `409` and nothing is saved.
- [x] A sentence whose word to blank is not in its text is `422`, naming
  the field.
- [x] Changing the target text or romanization of a row with audio sets
  it to Draft and says so in the response.
- [x] `updated_by` and `updated_at` are set.

### 004-a-rows-audio (FR-6)

**As an** admin, **I want** a row's recording saved with it, **so that**
the lesson's exercises can play it.

- [x] The admin uploads through the existing `/admin/audio/uploads`, then
  sets the row's audio URL; only URLs from that upload are accepted.
- [x] Setting it again replaces it; clearing it is allowed.
- [x] The read returns, per lesson, rows filled, reviewed and recorded.

### 005-draft-exercises (FR-7, FR-8)

**As an** admin, **I want** a lesson's generated exercises kept, and my
edits to them, **so that** I can check them before publishing.

- [x] A lesson's draft exercises are saved as a list of exercise bodies in
  the existing exercise format, each marked generated or edited, with the
  generated body it came from.
- [x] Saving them is refused unless every row of the lesson is Reviewed
  and has audio.
- [x] Bodies are validated like the existing exercise endpoints.

### 006-publish-a-lesson (FR-9)

**As an** admin, **I want** to publish one finished lesson, **so that**
learners get it beside the course's existing lessons.

- [x] Refused, with the reason, unless every row is Reviewed with audio
  and the lesson has draft exercises.
- [x] The first publish creates the section's category and the skill if
  they are not there yet (found again by the IDs the curriculum
  published), then the lesson, its exercises and a vocab item per word.
- [x] Publishing again keeps the lesson's ID and replaces only the
  exercises it published before; hand-made categories, skills, lessons
  and exercises are untouched.
- [x] The lesson's content version changes; all of it happens in one
  transaction.
- [x] The read shows Not published, Published, or Changed since publish
  (a row or draft exercise changed after it).

---

## Dependencies

### Depends On
None.

### Depended On By
- `002-curriculum-admin`
