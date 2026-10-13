---
intent: 029-audio-library
phase: construction
status: complete
created: '2026-10-13T18:00:00Z'
updated: '2026-10-14T00:30:00Z'
---

# Requirements: Audio library

## Intent Overview

Every recording and every generated take is uploaded to one R2 bucket,
but nothing in the admin site shows what is there. A super admin can't
hear a file without finding the exercise first, can't tell which files
nothing uses any more (unchosen Addis takes, replaced recordings), and
has no way to keep a copy of the audio elsewhere.

This intent adds an **Audio library** page under Configuration, for
super admins only:

- **See and hear** every audio file in storage, with what uses it:
  which exercise, Workbook row or Sounds letter. "Open" goes to that
  place, where the audio is re-recorded or replaced as today.
- **Clean up**: files nothing uses can be moved to a trash folder, then
  restored or deleted for good.
- **Export** a ZIP for backup: the files laid out by course, section
  and lesson, with a `manifest.csv` that says which file belongs to
  which exercise.

By the owner's choice (2026-10-13) the intent is built straight from
these requirements, without units, stories or bolts.

## Current state (2026-10-13)

| Topic | What is there |
|---|---|
| Storage | `R2Storage` (`app/infrastructure/external/r2_storage.py`) signs `PUT` upload links only, with a stdlib SigV4 `presign`. In local development without R2, `LocalAudioStorage` saves files in `backend/media/audio/`, served from `/media/audio/`. |
| Keys | `{language}/{lesson_id}/{12 hex}.{ext}`; a generated take is `{language}/{lesson_id}/gen-{am|om}-{voice}-{12 hex}.{ext}` (intent 027). Pictures share the bucket, as `.webp`/`.jpg`. |
| Public address | `AUDIO_BASE_URL` (`settings.audio_base_url`): a stored link is `{AUDIO_BASE_URL}/{key}`. |
| Where links are stored | `exercises.content` (`audio_url` of listening and audio-picture questions, optional on others); `curriculum_rows.audio_url` (Workbook); `sound_letters.audio_url` and `example_audio_url` (Sounds). |
| R2 CORS | The documented rule (README) allows `PUT`, `GET`, `HEAD` from the admin site, so the browser can already read files with a signed link. |
| Roles | Intent 028: `require_super_admin`; the route sweep test needs every admin route in `admin_route_rules.py`. |

## Business Goals

| Goal | Success Metric | Priority |
|------|----------------|----------|
| Know what is stored | Every audio file in storage is listed, with its size, date and uses | Must |
| Fix bad audio fast | From a file, one click opens the exercise, Workbook lesson or letter that uses it | Must |
| Free storage safely | Unused files can be trashed, restored and deleted; a file in use can never be | Must |
| Keep a backup | One ZIP per course (or everything) with a manifest that ties each file to its exercise | Must |

## Scope

In scope: audio files (`m4a`, `mp3`, `webm`, `ogg`, `wav`), on R2 and
the local store; the page, its API, trash and export.

Out of scope:

- Pictures. They share the bucket and could be a second tab later.
- Uploading the backup straight to Google Drive or Gmail. The ZIP is
  saved by the browser; the super admin puts it where they like.
  (Gmail limits attachments to 25 MB, so Drive suits a backup better.)
- Replacing audio on this page. Replacing stays where it is today.
- Emptying the trash on a schedule.

---

## Functional Requirements

### Backend

#### FR-1: Read, move and delete stored files
- **Description**: Both stores can list, link, move and delete files.
- **Acceptance Criteria**:
  - A `MediaLibrary` protocol with:
    - `list_files(prefix)` → `StoredFile(key, size, uploaded_at)`;
    - `download_url(key)` → a link the admin site can `fetch`;
    - `move(key, to_key)` and `delete(key)`.
  - R2: `ListObjectsV2` (all pages), a signed `GET` link (15 minutes),
    `CopyObject` then `DeleteObject` for a move, `DeleteObject`. All
    signed with the existing `presign`, which gains extra query
    parameters. The secret never appears in a response or log.
  - Local: walks `backend/media/audio/`; links are the backend's own
    `/media/audio/{key}` address; a move renames the file.
  - A key outside the bucket's layout (`..`, absolute) is refused.
- **Priority**: Must

