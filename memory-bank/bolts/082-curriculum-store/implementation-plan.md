---
stage: plan
bolt: 082-curriculum-store
created: '2026-10-05T12:05:00Z'
---

## Implementation Plan: curriculum-service

### Objective

Stories 001-004 (FR-1, FR-3 merge rules, FR-4 counts, FR-5 validation,
FR-6 audio): a course's curriculum kept as a draft in its own tables, an
import that merges the whole workbook by ID (with a dry run), the read with
per-lesson counts, editing a row with a version check, and a row's audio.
Draft exercises and publishing are bolt 085.

### What the code says (checked before planning)

- **F1 Sounds is the model to copy.** `app/domain/sounds.py` (constants,
  limits), `sound_models.py`, `sound_repository.py`,
  `sound_use_cases.py` (`_text`, `_audio`, `AdminContext`, `_log`),
  `sound_routers.py` (an `admin_router` with `require_admin`, its own
  presigned upload) and `sound_schemas.py`.
- **F2 The shared audio upload needs a live lesson.**
  `POST /admin/audio/uploads` takes a `lesson_id` and keys files under
  it; draft rows have no live lesson. Sounds has its own upload for the
  same reason.
- **F3 One transaction per request.** `get_db_session` commits on success
  and rolls back on any exception, so raising after writes saves nothing.
- **F4 Errors.** `AdminContentError` subclasses carry `details`;
  `InvalidImportError` (422) already lists `rows` problems for the
  exercise import; there is no "changed since you loaded it" error yet.
- **F5 Tests.** `db_path` builds the schema from `Base.metadata` (models
  must be imported in `conftest.py` and `migrations/env.py`); migration
  tests run Alembic in a subprocess (`test_courses_migration._alembic`).
  Head is `c5e8a3f1d7b2`.

### Decisions

- **D1 Two tables, keyed by course and ID.**
  - `curriculum_entries`: `id`, `course_id` (FK courses, cascade),
    `ref` (`S1`, `S1-U06`, `S1-U06-L1`), `kind` (section / skill /
    lesson), `parent_ref`, `position`, `title`, `goal`, `grammar`,
    timestamps. Unique `(course_id, ref)`.
  - `curriculum_rows`: `id`, `course_id`, `ref` (`W001`, `S001`), `kind`
    (word / sentence), `lesson_ref`, `position`, `english`, `text`,
    `romanization`, `blank`, `accepted` (JSON list), `notes`,
    `confidence` (high / medium / low / null), `status` (to_do / draft /
    needs_change / reviewed), `comment`, `audio_url`, `version`,
    `updated_by`, timestamps. Unique `(course_id, ref)`.
  - Check constraints on the kinds, status and confidence. One migration
    `d8b3f6a2c4e1`, new tables only.
- **D2 The admin sends keys, not labels.** The admin site turns "Needs
  change" into `needs_change` and "Medium" into `medium`; the backend
  accepts only keys.
- **D3 Import: `PUT /admin/courses/{course_id}/curriculum`.** Body:
  `entries`, `rows`, `overwrite_reviewed` (default false); `?dry_run=true`
  returns the same answer and saves nothing.
  - Every item is checked first; any problem is `422 invalid_import` with
    `details.rows = [{ref, field, message}]` and nothing is saved.
  - Checks: refs match `^[A-Za-z0-9][A-Za-z0-9_-]{0,31}$` and are unique
    in the request; a skill's parent is a section and a lesson's a skill
    (in the request or already saved); a row's lesson is a lesson entry; a
    sentence's blank is in its text; a word has no blank; lengths; known
    kinds, statuses and confidences.
  - Entries are added or updated; rows are added, updated, kept, or
    unchanged. A row is **kept** (not changed) when it is Reviewed or has
    audio and the file differs, unless `overwrite_reviewed`. Items saved
    but not in the request are left alone and listed as `missing`.
  - Import never touches `audio_url`. A changed row's `version` goes up
    and `updated_by` is the admin. If an overwrite changes the text or
    romanization of a row with audio, it goes back to Draft.
  - The answer: counts (`added`, `changed`, `kept`, `unchanged`) for
    entries and rows, and the refs of kept and missing rows.
- **D4 Read: `GET .../curriculum`.** Entries in order (by position),
  rows by lesson then position, and counts per lesson and in total:
  `rows`, `filled` (text not empty), `reviewed`, `recorded` (has audio),
  `needs_change`. An empty curriculum is a 200 with empty lists.
