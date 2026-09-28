---
stage: plan
bolt: 040-admin-vocabulary
created: '2026-09-28T00:00:00Z'
---

## Implementation Plan: admin-vocabulary

### Objective

Give each course a Vocabulary page in the admin site: every word the
course tracks for Practice, where it is used, and an edit that keeps
learners' progress. Also fix the "Add exercise" type menu, which is cut
off inside its section card and cannot be scrolled (reported with a
screenshot on 2026-09-28).

### What the code says (checked before planning)

- **F1: What a vocab item is.**
  - A `vocab_items` row is a word and its translation in one course. The
    table has no other fields.
  - A seeded exercise may carry a `vocab_item_id`. That link is what puts
    the question into Practice.
  - Learner progress (`user_vocab_progress`) is keyed by the vocab item's
    id. Editing the text never touches it.
- **F2: Editing the word does not change what learners see today.**
  - Practice's due items send `word` and `translation` to the app, but no
    screen shows them.
  - The learner sees the linked exercise's own prompt and choices.
  - So a fixed word needs its exercise fixed too. The page therefore
    shows each word's exercise, with a link to its editor.
- **F3: Exercises made in the admin site never reach Practice.**
  - `ExerciseRequest` has no `vocab_item_id`, so only seeded exercises
    are linked.
  - The stories don't ask to fix this. It is offered as extension E1
    below, for you to decide.
- **F4: A word is practised through one exercise.** Practice keeps the
  first exercise per `vocab_item_id` (by exercise id). The seed never
  links two exercises to one word. The page still lists every exercise
  that points at a word.
- **F5: The menu bug.**
  - The menu is positioned `absolute` inside the lesson row.
  - The section and skill cards use `overflow-hidden` for their rounded
    corners, so the menu is clipped at the card's edge. Scrolling the
    page doesn't reveal it.
  - There are six types, so the menu is about 400 px tall. It is clipped
    whenever the lesson is near the bottom of its section.

### Decisions

- **D1: The list endpoint.** `GET /api/v1/admin/courses/{id}/vocab`
  returns every item in the course. Each item has:
  - `id`, `word`, `translation`
  - `learners`: how many learners have progress on it
  - `used_by`: each linked exercise, with its id, type, prompt, lesson
    id, and its section, skill and lesson titles and numbers (such as
    `5.1.1`), so the page can link to it

  Items come in curriculum order, by the position of their first
  exercise. Unused items come last, by word. An unknown course is a
  `404`.
- **D2: The edit endpoint.** `PATCH /api/v1/admin/vocab/{id}` takes
  `word` and/or `translation`.
  - Each is trimmed. Empty, or over 255 characters, is a `422` naming the
    field.
  - It returns the item in the same shape as the list.
  - It logs one `admin_write` line (action, `vocab`, id, admin) and never
    logs the text.
  - The id doesn't change, so progress rows are kept.
  - No lesson's `content_version` moves, because downloaded lesson packs
    don't contain the word.
- **D3: Where the code goes.** Vocab queries go in
  `admin_content_repository.py`, and `list_vocab` and `update_vocab` in
  `admin_content_use_cases.py`. The routes and schemas sit beside the
  others. Nothing touches the learner-side code. No migration is needed.
- **D4: The page.** `/courses/:courseId/vocabulary`, reached from:
  - a "Vocabulary" button in the course header, next to "Rename course"
  - the sidebar's "Vocabulary" item. It is no longer a "Soon" label: it
    opens `/vocabulary`, which lists the courses to choose from. The
    "Coming next" heading goes, since nothing is left under it.

  The page has:
  - **Breadcrumb:** Courses › course › Vocabulary.
  - **Stat tiles:** Words, In exercises, Not used, and Learners
    practising (distinct learners).
  - **Search:** a box matching word or translation, case-insensitive, on
    the page itself.
  - **One row per word:** the word (large, it's usually Ge'ez), the
    translation, a learner-count badge, and each exercise as a link to its
    editor ("5.1.1 Basic Colors · Multiple choice").
  - **Unused words:** they show "Not in any exercise".
  - **Editing:**
    - **Opening it:** Edit turns the row into two fields with Save and
      Cancel.
    - **The note:** a line under the fields: "Learners keep their
      progress. The question itself is edited in its exercise."
    - **After saving:** the list reloads from the server, as the tree does.
    - **Errors:** a server `422` shows under its field; other errors show
      in the page's alert banner.
  - **Loading and errors:** a loading skeleton, and the same error panel
    as the course page (not found, or try again).
  - **Phones:** rows stack at phone width, and nothing scrolls sideways
    at 360 px.
