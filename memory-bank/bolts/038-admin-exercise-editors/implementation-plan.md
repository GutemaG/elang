---
stage: plan
bolt: 038-admin-exercise-editors
created: '2026-09-24T08:03:32Z'
---

## Implementation Plan: content-admin-web

### Objective

An admin can add, edit, preview, reorder and delete the exercises in a lesson,
with a proper form for each of the six types and no JSON typed by hand.
Opening any existing exercise and saving it unchanged sends back exactly what
the server had.

### What the code and data showed

1. **The API is already there** (bolt 035). The endpoints are:
   - `GET /lessons/{id}/exercises` (full `content` and `answer_key`)
   - `POST /lessons/{id}/exercises`
   - `PUT /exercises/{id}` (the type cannot change: `422 type`)
   - `PUT /lessons/{id}/exercises/order`
   - `DELETE /exercises/{id}`, which needs no confirmation because nothing
     references an exercise

   There is no single-exercise `GET`, so the editor reads the lesson's list
   and picks one.
2. **A `422` names one field**, as a path: `prompt`, `content.audio_url`,
   `content.choices[2].text`, `answer_key.correct_choice_id`,
   `answer_key.correct_sequence[1]`, `answer_key.correct_pairs`, and so on.
3. **The 181 seeded exercises** in `dev.db` break down as: 64
   multiple choice, 36 listening, 32 sentence construction, 17 match pairs,
   16 gap fill and 16 spell tiles. Their id conventions:
   - choices: `a`, `b`, `c`…
   - word bank: `w1…`
   - spelling tiles: `t1…`
   - match pairs: `l1…` on the left, `r1…` on the right
4. **The server's rules** the forms must respect:
   - at least 2 choices, 2 spelling tiles and 2 pairs, and 1 word-bank tile
   - match-pairs columns of equal length, with every left tile paired to a
     different right tile
   - gap fill needs text on at least one side of the gap
   - a sequence uses each tile at most once and may leave some out as
     distractors
   - ids are unique within their list
   - listening audio is `https://…`, or `/media/…` locally
5. **The existing test "offers no child below a lesson (exercises come
   later)"** has to change: lessons now get "Add exercise".

### Deliverables

**Where it lives**
- **In the course tree**, a lesson's exercise list gains:
  - **Edit** and **Preview** on each exercise
  - **Move up / down**, which sends the whole order, as the tree does
  - **Delete**, with a simple confirm dialog
  - **Add exercise** on the lesson row, which asks for the type once
- **The editor page**:
  - addresses: `/courses/:courseId/lessons/:lessonId/exercises/:exerciseId`,
    and `…/exercises/new/:type` for a new one
  - layout: the form on the left and a live **learner preview** on the right;
    on a phone, the preview sits below the form
  - saving: **Save** sends the `PUT` (or `POST` for a new exercise), then
    reloads from the server; a message says it is saved, and the page shows
    when there are unsaved changes
  - Back returns to the course, keeping the lesson open

**The forms**, one component per type, driven by the type:

| Type | Form |
|---|---|
| Multiple choice | Prompt, then choices (add, edit, remove, move) with a "correct" radio button on each. |
| Listening | As multiple choice, plus an audio address field with a Play button. It accepts `https://…` or a local `/media/…` path. Recording and upload come in bolt 039. |
| Gap fill | Prompt, then "text before", a visible gap and "text after", then choices with a "correct" radio button. |
| Sentence construction | Prompt, then the word bank (add, edit, remove). Then **Correct sentence**: click bank tiles to build the answer in order; each tile is used once; answer tiles can be removed or moved. Tiles left out are shown as distractors. |
| Spell tiles | The same builder as the sentence, over letter tiles. Two tiles showing the same letter stay separate tiles with separate ids, so `ሰ ላ ላ ም` is not confused. |
| Match pairs | Rows of *left ↔ right*: add, edit or remove a row. |

**Rules the forms follow**
- **No ids are ever typed.**
  - A new tile gets the next free id in its list's own convention (`e`
    after `a–d`, `w5` after `w4`, `t6`, `l5`/`r5`).
  - Removing a tile also removes it from the answer: it leaves the answer
    sequence, leaves its pair, or clears the correct choice. A choice-based
    exercise cannot be saved until a correct choice is marked again.
- **Round-trip exactness**:
  - The form edits the stored lists in place, keeping ids and order, and
    changes only what the admin changes.
  - Match pairs keeps the stored order of both columns and of
    `correct_pairs`, even when the right column is stored in a different
    order from the pairs.
  - "Identical" means equal as JSON values; key order within an object
    does not matter to the server.
- **Server errors appear beside their field.** A `422` field path is mapped
  to the input it names: the choice row, the audio field, the sequence and
  so on. Anything unmapped shows at the top of the form.
- **The type is fixed at creation.** It is shown, not editable.

**The preview** is an approximation of the learner's screen, not a pixel
copy. It renders from the form's current values, so it matches the saved
exercise once it is saved:
- a phone-sized card showing the prompt
- the choices, with the correct one highlighted
- the gap filled in with the correct word
- the bank tiles, and the answer line in the correct order
- the pairs matched by colour
- for listening, a working audio player; `/media/…` addresses are resolved
  against `VITE_API_BASE_URL`

**Data for the load-bearing test**
- A small backend script, `backend/scripts/export_exercise_fixtures.py`:
  - seeds a temporary SQLite database with the main seed, never `dev.db`
    or Neon
  - writes every seeded exercise to
    `admin/src/test/fixtures/seeded-exercises.json`
- Both are committed, so the admin tests need no backend, and the fixture
  can be regenerated when the seed changes.

### Tests (Stage 3)

**Written first**
- **Round trip over every seeded exercise:** each one loads into its form's
  model and serialises back equal to the original.
- **Round trip through the form itself:** for one exercise of each type,
  open the page, press Save unchanged, and check the `PUT` body equals the
  stored exercise.

**Then**
- **Choosing the correct answer:** marking a choice sets
  `correct_choice_id`; removing the correct choice clears it and blocks
  saving.
- **Sequences:** building one records ids in click order; spelling tiles
  with repeated letters stay distinct; distractors stay in the bank but out
  of the answer.
- **Match pairs:** adding and removing rows keeps both columns and the pairs
  in step.
- **New tiles:** each gets the next free id in its list's convention.
- **Server errors:** a `422` shows beside the field it names; an unmapped
  one shows at the top.
- **A new exercise:** the type is chosen once and sent in the `POST`; the
  editor then has no way to change it.
- **The preview:** each type renders with the correct answer highlighted,
  and the listening audio source is resolved correctly.
- **The tree:** a lesson offers Add exercise; exercises can be moved (the
  whole order is sent), deleted after confirming, and opened for editing.
- **Existing tests:** the 50 existing admin tests still pass, with the one
  "no child below a lesson" test updated.

### Out of scope

- Recording or uploading audio (bolt 039, on top of bolt 041's store). A
  local `/media/…` path from an upload can already be pasted.
- Linking exercises to vocabulary (`vocab_item_id`, bolt 040).
- Asking before leaving a page with unsaved changes. `BrowserRouter` cannot
  block navigation inside the app; the page shows an "Unsaved changes"
  marker instead, and the browser warns on a reload or closing the tab.
- Moving an exercise to another lesson.