- **D5 Edit: `PATCH .../curriculum/rows/{ref}`.** Body: `version` (the
  one the admin loaded) and any of `english`, `text`, `romanization`,
  `blank`, `accepted`, `notes`, `status`, `comment`, `audio_url`.
  - A stale `version` is `409 content_changed` with
    `details.current_version`; nothing is saved.
  - The same checks as the import; the blank is checked against the row's
    text after the change.
  - Changing `text` or `romanization` of a row with audio sets it to
    Draft (unless this same request sets the status), and the answer says
    `reset_to_draft: true`.
  - `audio_url` must be https (or `/media/audio/...` locally), like the
    Sounds tab; null clears it. Setting audio does not change the status.
- **D6 Audio upload: `POST .../curriculum/audio/uploads`.** Body
  `content_type`, `size`, `row_ref`; keys under
  `{language}/curriculum/{row_ref}/{hex}.{ext}`; the same types, size
  limit and link lifetime as the shared upload (deviation from the unit
  brief, which named the shared one: it needs a live lesson, F2).
- **D7 Code layout.** `app/domain/curriculum.py`,
  `app/infrastructure/db/curriculum_models.py`,
  `curriculum_repository.py`, `app/application/curriculum_use_cases.py`,
  `app/infrastructure/api/curriculum_routers.py` and
  `curriculum_schemas.py`; `ContentChangedError` (409) in the domain
  exceptions; the router in `main.py`.

### Deliverables

- Domain constants and checks; models; migration; repository; use cases;
  schemas and router; `ContentChangedError`
- Tests: unit (domain checks), integration (import, dry run, re-import,
  read, edit, version check, audio upload, admin-only), migration
- API notes in the router docstrings

### Dependencies

- None new. Uses `R2Storage` / `LocalAudioStorage` through
  `admin_routers.get_audio_storage`.

### Acceptance Criteria

- [ ] Migration upgrades and downgrades; single head; models match it
- [ ] Import of entries and rows saves all or nothing, with every problem
  listed
- [ ] Re-import keeps reviewed or recorded rows unless told; the same
  request twice changes nothing; dry run saves nothing
- [ ] Read returns entries, rows and per-lesson counts
- [ ] Edit needs the current version; checks the blank; resets a recorded
  row to Draft on a text change
- [ ] Audio upload link and setting audio work; non-https refused
- [ ] Every endpoint is admin-only; nothing learner-facing returns drafts
- [ ] ruff and the full backend suite pass

## Implement (2026-10-05T12:12:00Z)

- `app/domain/curriculum.py`: entry and row kinds, statuses, confidences,
  the ref pattern, limits, the word-to-blank rule, counts and "ready to
  publish".
- `app/infrastructure/db/curriculum_models.py` and migration
  `d8b3f6a2c4e1` (new tables only, down to `c5e8a3f1d7b2`):
  `curriculum_entries` and `curriculum_rows`, unique by course and ref,
  with check constraints, cascade with the course.
- `curriculum_repository.py`: the course, entries, rows, one row.
- `app/application/curriculum_use_cases.py`: the import (every problem
  collected, then all or nothing; merge by ref; reviewed or recorded rows
  kept unless `overwrite_reviewed`; dry run), the read with counts, the
  row edit (version check, blank rule, back to Draft), the upload link.
- `curriculum_schemas.py`, `curriculum_routers.py`: the four endpoints;
  `ContentChangedError` (`409 content_changed`); router in `main.py`,
  models in `env.py`.
- Deviation: an entry with its own problems still counts as a parent in
  the tree check, so one mistake is reported once, not again on each
  child.

## Test (2026-10-05T12:19:51Z)

- `tests/unit/test_curriculum_domain.py` (18): the blank rule, refs,
  counts, ready to publish.
- `tests/integration/test_curriculum.py` (23): empty curriculum; import
  with counts and order; dry run; every problem listed and nothing saved;
  a word with a blank; rows joining saved lessons and missing items
  listed; the same file twice; reviewed and recorded rows kept; overwrite
  keeps audio and resets status; edits, stale version (409), the blank
  rule, back to Draft (and not when the status is sent, or with no audio),
  no-op edits keep the version, bad values, 404s; the upload link (key,
  public address, no secret) then saving and clearing the audio; bad
  type, size and row; admin only.
- `tests/integration/test_curriculum_migration.py` (3): single head,
  upgrade and downgrade, kind check. The heads test moved here from
  `test_sound_kinds_migration.py`.

Results: `ruff check .` clean; mypy on the new files clean (3 errors in
other files, from before); `pytest` 1701 passed.