- **D5: The menu fix.** The menu is drawn in a portal on
  `document.body`, positioned `fixed` against the button, so no card can
  clip it.
  - **Width and alignment:** 18 rem wide, or the screen width less 16 px
    if that's smaller. Its right edge lines up with the button, and it is
    kept 8 px inside the screen.
  - **Direction:** it opens below the button. If it doesn't fit below and
    there is more room above, it opens above.
  - **Height:** it is capped at the room available, less 8 px. The list
    then scrolls inside it (`overflow-y: auto`, with contained
    overscroll).
  - **Keeping up with the page:** it follows the button when the page
    scrolls or the window resizes.
  - **Closing:** it closes on a click outside the button and the menu, on
    Escape (focus returns to the button), and when a type is chosen.
  - **Keyboard:** opening it moves focus to the first type. The up and
    down arrows, Home and End move between types.
  - **Unchanged:** the links, their labels and the `nav` landmark stay as
    they are, so existing tests keep working.

### Extension E1 (your call; not in the stories)

- **Linking an exercise to a practice word (F3).** The exercise editor
  gets a "Practice" panel with three choices:
  - not tracked
  - one of the course's unused words
  - a new word, with its translation

  The backend changes:
  - `ExerciseRequest` gains an optional `vocab_item_id`, or an optional
    `new_vocab {word, translation}`.
  - The word must be in the exercise's course.
  - A word already linked to another exercise is refused (F4).

  Why it matters: questions made in the admin site then reach Practice.
  Without it, the Vocabulary page only edits seeded words. It adds about
  half this bolt again.

### Deliverables

- **Backend:**
  - `admin_content_repository.py`: the course vocab query, with exercise
    locations and learner counts
  - `admin_content_use_cases.py`: `list_vocab`, `update_vocab`
  - `admin_schemas.py`: `AdminVocabItem`, `AdminVocabUse`,
    `AdminVocabList`, `UpdateVocabRequest`
  - `admin_routers.py`: the two routes
  - `tests/integration/test_admin_vocab_api.py`
- **Admin site:**
  - `admin/src/vocab/VocabularyPage.tsx`: the page, rows and inline edit
  - `admin/src/vocab/CoursePicker.tsx`: `/vocabulary`
  - `App.tsx`: the two routes
  - `shell/AppShell.tsx`: the real nav item, with "Coming next" removed
  - `tree/CourseTree.tsx`: the Vocabulary button
  - `tree/levels.ts`: the `vocab` routes
  - `types.ts`: the vocab types
  - `exercises/AddExerciseMenu.tsx`: the portal menu
  - **Tests:** `vocab/vocabulary.test.tsx` and
    `exercises/addExerciseMenu.test.tsx`

### Dependencies

- Bolts 035 (admin API), 037 (admin shell) and 038 (the exercise editor
  route the links open). All are complete.
- No new packages, no migration, and no Neon, Vercel or R2 change.

### Out of Scope

- Creating or deleting words (the story says deletion is out for v1).
  Creating words is part of E1 only.
- Bulk import, audio per word, and showing the word in the learner app.

### Acceptance Criteria

**Story 006-vocabulary-api**
- [ ] `GET /admin/courses/{id}/vocab` lists that course's items only,
      with their exercises and learner counts, in curriculum order.
      Unused items come last. An unknown course is a `404`, and a
      non-admin is a `403`.
- [ ] `PATCH /admin/vocab/{id}` trims and saves. Empty or over-long
      fields are a `422` naming the field. An unknown id is a `404`.
- [ ] After editing an item with learner progress, the progress rows are
      unchanged, and `GET /practice/due-items` still serves it, with the
      new word.

**Story 006-vocabulary-screen**
- [ ] From the course page and from the sidebar, Vocabulary opens the
      course's words. Each can be edited and saved, and the list shows the
      saved text.
- [ ] Search narrows the list by word or translation. Unused words are
      marked.
- [ ] Each exercise link opens that exercise's editor.
- [ ] A `422` shows under its field. Loading, empty and error states
      show. At 360 px nothing scrolls sideways.