#### FR-2: Which file is used where
- **Description**: The library matches stored files to stored links.
- **Acceptance Criteria**:
  - A link names a stored key when it starts with the store's public
    address (`AUDIO_BASE_URL/` on R2, `/media/audio/` or an absolute
    `…/media/audio/` locally); a query string is ignored.
  - Uses are read from: every string anywhere in `exercises.content`;
    `curriculum_rows.audio_url`; `sound_letters.audio_url` and
    `example_audio_url`.
  - Each use says what it is and where it opens in the admin site:
    - exercise: course, section, lesson, exercise number and type,
      prompt; opens `/courses/{course}/lessons/{lesson}/exercises/{id}`;
    - Workbook row: course, Workbook lesson title, the row's English
      and text; opens `/courses/{course}/workbook/lessons/{ref}`;
    - Sounds: language, letter and whether it is the letter's sound or
      its example word; opens `/sounds/{language}/letters/{id}`.
  - A file is **in use** with one or more uses, otherwise **not used**.
  - A link under the store's address whose key isn't stored is
    **missing**: listed with its use, so a broken exercise can be fixed.
  - Links elsewhere (another host) are only counted.
- **Priority**: Must

#### FR-3: Library API
- **Description**: `GET /api/v1/admin/audio-files`, super admin only.
- **Acceptance Criteria**:
  - Returns `storage` (`r2` or `local`), `files` (key, url, size,
    uploaded_at, language, source `recorded`/`generated`, status, uses,
    `can_trash`), `missing` (url, key, uses), `trash` (key, original
    key, size, moved_at), `external_links` (count), and totals.
  - Files newest first. Only audio extensions; pictures are left out.
  - `can_trash` is true only for a file not used and uploaded more than
    24 hours ago, because a file is uploaded before its exercise is
    saved.
  - No store configured → 503 `audio_storage_not_configured`, as
    uploads do. A store error → 502 `audio_storage_unavailable`.
- **Priority**: Must

#### FR-4: Trash
- **Description**: Unused files can be moved to trash, restored, or
  deleted for good.
- **Acceptance Criteria**:
  - `POST /api/v1/admin/audio-files/trash` `{keys}` moves each file to
    `trash/{key}`. The uses are read again first: a file in use, or
    younger than 24 hours, is refused with 409 `audio_file_in_use`
    and nothing is moved.
  - `POST /api/v1/admin/audio-files/trash/restore` `{keys}` takes trash
    keys (`trash/{key}`) and moves each back to `{key}`. A file already
    at `{key}` → 409 `audio_file_exists`, and nothing is moved. A
    restored file counts as new, so it can't be trashed again for a day.
  - `POST /api/v1/admin/audio-files/trash/delete` `{keys}` deletes
    trashed files for good. Only keys under `trash/`.
  - At most 500 keys per call. Unknown keys → 404 `audio_file_not_found`.
  - Bad input (no keys, or more than 500) → 422 `invalid_content`,
    `field: keys`.
  - Each move and delete logs `admin_write action=… entity=audio_file
    id=… admin=…`.
- **Priority**: Must

#### FR-5: Export
- **Description**: `GET /api/v1/admin/audio-files/export?course_id=`,
  super admin only.
