---
stage: test
bolt: 038-admin-exercise-editors
created: '2026-09-24T08:50:00Z'
---

## Test Report: content-admin-web

### Summary

- **Tests**: 330/330 pass (`npm test`, Vitest on jsdom), in about 25 s. The
  suite was 50 tests before this bolt.
- **Types, lint and build**: `tsc -b` and `eslint` are clean, and the build
  succeeds. JS is 100.7 KB gzipped (87.6 KB before this bolt). The 95 KB
  seed fixture is test-only and not bundled.
- **Falsification**: 14 deliberate breakages, every one caught. The sources
  were restored byte for byte.
- **Backend**: unchanged apart from the new, standalone exporter script. No
  backend test touches it.

### Test Files

- [x] `admin/src/exercises/roundtrip.test.tsx` (178), written first, in
  Stage 2:
  - The export holds all six types.
  - **Every one of the 177 seeded exercises** is opened in the real editor
    page and saved unchanged. The `PUT` body must equal the stored
    `{type, prompt, content, answer_key}`.
- [x] `admin/src/exercises/model.test.ts` (64). Every draft is deep-frozen
  first, so any change made in place instead of copied would throw.
  - **ids**
    - Next free letter, including gaps.
    - Prefix plus next number (`w5`, `t4`, `l3`).
    - The fallback for a list that follows no single convention.
    - Numbers once `a–z` are used.
    - Never an id already taken.
  - **A stored exercise** is deep-copied, and each blank has its type.
  - **Choices**
    - Marking one sets the answer.
    - A new choice gets `e`.
    - Editing text keeps ids and answer.
    - Removing the correct choice clears the answer and reports it missing;
      removing another keeps it.
    - Moving keeps the answer with its choice, and refuses to go past the
      end.
    - Gap fill keeps its sentence when choices change.
  - **Tiles**
    - The same letter twice is two tiles, both placeable, in click order.
    - A tile is used once; unknown ids are ignored.
    - A removed tile leaves the answer; removing a distractor leaves the
      answer alone.
    - New tiles get `w…` or `t…`, and editing keeps the answer.
    - Placed tiles move and come out by position; an empty answer is
      missing.
  - **Pairs**
    - Rows follow the stored pairs even when the right column is stored in
      another order.
    - Editing changes the row's own tile, and no column is reordered.
    - Adding and removing a row changes both columns and the pair.
  - **Placing errors**: 17 field paths, each mapped to its slot, including a
    match-pairs tile mapped to the row that holds it and a gap rule mapped
    to the sentence.
  - **Plain messages**: 7 real server messages.
  - **Audio**: local paths are resolved against the API base; hosted ones
    are left as they are.
- [x] `admin/src/exercises/editor.test.tsx` (32), the page as an admin uses
  it:
  - **The page**
    - The breadcrumb names the course and lesson, and links back with
      `?open=`.
    - The type is shown, and nothing offers another type.
    - "All changes saved", then "Unsaved changes", then "Saved".
    - After a save the server's copy is shown, not the typed one.
    - An exercise not in the lesson says so.
  - **Choices**
    - The answer is set by radio button, and the content is otherwise sent
      untouched.
    - Removing the correct choice disables Save until another is marked.
    - A new choice goes out as `e`.
    - Moving keeps the answer.
    - Gap-fill sentence edits are sent.
    - Listening plays `/media/…` from the backend, and address edits are
      sent.
  - **Tiles**
    - Spell `ሰ` + the second `ላ` + the first `ላ` + `ም`, sent as
      `t1, t4, t2, t3`, with the content untouched.
    - A distractor is shown and stays out of the answer.
    - Removing a placed word takes it out of the answer.
    - An empty answer disables Save.
  - **Pairs**
    - Editing a row keeps the stored right column's order.
    - Add and remove keep both columns and the pairs in step.
  - **Refused saves**
    - A row error appears inside that row, in plain words.
    - A list error appears right under the list.
    - An error with no field appears at the top.
    - Errors clear on the next edit.
  - **A new exercise**
    - The `POST` carries the chosen type and exactly what was typed, then
      the page shows the saved exercise.
    - Each type starts with its own fields.
    - An unknown type is refused.
  - **The preview**
    - The correct choice is highlighted, and follows the form live.
    - Listening audio plays from the backend.
    - The gap is filled with the answer.
    - The answer is shown in order, with distractors marked.
    - Pairs are numbered alike on both sides.
- [x] `admin/src/tree.test.tsx`: 6 new cases, and 1 rewritten.
  - A lesson offers exactly the six types, and each leads to its new
    exercise.
  - Moving sends the whole lesson's order and reloads, and the first and
    last buttons are disabled.
  - Delete asks first, Cancel sends nothing, and a confirmed delete sends no
    `confirm` query.
  - Edit opens the editor.
  - Preview shows the saved answer, and Close closes it.
  - `?open=lesson-1` reopens that lesson only.
  - "No child below a lesson" became "offers exercises, and nothing else".

### Falsification

Each breakage was applied, the whole suite run, and the source restored:

| Breakage | Tests failing |
|---|---|
| Removing the correct choice keeps it as the answer | 1 |
| A removed tile stays in the answer | 2 |
| Tiles told apart by text, not id | 2 |
| Pair text edited by position, not id | 2 |
| Ids ignore the list's convention | 6 |
| Server errors not placed by row | 2 |
| Messages left with their field path | 8 |
| Local audio not resolved against the API | 3 |
| An empty gap side dropped on load (a normalisation) | 10, most of them round-trip cases |
| Preview marks the first choice correct | 2 |
| Exercise move sends only two ids | 1 |
| Delete without asking | 1 |
| `?open=` ignored | 1 |
| A missing answer no longer blocks saving | 2 |

### Acceptance Criteria Validation

**Story 003, exercise editors**
- ✅ **Each type round-trips unchanged**: all 177 seeded exercises, through
  the real page
- ✅ **Marking a choice sets the answer key; no ids are typed**:
  `editor.test.tsx` and `model.test.ts`
- ✅ **Arranging tiles sets the sequence, and repeated characters stay
  distinct**: the `ሰ ላ ላ ም` cases
- ✅ **A `422` naming a field shows beside it**: row, list and top cases
- ✅ **The type is chosen once and cannot change**: the new-exercise
  `POST`, and the page offering no type control

**Story 005, preview**
- ✅ **Prompt, options or tiles render with the correct answer
  highlighted**: one preview case per type
- ✅ **A listening exercise's audio plays**: the player's source resolves to
  the backend. Actual playback happens in the browser and is not checked
  here.

### Issues Found

- **None in the code.** Two type errors were in the test file itself: its
  helper returned the exercise union and so could not read one type's
  fields. It is now loosely typed.

### Notes

- **Not proven by these tests: a real backend.** Every request goes to the
  fake server, and the `PUT`/`POST` shapes are checked against what the
  backend stores (the seed export) and its error format. Saving against the
  real local backend needs a sign-in, so that is for the user to try.
- **The fixture reflects the seed, not `dev.db`.** Exercises edited through
  the admin site later are not in it. To refresh it after a seed change,
  run `backend/scripts/export_exercise_fixtures.py`.