**The menu fix**
- [ ] The menu isn't inside any card (it's in a portal), so a lesson at
      the bottom of a section shows the whole menu.
- [ ] With little room below, it opens above. With little room either
      way, it is capped and scrolls.
- [ ] Escape, an outside click and choosing a type close it. The arrow
      keys move between types.

**Baselines**
- [ ] All existing backend and admin tests pass. `ruff`, `mypy`,
      `eslint` and `tsc -b` stay clean.

### Test Plan

- **Backend (`test_admin_vocab_api.py`):**
  - the list's scope, order, `used_by` and learner counts
  - an unused item
  - `404` and `403`
  - `PATCH`: trimming, the `422`s, `404`, and the log line without the
    text
  - progress kept and the item still due with the new word
- **`vocabulary.test.tsx`** (fake server):
  - the list, stat tiles and search
  - edit, save and reload
  - a `422` under its field
  - the links go to the exercise editor
  - the empty course, `404` and network errors
  - the sidebar and course-page entry points
- **`addExerciseMenu.test.tsx`:**
  - the menu isn't inside the lesson row
  - it opens above when the button is near the bottom (with a stubbed
    rect and window height)
  - the height cap
  - outside click, Escape (focus returns), and arrow, Home and End
  - the links go to the editor

---

## Implementation Notes (Stage 2)

Kept in this file at the user's request: one markdown file per bolt.

### What was built

- **Backend:**
  - `admin_content_repository.py`:
    - `course_outline`, split out of `course_tree`, which now uses it
    - `course_vocab`: the items, the exercises pointing at them within
      the course's lessons, per-item learner counts and the distinct
      total
    - `vocab_uses` and `vocab_learners` for one item
  - `admin_content_use_cases.py`: `list_vocab` and `update_vocab` (both
    fields checked before either is written; logged as
    `entity=vocab`)
  - `admin_schemas.py`: `AdminVocabUse`, `AdminVocabItem`,
    `AdminVocabList`, `UpdateVocabRequest`
  - `admin_routers.py`: `GET /courses/{id}/vocab` and
    `PATCH /vocab/{id}`, with the numbering (`_places`, the tree's
    1-based per-parent count) and the ordering (`_vocab_items`)
- **Admin site:**
  - `vocab/VocabularyPage.tsx`: the page, the rows, the inline edit
    form, search, stat tiles, and the loading, error and empty states
  - `tree/CourseList.tsx`: a `purpose` prop, so `/vocabulary` reuses the
    course list with its own wording and links
  - `App.tsx`: `/vocabulary` and `/courses/:courseId/vocabulary`
  - `shell/AppShell.tsx`: Curriculum and Vocabulary as real nav items;
    "Coming next" removed
  - `tree/CourseTree.tsx`: the Vocabulary link in the course header
  - `tree/levels.ts`, `types.ts`: the routes and shapes
  - `ui/popover.ts` (new): `placePopover`, the pure placement rule
  - `exercises/AddExerciseMenu.tsx`: the menu in a portal, placed by
    `placePopover`, measured unseen before its first paint, kept with
    the button on scroll and resize, with the keyboard handling
  - `ui/Button.tsx`: accepts a `ref` (React 19 prop), for the menu's
    anchor

### Deviations from the plan

- **No `CoursePicker.tsx`:** `/vocabulary` reuses `CourseList` with a
  `purpose` prop instead of a second list.
- **Breadcrumb:** "Vocabulary › course", with a Curriculum link in the
  page header, rather than "Courses › course › Vocabulary". It keeps the
  breadcrumb inside the section the sidebar marks as current.
- **New `ui/popover.ts`:** the placement maths lives in its own pure
  module so the tests can check it without a layout engine.

### Checks

Run by the user, because the agent's shell was blocked (the auto-mode
safety check returned no verdict):
- **Admin site:** `tsc -b`, `eslint src` and `prettier --check src` were
  clean.
- **Backend:** `ruff check app` and `mypy app` were clean.
- **Tests:** `test_admin_content_endpoints.py` passed, 55 tests. That
  includes the every-route admin-only check, which now covers the two new
  routes.

The full suites run in Stage 3.

---

## Test Report (Stage 3)

### Summary