- **Acceptance Criteria**:
  - Without `course_id`: every file. With it: the files that course
    uses, plus the Sounds files of its learning language.
  - `include_unused=true` adds files nothing uses (all of them without
    a course; the course's language with one).
  - Returns one row per file and use, with: the ZIP path, status, the
    use's course, section, lesson, exercise number and type, prompt,
    text, English, place (exercise/Workbook/Sounds), admin path, key,
    original URL, size, uploaded date, and a signed download link.
    Missing files are rows with no download link.
  - ZIP paths follow the course:
    `{course}/{nn}-{section}/{nn}-{skill}/{nn}-{lesson}/ex{nn}-{type}-{id}.{ext}`,
    `{course}/workbook/{lesson}/{row}-{id}.{ext}`,
    `sounds/{language}/{letter}-{sound|example}-{id}.{ext}`,
    `unused/{language}/{file}`. Names are ASCII slugs; Fidel is kept
    only in the manifest. A file used in several places is stored once,
    at its first path.
- **Priority**: Must

### Admin site

#### FR-6: Audio library page
- **Description**: `/audio-library`, under Configuration, super admin
  only.
- **Acceptance Criteria**:
  - Totals: files, size, in use, not used, missing, in trash.
  - Tabs: Files, Missing, Trash.
  - Files: filter by course or language, status (all / in use / not
    used), source (recorded / generated), and a search on key or use.
  - Each file: Play (one at a time), key, size, date, source, status
    badge, and its uses, each with Open.
  - Missing: each use with Open, so the audio can be recorded again.
- **Priority**: Must

#### FR-7: Clean up on the page
- **Description**: Trash, restore and delete from the page.
- **Acceptance Criteria**:
  - Files that `can_trash` have a checkbox; "Select all not used" picks
    them. "Move to trash" asks in a dialog with the count and size.
  - Trash: Restore, and Delete for good after a dialog that says it
    can't be undone.
  - Errors stay in the dialog; the list reloads after each change.
- **Priority**: Must

#### FR-8: Export on the page
- **Description**: The browser builds and saves the ZIP.
- **Acceptance Criteria**:
  - An Export dialog: course or everything, and "Include files nothing
    uses".
  - The browser downloads each file from its signed link, shows
    "{n} of {total}", and can be cancelled.
  - The ZIP holds the files and `manifest.csv` (UTF-8 with a BOM so
    Excel shows Fidel). Files are stored without compression (audio is
    already compressed), by a small ZIP writer in the admin code; no new
    package.
  - A file that fails to download is marked `download_failed` in the
    manifest, and the summary says how many.
  - Saved as `buna-audio-{course or all}-{yyyy-mm-dd}.zip`.
- **Priority**: Must

#### FR-9: Navigation and access
- **Acceptance Criteria**:
  - "Audio library" in the Configuration group; course admins don't see
    it, and `/audio-library` sends them to `/`.
  - The four routes are in `SUPER_ONLY`; the route sweep stays green.
- **Priority**: Must

---

## Non-Functional Requirements

- **Security**: super admin only, server-side. Signed links last 15
  minutes and name one key. No R2 secret in any response or log.
- **Safety**: a file in use can't be trashed or deleted; deleting for
  good works only inside `trash/`.
- **Performance**: one list of the bucket and one read per link table
  per request. A few thousand files stay well under Vercel's 4.5 MB
  response limit (about 400 bytes a file).
- **Reliability**: the export never goes through the backend's
  response, so its size is limited only by the browser.

## Constraints

- No new Python package: R2 calls use `httpx` and the existing SigV4
  signer. No new npm package.
- R2's CORS rule must allow `GET` from the admin site (the documented
  rule already does).

## Decisions (2026-10-13)

| Decision | Why |
|---|---|
| Built from requirements only | The owner asked for no bolts in this intent. |
| Trash folder instead of instant delete | A wrong click can be undone. |
| ZIP built in the browser | Vercel can't return large responses. |
| Audio only | Pictures can reuse the same library later. |

---

## Implement (2026-10-13)

- **Backend:**
  - `presign` signs extra query parameters (`params`).
  - `app/infrastructure/external/media_library.py`: `R2MediaLibrary`
    and `LocalMediaLibrary`, plus `choose_media_library` (FR-1).
  - `app/infrastructure/db/audio_library_repository.py`: the three
    link tables, with their names (FR-2).
  - `app/application/audio_library_use_cases.py`: matching, trash and
    export (FR-2 to FR-5).
  - `audio_library_routers.py` and `audio_library_schemas.py`, registered
    in `main.py` and `make_client`.
  - `AudioStorageUnavailableError` (502), `AudioFileNotFoundError`
    (404), `AudioFileInUseError` (409).
  - The five routes are in `SUPER_ONLY`. `conftest` sets the library to
    None, so tests never touch R2 or `backend/media`.
- **Admin:** `src/library/`: `api.ts`, `zip.ts` (stored ZIP with
  CRC-32), `backup.ts` (downloads and `manifest.csv`),
  `AudioLibraryPage.tsx`, `ExportDialog.tsx`; "Audio library" in
  Configuration; `/audio-library` is behind `SuperOnly`.
- A read-only run against `dev.db` and the local folder found 17
  files: 5 in use, 0 missing, and 31 links to audio elsewhere (the
  seed's placeholder).

## Test (2026-10-14)

- `tests/unit/test_media_library.py` and
  `tests/integration/test_audio_library_api.py`: 52 tests, including
  the route sweep.
- Full backend suite: 2303 passed. Ruff clean; mypy only the 4 errors
  that were already there.
- `src/library/zip.test.ts` and `library.test.tsx`: 14 tests. Admin
  suite: 862 of 863 passed while the backend suite was running; the one
  failure (`generate.test.tsx`, a timing test) passes on its own.
  `tsc -b` and `eslint .` are clean.
