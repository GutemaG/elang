---
intent: 019-image-choice-exercise-types
phase: inception
status: complete
created: '2026-09-24T21:22:18Z'
updated: '2026-09-25T06:23:36Z'
---

# Requirements: image-choice-exercise-types

## Intent Overview

Add two question types where the answers are pictures:

- **Image choice (`image_choice`):** the learner reads a word or question
  in the course language (for example "ቡና") and taps the picture that
  matches it.
- **Audio image choice (`audio_image_choice`):** the learner hears a clip
  and taps the picture that matches it. Only the instruction and the play
  button are shown. The clip plays by itself when the question appears
  (bolt 045's rule), and the play button replays it.

Both types reach the whole stack:

- the backend's content model and API
- picture storage, beside the audio (R2 in production, the local backend
  in development)
- the admin site's editors, with picture upload
- offline lesson downloads
- practice sessions
- the mobile lesson, through a picture tile added to the question kit
  (018-mobile-design-system)

**Type:** New feature, brown-field. It extends the exercise-type dispatch
that `004-match-pairs`, `015-gap-fill` and `016-spell-from-tiles` extended
before it.

## Checkpoint 1 Answers (2026-09-24)

| # | Question | Answer |
|---|----------|--------|
| 1 | Where pictures come from | **b**: each question's pictures are uploaded with that question, with no shared library |
| 2 | How many, and labelled? | **a**: 2 to 4 pictures in a 2×2 grid, no caption, with a hidden description for screen readers |
| 3 | What the audio question shows | **a**: the instruction and the play button only |
| 4 | Offline | **a**: downloaded lessons include their pictures |
| 5 | Picture files | **a**: JPEG, PNG or WebP in; the admin site shrinks to at most 512×512 and uploads WebP or JPEG |
| 6 | Sample pictures | **c**: I choose free-licensed pictures and download them for the sample content |
| 7 | Practice sessions | **a**: picture questions linked to a vocabulary word appear in practice |

## Business Goals

| Goal | Success Metric | Priority |
|------|----------------|----------|
| Teach concrete words by meaning rather than by translation | A course can include both types, and a learner can answer them in a lesson, a downloaded lesson and practice | Must |
| Let content authors build picture questions without a developer | An admin creates, previews and saves either type, pictures included, entirely in the admin site | Must |
| Keep the lesson one consistent experience | The picture questions use the same frame, prompt, action bar and grading behaviour as the other five types | Must |
| Keep lessons light on data | A picture is at most 300 KB after upload, and typically under 150 KB | Should |

---

## Functional Requirements

### FR-1: Image Choice Content Type
- **Description:** The backend stores and serves an `image_choice` question.
  - **Its content:** a prompt, and 2 to 4 picture choices. Each choice has
    an id, a picture reference and a short description (alt text).
  - **The prompt** is text in the course language. It may use the existing
    `Instruction: 'content'` shape, which the app splits into two lines.
  - **Its answer key** is the correct choice's id, the same `ChoiceAnswerKey`
    that multiple choice, listening and gap fill use.
  - The lesson API returns it like the other types. The picture reference is
    a path the app resolves against the API, as audio already is.
- **Acceptance Criteria:**
  - An `image_choice` question with 2, 3 or 4 choices saves, and the lesson
    API returns it.
  - It is rejected, with a field-level error, when it has fewer than 2 or
    more than 4 choices, a repeated choice id, a missing picture, missing
    alt text, or an answer key that names no choice.
  - `exercises.type` accepts `image_choice`, both in the model's check
    constraint and in a migration.
- **Priority:** Must

### FR-2: Audio Image Choice Content Type
- **Description:** The backend stores and serves an `audio_image_choice`
  question.
  - **Its content:** an instruction (for example "Tap what you hear"), an
    audio clip reference, and 2 to 4 picture choices shaped as in FR-1.
  - **Its answer key** is the correct choice's id.
- **Acceptance Criteria:**
  - An `audio_image_choice` question with a clip and 2 to 4 choices saves,
    and the lesson API returns it.
  - It is rejected, with a field-level error, when the clip is missing, or
    on any of FR-1's choice errors.
  - `exercises.type` accepts `audio_image_choice`.
- **Priority:** Must

### FR-3: Picture Storage
- **Description:** Pictures are uploaded and served the way audio is today.
  - The admin site asks the backend for a short-lived upload link, bound to
    one content type and exact size, and uploads straight to storage: R2 in
    production, the local backend's media folder in development.
  - Each question's pictures are uploaded with that question (answer 1b).
    There is no shared picture library.
  - Pictures are served at public URLs, like the audio.
- **Acceptance Criteria:**
  - An upload link is issued only to a signed-in admin, only for
    `image/webp` or `image/jpeg`, and only for 1 byte to 1 MB. Anything
    else is refused with a field-level error.
  - The link expires after 10 minutes, as audio's does.
  - An uploaded picture's reference saves into a choice and loads in the
    app, both in development and in production.
  - Stored picture keys follow the audio layout, under the course language
    and the lesson.
- **Priority:** Must

### FR-4: Admin Editors for Both Types
- **Description:** The admin site's "add exercise" menu offers both types,
  each with an editor and a preview.
  - **Image choice editor:** the prompt, and 2 to 4 picture slots. Each slot
    has an upload, its alt text and a "correct" marker.
  - **Audio image choice editor:** the same picture slots, plus the
    existing audio field (record or upload) and the instruction.
  - **Before uploading, the browser shrinks each picture:**
    - It accepts JPEG, PNG or WebP.
    - It scales the longest side down to 512 px and never scales up.
    - It encodes as WebP. Where the browser cannot encode WebP, it uses
      JPEG instead.
  - **The preview** shows the question as the learner sees it: the grid,
    and the audio play button.
- **Acceptance Criteria:**
  - An admin creates, edits and saves each type, and it round-trips through
    the API unchanged.
  - A 4000×3000 JPEG uploads as a picture no larger than 512×384, and at
    most 300 KB.
  - Save is blocked, with the reason shown beside the field, when a slot
    has no picture or no alt text, when no slot is marked correct, or when
    there are fewer than 2 slots.
  - Adding a fifth slot is not offered.
  - A file that is not a picture, or is over 10 MB before shrinking, is
    refused with a message before any upload.
- **Priority:** Must

### FR-5: Picture Tile and Lesson Screens
- **Description:** The lesson shows both types in the question kit's frame.
  - **A picture tile** is added to the kit. It has the six `AnswerTile`
    states and the same press, shelf, shake and colours, with the picture
    in place of the label.
  - **Layout:** 2 to 4 tiles in a 2×2 grid. Three pictures sit as two, then
    one, with every tile the same size.
  - **Image choice:** `QuestionPrompt` with the prompt, then the grid.
  - **Audio image choice:** the instruction and the large `AudioPlayButton`
    only, with no written word. The clip plays by itself on first
    appearance.
  - **Grading** happens on the tap, as for multiple choice: only the chosen
    tile shows right or wrong, and wrong costs a bean and requeues the
    question.
  - **Screen readers** hear each tile's alt text, with its button and
    selected state.
  - **The picture shows in full**, fitted inside the tile without cropping.
  - **While a picture loads**, the tile shows a quiet placeholder. If it
    fails to load, the tile shows its alt text and can still be answered.
- **Acceptance Criteria:**
  - Both types appear in the component gallery, in every state, with 2, 3
    and 4 pictures.
  - In the lesson, both types sit in the same frame as the other five, and
    the frame test covers them.
  - A tap grades the question. The chosen tile shows correct or incorrect,
    the incorrect one shakes, and the others stop taking taps.
  - Each tile's screen-reader label is its alt text.
  - A picture that fails to load shows its alt text, and the question can
    still be answered and graded.
  - No overflow at 320 and 360 px, at 1.0× and 1.3× text.
  - The audio question plays its clip once when it appears, and not again
    on a rebuild or an answer.
  - Tiles are built only from the kit and theme tokens, and the rules test
    passes with no new allow-list entries.
- **Priority:** Must

### FR-6: Offline Lessons
- **Description:** Downloading a lesson also downloads its pictures, and
  the audio for audio-image questions. The pack refers to them by local
  path, as packs already do for listening audio.
- **Acceptance Criteria:**
  - A downloaded lesson with both types plays fully with no network: every
    picture shows, and the clip plays.
  - If any picture or clip fails to download, no partial pack is saved, and
    the download reports failure, as today.
  - A cached copy of a lesson (not a download) whose questions need
    pictures or audio is not opened offline. The learner sees the
    "download required" state, as for listening today.
  - Removing a download removes its pictures.
- **Priority:** Must

### FR-7: Practice Sessions
- **Description:** A picture question linked to a vocabulary word counts
  toward that word's review, and can be chosen for a practice session, like
  the other types.
- **Acceptance Criteria:**
  - A due vocabulary word whose question is `image_choice` or
    `audio_image_choice` appears in practice as that question.
  - Answering it updates the word's review progress, as for the other types.
- **Priority:** Must

### FR-8: Sample Content with Free-Licensed Pictures
- **Description:** The existing Amharic course gains sample questions of
  both types, using pictures I choose and download.
  - Each picture's licence allows commercial use and redistribution:
    CC0, CC BY or CC BY-SA.
  - Each picture's source, author and licence are recorded in a credits
    file in the repository.
  - Pictures that need attribution are credited in the app's licences
    page.
  - The pictures are processed as the admin site would process them: at
    most 512 px, WebP or JPEG.
- **Acceptance Criteria:**
  - At least 3 `image_choice` and 2 `audio_image_choice` questions are
    seeded, each linked to a vocabulary word.
  - Every seeded picture has an entry in the credits file with its source
    URL, author and licence.
  - The app's licences page lists the picture credits.
  - The seed works in development with local media. Uploading the
    pictures to production R2, and seeding Neon, wait for the owner's
    go-ahead.
- **Priority:** Must

### FR-9: Older App Versions
- **Description:** An installed app that predates these types keeps
  working when a lesson contains them.
- **Acceptance Criteria:**
  - An app without the new types skips them and completes the lesson. This
    is the existing handling of unknown types, counted in
    `unrenderableCount`. A test with a lesson holding a new type confirms
    it.
- **Priority:** Must

### FR-10: Pictures Ready Before Their Question
- **Description:** When a lesson starts, the app starts loading every
  picture it will need. A picture question then rarely waits on the
  network.
- **Acceptance Criteria:**
  - On lesson start, all of the lesson's picture URLs are requested for
    caching.
  - A failed early request does not block the lesson; the tile loads again
    when shown.
- **Priority:** Should

---

## Non-Functional Requirements

### Performance
| Requirement | Metric | Target |
|-------------|--------|--------|
| Picture size | Bytes per stored picture | ≤ 300 KB; typically < 150 KB |
| Picture dimensions | Longest side | ≤ 512 px |
| Question with 4 pictures | Total picture bytes | ≤ 1.2 MB |
| Lesson with pictures | Frame time while tiles load | No dropped frames from decoding. Pictures are decoded at tile size (`cacheWidth` / `cacheHeight`). |

### Security
| Requirement | Standard | Notes |
|-------------|----------|-------|
| Upload authorisation | Admin session, as for audio | Only signed-in admins get upload links |
| Upload limits | Signed PUT link bound to content type and exact size | `image/webp` or `image/jpeg`, ≤ 1 MB, 10-minute expiry |
| Storage credentials | R2 keys server-side only | Never committed, never in a `VITE_` variable |

### Accessibility
| Requirement | Metric | Target |
|-------------|--------|--------|
| Alt text | Every picture choice | Required to save; read as the tile's label |
| Tap target | Picture tile | ≥ 48×48 px at every text scale |
| Text scale | Prompt and grid at 1.3× on 320 px | No clipping or overflow |
| Reduced motion | Shake and panel | Follow the kit (none under reduced motion) |

### Reliability
| Requirement | Metric | Target |
|-------------|--------|--------|
| Failed picture | Question still answerable | 100%: alt text shown in place of the picture |
| Offline pack | Partial packs | Never saved |

### Compatibility
| Requirement | Metric | Target |
|-------------|--------|--------|
| Flutter web | Pictures from R2 | R2 serves pictures with CORS headers that let the web app draw them |
| Admin browsers | Shrinking | Chrome, Edge, Firefox and Safari; JPEG where WebP encoding is missing |

---

## Constraints

### Technical Constraints

**Project-wide standards:** loaded by the Construction Agent from the
memory bank.

**Intent-specific constraints:**
- **Neon:** the production database needs a migration to widen the
  `exercises.type` check constraint. It runs only with the owner's
  explicit go-ahead. The same goes for seeding production.
- **R2:** keys stay server-side on Vercel. Uploading sample pictures to
  production R2, and any R2 CORS change, happen only with the owner's
  go-ahead.
- **Design:** the picture tile lives in `lib/shared/widgets/exercise/` and
  uses only Highland Pulse tokens. The rules-test allow-list may not grow.
- **Answer key:** these types reuse `ChoiceAnswerKey`, so grading and the
  answer-key checks stay as they are.

### Business Constraints
- Sample pictures must be free-licensed for commercial use, with
  attribution where the licence asks for it.

---

## Assumptions

| Assumption | Risk if Invalid | Mitigation |
|------------|-----------------|------------|
| Uploading pictures per question (1b) is acceptable, even when the same picture is reused | Duplicate uploads and storage | Pictures are small (≤ 300 KB). A shared library can be a later intent. |
| Older app versions already skip unknown types via `unrenderableCount` | An old app crashes on the new types | FR-9 adds a test. Verify before seeding production. |
| R2 can serve pictures with CORS for Flutter web | Pictures don't draw on the web build | Check the bucket's CORS in construction. The change needs the owner's go-ahead. |
| Free-licensed pictures exist for the sample words (coffee, water, bread, tea and so on) | Sample content is thin | Pick sample words by the pictures available. |
| Browser-side shrinking gives ≤ 300 KB at 512 px | An upload is over the limit | Lower the quality step by step until the picture is ≤ 300 KB. |

---

## Open Questions

| Question | Owner | Due Date | Resolution |
|----------|-------|----------|------------|
| Which picture set to use for samples (for example OpenMoji CC BY-SA 4.0, Twemoji CC BY 4.0, or Wikimedia Commons photos) | Claude, at the service bolt's Plan | Before seeding | Pending: chosen by licence and fit, and recorded in the credits file |
| Where old unused pictures go when a choice's picture is replaced | Owner | Later | Pending: out of scope here; files are left in storage, as audio is today |
