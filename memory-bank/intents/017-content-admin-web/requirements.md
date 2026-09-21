---
intent: 017-content-admin-web
phase: inception
status: units-defined
created: '2026-09-22T09:00:00Z'
updated: '2026-09-22T10:00:00Z'
---

# Requirements: Content Admin Web

## Intent Overview

A browser-based admin tool, built with **React**, for managing lesson
materials: courses, sections (categories), skills, lessons, exercises,
vocabulary and their audio clips.

**Why now.** Today every content change goes through code: edit
`seed_lesson_content.py` / `seed_course_content.py`, run the seed against Neon,
and redeploy. Hand edits in the Neon console are possible, but the next seed
run silently overwrites them, because the seed rewrites every row it owns by
its uuid5 content id. Adding real recordings (four clips now on Cloudflare R2)
made this concrete: attaching one clip to one exercise meant SQL, URL-encoded
object keys and a hand-edited answer key. That does not scale to a course's
worth of recordings.

**Brown-field.** The FastAPI backend, the Neon schema (`courses`,
`categories`, `skills`, `lessons`, `exercises`, `vocab_items`) and the six
exercise types (`multiple_choice`, `listening`, `sentence_construction`,
`match_pairs`, `gap_fill`, `spell_tiles`) already exist. This intent adds an
admin API to the backend and a new React front end beside the Flutter app. The
learner app and the learner-facing API do not change.

## Business Goals

| Goal | Success Metric | Priority |
|------|----------------|----------|
| Change lesson content without touching code or SQL | An admin creates, edits, reorders and deletes a lesson's exercises from the browser, and the change shows in the app on its next fetch | Must |
| Attach real audio to exercises | An admin records, uploads or links a clip and attaches it to a listening exercise in one flow; it plays in the released app | Must |
| Keep content edits safe | Only admins can write; an invalid exercise cannot be saved | Must |
| The database is the single source of truth for content | A seed run after an admin edit leaves that edit in place | Must |

---

## Functional Requirements

### FR-1: Admin Sign-In and Authorization
- **Description**: Admins sign in to the web app with Google, reusing the
  backend's existing Google token exchange and session tokens. A user is an
  admin when their Google account email is in the `ADMIN_EMAILS` environment
  variable (comma-separated, compared case-insensitively). Every `/admin/*`
  endpoint checks this on the server.
- **Acceptance Criteria**:
  - No token → `401`; a valid non-admin token → `403` on every `/admin/*`
    endpoint; an admin token succeeds.
  - Removing an email from `ADMIN_EMAILS` revokes access on the next request
    (no re-login or migration needed).
  - The web app shows a "not authorised" screen to a signed-in non-admin and
    offers sign-out.
  - `ADMIN_EMAILS` unset or empty → nobody is an admin (fail closed).
- **Priority**: Must
- **Related Stories**: api/001, web/001

### FR-2: Browse the Content Tree
- **Description**: Navigate course → section → skill → lesson → exercises.
- **Acceptance Criteria**:
  - Every course and its full tree are listed in `order_index` order.
  - Each level shows the count of its children; each exercise shows its type
    and prompt, and listening exercises show whether they have real audio or
    still use the placeholder.
- **Priority**: Must
- **Related Stories**: api/003, web/002

### FR-3: Create, Edit, Reorder and Delete Content
- **Description**: Create, edit, reorder and delete sections, skills, lessons
  and exercises. Courses are listed and their titles are editable; creating a
  course (a new language pair) is out of scope.
- **Acceptance Criteria**:
  - Each operation persists to the database and appears in the learner API
    (skill tree, lesson fetch) on the next request.
  - Reordering is a single atomic request per parent and never leaves
    duplicate `order_index` values (the `(course_id, order_index)` uniqueness
    on categories holds).
  - New content gets a random UUID id; seeded content keeps its uuid5 id.
  - Deleting a skill or lesson that learners have progress or attempts on is
    refused with a message naming how many learners are affected; content
    with no learner history can be deleted, children included, after a
    confirmation.
- **Priority**: Must
- **Related Stories**: api/003, web/002

### FR-4: Per-Type Exercise Editors
- **Description**: A form for each of the six exercise types that edits its
  `prompt`, `content` and `answer_key` without exposing raw JSON. The correct
  answer is chosen in the form (e.g. marking a choice correct), not typed as
  an id.
- **Acceptance Criteria**:
  - Opening and saving any existing seeded exercise without changes leaves
    its stored `content` and `answer_key` identical.
  - The backend validates every write against the exercise type, using the
    same domain rules the lesson engine uses, and rejects invalid content with
    a `422` naming the field (e.g. answer key points at a missing choice,
    fewer than two choices).
  - Changing an exercise's type is not supported; delete and recreate instead.
- **Priority**: Must
- **Related Stories**: api/004, web/003

### FR-5: Audio: Record, Upload or Link
- **Description**: A listening exercise's editor offers three ways to set its
  `audio_url`, and a play button for the current clip:
  1. **Record** in the browser with the microphone (start, stop, listen back,
     re-record, then save).
  2. **Upload** an existing audio file from the computer.
  3. **Link** to audio already hosted elsewhere by pasting its URL.

  Recorded and uploaded clips go straight from the browser to R2 through a
  short-lived presigned PUT URL issued by the backend; a link is saved as
  given.