- **Tests:** all pass. The backend has 1280 tests, with the new vocab
  API file included. The admin site suite (`vitest run`) passes in full,
  including the new files.
- **Who ran them:** the user, because the agent's shell was still
  blocked. `tsc -b`, `eslint`, `prettier --check`, `ruff check` and
  `ruff format --check` were clean.
- **Coverage:** not measured; neither suite is configured for it.

### Test Files

- [x] `backend/tests/integration/test_admin_vocab_api.py` (18 tests)
  - **The list:**
    - its scope is the course only, while other courses have words too
    - every linked exercise, with its type, prompt, lesson and number,
      checked against the tree's own numbering
    - curriculum order, unused words last by word
    - learner counts per word, and distinct learners in total
    - an empty course, and an unknown course (`404`)
  - **The edit:**
    - trimmed, saved, and answered in the list's shape
    - one field alone leaves the other
    - `422`s for empty and 256-character text, naming the field, with
      nothing written even when the other field was valid; 255 is
      allowed
    - an unknown word is a `404`
    - learner progress kept byte for byte, and `GET
      /practice/due-items` serving the word with its new text
    - one log line, without the text; a refused edit logs nothing
- [x] `admin/src/vocab/vocabulary.test.tsx` (12 tests)
  - **The page:**
    - the rows, links (address and place), learner badge and "Not in
      any exercise"
    - the stat tiles and search (Latin and Ge'ez)
    - edit, save and reload, and the `PATCH` body trimmed
    - Save disabled on an empty field; Cancel and Escape close without
      saving
    - a `422` under its field, and other errors in the banner, with a
      reload
    - the empty, not-found and offline states, and Try again
  - **Getting there:** from the sidebar through `/vocabulary` (nav
    highlighting and no "Soon"), and from the course page and back to
    the curriculum.
- [x] `admin/src/exercises/addExerciseMenu.test.tsx` (12 tests)
  - **Placement:**
    - in a portal on `document.body`, outside a card with hidden
      overflow
    - below the button, right-aligned, when there is room; above near
      the bottom of the window
    - capped and scrolling when neither side fits
    - following the button on window scroll and on scrolls inside
      other elements
  - **Keyboard and closing:**
    - focus on the first type; the arrow keys, Home and End, wrapping
      at both ends
    - Escape and Tab close and return focus to the button
    - an outside click closes it, an inside click doesn't, and the
      button toggles it
    - choosing a type opens its editor
    - the listeners are removed on close
- [x] `admin/src/ui/popover.test.ts` (7 tests): below, above, capped
  either way, phone width, the edge margins, and never a negative room.

### Acceptance Criteria Validation

- ✅ **The list:** `GET /admin/courses/{id}/vocab` lists the course's
  words with their exercises and learner counts, in curriculum order,
  unused words last; `404` and `403` (`TestAccess` covers every admin
  route).
- ✅ **The edit:** `PATCH /admin/vocab/{id}` trims; `422` for empty or
  too-long text, naming the field; `404` for an unknown word.
- ✅ **Progress:** after an edit it is unchanged, and Practice still
  serves the word with the new text.
- ✅ **Screen:** Vocabulary opens from the course page and the sidebar,
  and words are edited, saved and shown as saved.
- ✅ **Search** and the unused-word marking.
- ✅ **Exercise links** go to the exercise editor.
- ✅ **Errors:** a `422` shows under its field, and the loading, empty
  and error states all show.
- ⏳ **360 px width:** no sideways scroll on a phone isn't tested
  automatically (jsdom has no layout). It is left for a look in a
  browser.
- ✅ **Menu fix:** the menu is in a portal and no card clips it; it
  opens upward, is capped and scrolls, and closes on Escape, a click
  outside and a choice. The arrow keys work.
- ✅ **Baselines:** both full suites and all linters are clean.

### Issues Found

None in the tests. The agent's shell was blocked throughout Stages 2
and 3, so every check was run by the user and reported back.

### Notes

- **What editing changes for learners:** as planned (F2), editing a word
  changes nothing they see today. The app doesn't display vocab text.
  The page says the question itself is edited in its exercise, and
  links there.
- **Follow-up (E1):** linking admin-made exercises to a practice word,
  so they reach Practice, remains open.
- **Deployment:** no migration, so nothing to run on Neon. The backend
  and the admin site both need deploying for the page to work in
  production.
