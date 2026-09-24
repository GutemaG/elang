---
stage: implement
bolt: 038-admin-exercise-editors
created: '2026-09-24T08:27:30Z'
---

## Implementation Walkthrough: content-admin-web

### Summary

Lessons now have exercises an admin can add, edit, preview, reorder and
delete. Each of the six types has its own form, and none of them asks for
an id or any JSON. The editor page shows the form beside a live learner
preview. The load-bearing round trip was written first, and passes:
**every one of the 177 seeded exercises**, opened in the real page and
saved unchanged, reaches the server exactly as it was stored.

### Structure Overview

- **The draft is the stored shape.** `src/exercises/model.ts` holds the
  exercise as the server's own `{type, prompt, content, answer_key}` and
  never turns it into some other structure. Every change is a pure function
  that copies only what it touches, so ids, list order and keys survive
  anything the admin does not change.
- **The forms are thin views over those functions.** Choices serve three
  types; the sequence builder serves two; pairs serve one.
- **Errors are placed by path.** A `422`'s `details.field` becomes a
  **slot**, and each part of the form shows the error for its own slot.

### Completed Work

**Data**
- [x] `backend/scripts/export_exercise_fixtures.py`:
  - seeds a throwaway SQLite database in a temporary folder with the main
    seed, then writes `admin/src/test/data/seeded-exercises.json` (177
    exercises covering all six types)
  - never opens `dev.db` or reads `DATABASE_URL`; `dev.db`'s modification
    time was unchanged by the run
  - `ruff` is clean

**Types and routes**
- [x] `admin/src/types.ts` — `Tile`, `ExerciseType`, and `ExerciseBody`
  (one union member per type, mirroring `exercise_parts.py`), plus
  `AdminExercise` and `AdminExerciseList`.
- [x] `admin/src/tree/levels.ts` — the `exercises`, `exercise` and
  `exerciseOrder` routes.

**The model** (`admin/src/exercises/model.ts`)
- `TYPE_INFO`: the name, icon and description of each type.
- `bodyOf`: a deep copy of a stored exercise. `sameBody` compares two.
- `blank(type)`: a new exercise with the fewest tiles the server accepts.
- `nextId`: a new id in the list's own convention (`a`–`d` → `e`,
  `w4` → `w5`); never one already taken.
- **Choices**: add, edit text, remove (removing the correct one clears the
  answer), move, mark correct.
- **Tiles and sequences**: add, edit, remove (a removed tile also leaves the
  answer), append to the answer (each tile once; a repeated letter is still
  a separate tile), take out of the answer, move within it.
- **Pairs**: each row is one `correct_pairs` entry, in stored order. Adding
  or removing a row changes both columns together. Neither column is ever
  reordered.
- `missingAnswer`: the two things the form itself can check (a correct
  choice is marked; an answer exists). Everything else is left to the
  server.
- `placeError` and `plainMessage`: where a server error belongs, and its
  message without the path or class name ("Needs at least 2 choices").
- `playableUrl`: `/media/...` paths are resolved against the API base.

**The editor**
- [x] `fields.tsx` — the error context, `FieldError`, `Section`, `RowTools`,
  `AddRowButton` and `Hint`.
- [x] `ChoicesEditor.tsx` — radio buttons for "correct" (so no id is
  typed), row tools, and a highlighted correct row.
- [x] `SequenceEditor.tsx`:
  - the word bank or letter tiles, each marked "In answer" or "Distractor"
  - a **Correct answer** line built by clicking the tiles still to place,
    with earlier, later and take-out on each placed tile
- [x] `PairsEditor.tsx` — rows of *left ↔ right*.
- [x] `ExerciseForm.tsx` — the prompt, plus the audio address and player
  (listening) or the sentence around a visible gap (gap fill), then the
  type's editor.
- [x] `ExercisePreview.tsx` — a phone-framed approximation of the learner's
  screen:
  - the correct choice highlighted, and the gap filled with it
  - the answer tiles in order, with distractors dimmed
  - pairs coloured and numbered by match
  - a real `<audio>` player for listening exercises
- [x] `ExerciseEditorPage.tsx`:
  - addresses: `…/exercises/new/:type` and `…/exercises/:exerciseId`
  - loads the tree (for the breadcrumb) and the lesson's exercises
  - Save sends a `PUT`, or a `POST` that then moves to the new exercise;
    the page then shows the server's copy
  - shows "Unsaved changes", "Saved" or "All changes saved", and the
    browser warns before closing the tab with unsaved changes
  - `ExerciseEditorRoute` keys the page by what is being edited, so moving
    from new to edit starts it afresh
- [x] `AddExerciseMenu.tsx` — "Add exercise" on a lesson: the six types,
  each with a description.

**The tree**
- [x] `ExerciseList.tsx`:
  - on each exercise: Edit (the prompt is a link too), Preview (a dialog
    that reads the lesson's exercises in full), Move up and down (sends the
    whole order), and Delete (a confirm dialog)
  - the audio pills now include "audio ready" for hosted clips
- [x] `NodeRow.tsx` — two new props: `defaultExpanded`, and `extraAction`
  for levels with no child level.
- [x] `CourseTree.tsx` — lessons get Add exercise. `?open=<lessonId>`
  reopens that lesson, and its skill and section, on the way back from an
  exercise.
- [x] `ui/Modal.tsx` — a shared dialog: a bottom sheet on a phone, Escape or
  the backdrop to close.
- [x] `App.tsx` — the two editor routes.
- [x] `AppShell.tsx` — "Exercise editor" is removed from "Coming next".

### Key Decisions

- **Save stays enabled when nothing has changed.** Story 003 is literally
  "opened and saved unchanged". It is disabled only while a save is running
  or the answer is missing.
- **Errors clear on the next edit.** A kept error could point at a row that
  has since moved.
- **Preview renders the draft, not only the saved copy.** Once saved the
  two are the same, and a live preview catches mistakes before saving,
  which is story 005's purpose.
- **"Keeping the lesson open" is a query parameter, `?open=`.** Expansion
  was local state, lost on navigation.

### Deviations from Plan

- **The round-trip test was written during this stage.** The plan listed it
  under Stage 3 as "written first", and the bolt's notes say to write it
  first. It is already in place and passing (178 cases).
- **Two additions from looking at the screenshots:** the stale "Exercise
  editor — Soon" sidebar item was removed, and errors now read plainly
  (`plainMessage`).

### Dependencies Added

None.

### Developer Notes

- **Checks:** `tsc -b` and `eslint` are clean. `npm test` passes **228**:
  the 50 existing tests, with the "no child below a lesson" test rewritten
  as "offers exercises, and nothing else", plus 178 round-trip cases.
- **Build:** JS is 100.7 KB gzipped (was 87.6), CSS 7.4 KB. The 95 KB
  fixture is test-only and not bundled.
- **Screenshots:** the editor was checked through a temporary page over
  canned seed data (since deleted):
  - spell tiles, match pairs and listening at 1440 px
  - a sentence exercise at a true 390 px
  - the tree with the Add exercise menu open
  - a `422` placed under choice 2
- **Port 5173 was already in use** by another dev server during the
  screenshots (probably the user's). It serves the same folder, so it was
  used as is and not stopped.