- **Acceptance Criteria**:
  - Record: the browser asks for microphone permission; a denied permission
    shows a message and leaves Upload and Link usable. The take can be played
    back and discarded before anything is uploaded. Recording prefers
    `audio/mp4` where the browser supports it.
  - Upload and Record: the backend chooses the object key -- ASCII only,
    under the course's language folder (e.g.
    `am/<lesson-slug>-<n>-<random>.m4a`). The presigned URL expires within
    10 minutes and only allows audio content types (`audio/mp4`,
    `audio/x-m4a`, `audio/mpeg`, `audio/webm`, `audio/ogg`) up to 5 MB. The
    saved `audio_url` is `AUDIO_BASE_URL` + key.
  - Link: only `https://` URLs are accepted. The backend checks the URL
    answers with an audio content type before saving and rejects it with a
    readable error otherwise.
  - Every saved `audio_url` is a full https URL that plays in the
    already-released app.
  - The R2 access keys exist only in the backend's environment and never
    appear in any response or in the web bundle.
- **Priority**: Must
- **Related Stories**: api/005, web/004

### FR-6: Seed Becomes Insert-Only
- **Description**: The lesson and course seeds only insert rows whose ids do
  not exist yet; they never update or delete existing rows. The database is
  the source of truth from then on.
- **Acceptance Criteria**:
  - Running the seed against an empty database produces today's content.
  - Running it after an admin edit leaves the edit untouched.
  - Running it twice in a row changes nothing (still idempotent).
- **Priority**: Must
- **Related Stories**: api/002

### FR-7: Preview an Exercise
- **Description**: A read-only preview showing an exercise roughly as the
  learner sees it, with its audio playable and the correct answer
  highlighted.
- **Acceptance Criteria**: The preview renders all six types from saved data.
- **Priority**: Should
- **Related Stories**: web/005

### FR-8: Vocabulary Management
- **Description**: List and edit `vocab_items` per course.
- **Acceptance Criteria**: Edits persist, and SRS practice keeps working for
  learners with existing progress on the edited items.
- **Priority**: Could
- **Related Stories**: api/006, web/006

---

## Non-Functional Requirements

### Security
| Requirement | Standard | Notes |
|-------------|----------|-------|
| Authorization | Server-side `ADMIN_EMAILS` check on every `/admin/*` endpoint | Fail closed when unset |
| Secrets | R2 keys only on the backend | Presigned URLs only; never in the web bundle or responses |
| CORS | Only the admin site's origin (and `localhost` in development) allowed on `/admin/*` | No wildcard origin |
| Audit | Each admin write is logged with the admin's email, entity, id and action | Existing structured logging |

### Performance
| Requirement | Metric | Target |
|-------------|--------|--------|
| Content tree load | Time to show one course's full tree | < 2 s on Vercel |
| Admin bundle | Gzipped JS | < 500 KB |

### Reliability
| Requirement | Metric | Target |
|-------------|--------|--------|
| Content integrity | Invalid exercises saved | 0 (server-side validation) |
| Learner impact | Breaking changes to the learner API | None; existing backend tests stay green |

---

## Constraints

### Technical Constraints

**Project-wide standards**: loaded from `memory-bank/standards/` by the
Construction Agent.

**Intent-specific constraints:**
- The front end is **Vite + React + TypeScript**, in a new `admin/` folder in
  this repo, deployed as its **own Vercel project** that calls
  `https://ethio-lang.vercel.app`. No UI component library; plain CSS.
- Edits are **live immediately**; there is no draft/publish step.
- Google sign-in on the web needs a Web OAuth client id in the existing Google
  Cloud project, and the backend must accept tokens issued to that client.
- R2 needs a CORS rule allowing `PUT` from the admin site's origin.
- `tech-stack.md` says there is "no teacher/admin/content-manager role". It
  is updated to record the backend-only admin role once these requirements
  are approved.

### Business Constraints
- Single maintainer; one to three admins.

---

## Assumptions

| Assumption | Risk if Invalid | Mitigation |
|------------|-----------------|------------|
| The backend's Google token check can accept a second (web) client id | Web sign-in rejected | Accept a list of allowed client ids |
| Content volume stays small (hundreds of exercises per course) | Tree loads slowly | Load per course; add paging later |
| Browsers that cannot record `audio/mp4` (e.g. Firefox) record WebM/Opus, which Android plays but iPhones may not | A clip recorded there is silent on iOS | Record in Chrome, Edge or Safari (all record mp4); the editor warns when a take is WebM |
| Linked audio stays online | A linked clip later breaks | The tree marks listening exercises whose link no longer answers (FR-2 audio status) |
| The R2 public dev URL is fixed before FR-5 is verified | Uploaded clips cannot play | Fix bucket public access first (currently 404) |

---

## Out of Scope

- Changes to the Flutter learner app.
- Creating new courses / language pairs.
- Draft and publish workflow, version history, undo.
- Multiple admin roles or permissions beyond "admin".
- Editing or trimming recordings in the browser, and converting audio
  formats on the server.

---

## Open Questions

| Question | Owner | Due Date | Resolution |
|----------|-------|----------|------------|
| Source of truth | User | Checkpoint 1 | Resolved: database; seed becomes insert-only (FR-6) |
| How admins are identified | User | Checkpoint 1 | Resolved: `ADMIN_EMAILS` env var (FR-1) |
| React setup and hosting | User | Checkpoint 1 | Resolved: Vite + React + TS, own Vercel project |
| Publishing model | User | Checkpoint 1 | Resolved: live immediately |
| Audio source | User | Checkpoint 2 | Resolved: record in the browser, upload a file, or paste a link (FR-5); recordings and uploads use presigned PUT to R2 |
| The local-only Audio Lab / `seed_local_audio.py` | Claude | Checkpoint 1 | Resolved by default: kept for local development until FR-5 ships, then removed in a later change |
