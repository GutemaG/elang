---
stage: plan
bolt: 055-admin-tree-polish
created: '2026-09-28T19:41:33Z'
---

## Implementation Plan: admin-tree-polish

### Objective

Three fixes reported on 2026-09-28:

- **A.** The picture description ("Describe the picture for learners who
  can't see it") stops being required.
- **B.** Reordering is by drag and drop, at every level, and nothing is
  saved until Save is clicked.
- **C.** The course page looks the same whether you come back by the
  browser's Back button, the course link in the breadcrumb, or "Back to
  lesson".

### What the code says (checked before planning)

- **F1: The description is required in three places.**
  - Admin: `pictureProblems` in `admin/src/exercises/model.ts` blocks
    saving without it.
  - Backend: `_check_pictures` in `backend/app/domain/lesson/exercise_parts.py`
    refuses an empty `alt_text` with a `422`, and `PictureChoice` in
    `value_objects.py` refuses it too.
  - Flutter: `PictureTile` uses the text as the screen-reader label and
    shows it when a picture fails to load. An empty string would give an
    unlabelled tile, so the app needs a fallback.
- **F2: Reordering today.**
  - Each row has up and down arrows. Each click saves at once (a `PUT` of
    the whole id list to the level's `/order` endpoint), then reloads the
    tree.
  - The backend reorders children within one parent only. Moving a lesson
    to another skill is not possible, and this bolt does not add it.
  - The admin site has no drag-and-drop library.
- **F3: Why the tree collapses.**
  - Each row keeps "open or closed" in its own React state, so leaving the
    page throws it away.
  - "Back to lesson" only looks right because its link adds
    `?open=<lessonId>`, which opens that lesson and its parents.
  - The browser's Back button and the breadcrumb's course link go to plain
    `/courses/:id`, so everything starts closed.
  - None of the three restores the scroll position: the tree loads after
    the page appears, so the browser has nothing to scroll to yet.

### Decisions

- **D1: The description is optional everywhere.**
  - Admin: it no longer blocks saving. The field is labelled "Description
    (optional)" and the hint stays: "Read aloud to learners who can't see
    it."
  - Backend: an empty or blank `alt_text` saves (stored as `""`). It must
    still be a string of at most 200 characters.
  - Flutter: an empty description falls back to "Picture 1", "Picture 2",
    and so on, for the screen-reader label and for a picture that fails
    to load.
  - No database change, so nothing for Neon. Older app versions already
    read `alt_text` as a string, so `""` doesn't break them.
- **D2: Drag with @dnd-kit.**
  - `@dnd-kit/core` and `@dnd-kit/sortable`. They are headless (no styles
    of their own) and handle mouse, touch and keyboard.
  - Native HTML drag and drop was rejected: it doesn't work on touch
    screens and has no keyboard support.
- **D3: How dragging works.**
  - Each row gets a grip handle at its start. You drag by the handle, so
    clicking a title still opens and closes it.
  - Rows move only within their own list (a section's skills, a skill's
    lessons, and so on), as the backend allows.
  - Numbers (1.2, 1.2.3, exercise 4) update as you drag.
  - Keyboard: focus the handle, Space picks up, arrow keys move, Space
    drops, Escape cancels. Each step is announced to screen readers.
- **D4: One Save for all order changes.**
  - A drag only changes the page. A bar sticks to the bottom of the
    window: "New order not saved (2 lists)", with Discard and Save order.
  - Save sends one `PUT` per changed list, using the existing endpoints,
    then reloads. A failure shows in the banner and reloads, as other
    writes do.
  - While an order is unsaved, the other edits (add, rename, delete) are
    disabled, titled "Save or discard the new order first". This stops a
    reload from wiping out the unsaved order.
  - Closing or reloading the tab with an unsaved order asks first, as the
    exercise editor does.
- **D5: The up and down arrows go.** The handle does their job, from the
  keyboard too, and it saves space on a phone. If you'd rather keep them,
  they would move rows without saving, like a drag.
- **D6: The page remembers what was open, and where you were.**
  - What's open is saved per course in `sessionStorage`
    (`buna_admin.tree_open.<courseId>`) on every open and close.
  - The scroll position is saved when you leave the page, and restored
    once the tree has loaded.
  - `?open=<lessonId>` still opens that lesson, on top of what was
    remembered.
  - It's `sessionStorage`, like the sign-in, so it lasts for the tab and
    is forgotten when the tab closes.
  - Result: Back, the breadcrumb and "Back to lesson" all show the tree
    as you left it.

### Files

- **Admin site**
  - `package.json` and the lock file: add `@dnd-kit/core`,
    `@dnd-kit/sortable` and `@dnd-kit/utilities`.
  - `src/exercises/model.ts`: remove the description check.
  - `src/exercises/PictureChoicesEditor.tsx`: the "(optional)" wording.
  - New `src/tree/treeMemory.ts`: reads and writes the open rows and the
    scroll position.
  - New `src/tree/Sortable.tsx`: the sortable list, row and grip handle,
    shared by all four levels.
  - `src/tree/CourseTree.tsx`: holds the unsaved orders and the open rows,
    the Save bar, and the scroll restore.
  - `src/tree/NodeRow.tsx`: the handle instead of arrows; open state comes
    from the tree.
  - `src/tree/ExerciseList.tsx`: the handle instead of arrows.
  - `src/tree/TreeActions.ts`: the new context fields.
  - `src/tree/levels.ts`: `moved()` is no longer needed.
- **Backend**
  - `app/domain/lesson/exercise_parts.py` and
    `app/domain/lesson/value_objects.py`: allow an empty description.
  - Tests: `tests/unit/test_picture_exercises.py` and
    `tests/integration/test_picture_exercises_api.py`.
- **Flutter**
  - `lib/features/lesson/screens/lesson_screen.dart`: the "Picture N"
    fallback, localised if the screen's other text is.
  - A widget test for the fallback.
- **Docs**
  - `database-schema.md`: `alt_text` is optional.
  - The unit 002 brief: drag and drop is now in scope.

### Acceptance criteria

- **A. Optional description**
  - [ ] A picture question with no descriptions can be created and saved
    in the admin site.
  - [ ] The API saves an empty or blank `alt_text`, and still refuses one
    over 200 characters.
  - [ ] In the app, a picture with no description is announced as
    "Picture N", and shows that if it fails to load.
- **B. Drag to reorder**
  - [ ] Sections, skills, lessons and exercises can be dragged by their
    handle, with the mouse, touch or keyboard, within their own list.
  - [ ] Nothing is sent while dragging. The Save bar shows how many lists
    changed.
  - [ ] Save sends one `PUT` per changed list, with the new id order, then
    shows the saved order.
  - [ ] Discard puts every list back as it was.
  - [ ] While an order is unsaved, add, rename and delete are disabled.
  - [ ] A failed save shows the error and reloads the tree.
- **C. Coming back to the course**
  - [ ] Rows opened before leaving are still open after the browser's
    Back button, the breadcrumb's course link, and "Back to lesson".
  - [ ] The page scrolls back to where it was.
  - [ ] `?open=<lessonId>` still opens that lesson and its parents.
  - [ ] Another course's open rows are not affected.

### Tests

- **Admin (Vitest)**
  - `model.test.ts` and `pictures.test.tsx`: a question with no
    description saves.
  - New `tree/reorder.test.tsx`: drag by keyboard (dnd-kit's keyboard
    sensor works in jsdom; pointer dragging doesn't), the Save bar, the
    `PUT` bodies, Discard, disabled edits, and a failed save.
  - New `tree/treeMemory.test.ts`, plus cases in `tree.test.tsx`: open
    rows survive leaving and coming back by each route, and scroll is
    restored.
  - Existing tests that click "Move up" or "Move down" are rewritten to
    drag.
- **Backend (pytest)**: empty and blank descriptions save; over 200 is
  refused.
- **Flutter**: the "Picture N" fallback.
- **By hand (you)**: drag with a mouse and on a phone or touch screen, and
  use the Back button on a long course.

### Risks

- **Drag on touch:** a handle that's too small is hard to grab. It will be
  44 px on a phone, like the other row buttons.
- **Dragging an open section:** its whole card moves, and it can be tall.
  During a drag the page scrolls itself near the window's edges (dnd-kit
  does this).

---

## Implementation Notes (Stage 2)

Plan approved 2026-09-28, with D5 as written: the up and down arrows are
gone.

### A. Optional description

- **Admin:** `pictureProblems` checks only for a picture. The hint reads
  "Optional. Read aloud to learners who can't see it; without one they hear
  "Picture n"." The learner preview names a picture with no description
  "Picture n", as the app does; an empty slot still says "No picture".
- **Backend:** `_check_pictures` still needs `alt_text` to be a string of
  at most 200 characters, but it may be empty or blank. `PictureChoice` no
  longer refuses an empty one. A blank one is stored as sent (not trimmed
  to `""`); the app treats blank as empty. This differs from D1's "stored
  as `""`" and changes nothing a learner sees.
- **Flutter:** `PictureChoice.labelAt(index)` gives the description, or
  "Picture n". The lesson screen passes it to `PictureTile`, so it is the
  screen-reader label and the text shown if the picture fails to load. The
  app has no localisation, so it is English like the rest of the screen.

### B. Drag to reorder

- **New `tree/Sortable.tsx`:** `SortableList` (one `DndContext` per list,
  so a row only lands among its siblings), `SortableItem` (the `<li>` that
  moves) and `DragHandle`.
  - Pointer (mouse, pen, touch) through dnd-kit's `PointerSensor`, after
    4 px of travel so a click stays a click. Rows move only vertically.
  - **Keyboard, a change from D3:** the up and down arrows on a focused
    handle move the row one place at once, and focus stays on it. This
    replaces dnd-kit's Space-to-pick-up keyboard sensor: it is one key per
    move instead of three, needs no layout, and matches the old arrow
    buttons. Each move is announced ("section Basics moved to position 2
    of 2. Not saved yet."). dnd-kit's own announcements cover pointer drags.
  - Numbers update when a row is dropped, not while it is in the air.
- **`CourseTree.tsx`:**
  - `drafts`, keyed by the id of what holds each list, with its kind; lists
    are drawn from a draft when it names exactly their items (`inOrder`).
  - The sticky "Unsaved order" bar: "New order not saved (n lists)",
    Discard, Save order. Save sends one `PUT` per list through `run()`,
    then clears the drafts; a failure shows in the banner over the
    reloaded tree.
  - While a draft exists: Rename course, Add section, and every row's Add,
    Rename and Delete are disabled, titled "Save or discard the new order
    first". An exercise's Edit link and prompt link are too, since leaving
    the page would lose the order. Handles and Preview stay on.
  - `beforeunload` asks while a draft exists.
- **`NodeRow.tsx` / `ExerciseList.tsx`:** a handle first in each row; the
  arrows removed. `ExerciseRow` is split out. The exercise list lost
  `overflow-hidden` (it would clip a dragged row); its rows have their own
  background and rounded ends instead.
- **`levels.ts`:** `moved()` removed; `OrderKind` and `orderRoute()` added.
- **Dependencies:** `@dnd-kit/core` 6.3.1, `@dnd-kit/sortable` 10.0.0,
  `@dnd-kit/utilities` 3.2.2. The built bundle is 416 kB (126 kB gzip).

### C. Coming back to the course

- **New `tree/treeMemory.ts`:** open rows per course
  (`buna_admin.tree_open.<courseId>`) and scroll position
  (`buna_admin.tree_scroll.<courseId>`) in `sessionStorage`, every read and
  write in `try`/`catch`. `pathTo()` finds a lesson's section and skill.
- **`CourseTree.tsx`:**
  - Open rows live in the page, not in each row, and are written on every
    change. `?open=` adds the lesson's path on arrival.
  - The scroll position is written in a layout-effect cleanup, as the page
    is left and before the next page can change it, and restored once the
    tree is first drawn. With `?open=`, the lesson is also scrolled into
    view if it is off screen.
  - `CourseTree` now renders `CoursePage` keyed by course, so another
    course starts from its own memory.
- **Known limit:** going Back *from* the course page (to the course list)
  lets the browser restore the list's scroll before the course page is
  unmounted, so the position saved then can be the list's. Leaving by a
  link, the usual way to an exercise, saves the right one.

### Hooks lint

The React compiler's `react-hooks/refs` rule took an object holding
dnd-kit's `setNodeRef` for a ref and refused its other fields during
render. `SortableItem` owns the `<li>` and hands the handle its parts
through context, which the rule accepts.

### Docs

- `database-schema.md`: `alt_text` is optional.
- Unit 002 brief: drag-and-drop is in scope; moving a row to another parent
  is out.

## Checks (Stage 2)

- **Admin:** `eslint .` clean, `npm run build` clean, `vitest run` 534
  passed (18 files).
- **Backend:** picture tests 136 passed; `ruff check` and
  `ruff format --check` clean. Full suite 1282 passed (1280 before, plus
  the two new API cases).
- **Flutter:** `flutter analyze` on the touched files clean; lesson, shared
  and design tests 1224 passed. The 7 failures are all in
  `http_auth_api_e2e_test.dart`, which needs a live backend running and
  does not touch this change.

---

## Test Report (Stage 3)

Implement approved 2026-09-28.

### Runs

| Suite | Result |
|---|---|
| Admin `vitest run` | 534 passed, 18 files (re-run 2026-09-28T20:11Z) |
| Admin `eslint .`, `npm run build` | clean |
| Backend `pytest` (full) | 1282 passed |
| Backend `ruff check`, `ruff format --check` | clean |
| Flutter lesson, shared and design tests | 1224 passed; 7 failed, all in `http_auth_api_e2e_test.dart` (needs a live backend, unrelated) |
| `flutter analyze` (touched files) | clean |

### Acceptance criteria

- **A. Optional description**
  - [x] A picture question with no descriptions saves in the admin site
    (`pictures.test.tsx`: "a description is optional…"; `model.test.ts`).
  - [x] The API saves an empty or blank `alt_text` and refuses one over
    200 characters (`test_picture_exercises.py`,
    `test_picture_exercises_api.py`).
  - [x] The app names a picture without one "Picture N", for the label and
    the failed-load text (`lesson_screen_pictures_test.dart`).
- **B. Drag to reorder**
  - [x] Every level is dragged by its handle, within its own list:
    pointer drags in `sortable.test.tsx`, keyboard in `tree.test.tsx`.
    Touch goes through the same pointer events; check it by hand.
  - [x] Nothing is sent while moving; the bar counts the lists.
  - [x] Save sends one `PUT` per list with every id, then shows the saved
    tree.
  - [x] Discard puts every list back.
  - [x] Add, rename, delete and Edit wait while an order is unsaved.
  - [x] A refused save shows why and reloads the tree.
- **C. Coming back**
  - [x] Open rows survive the breadcrumb, "Back to lesson", and a return to
    the plain course address (what the browser's Back button lands on).
  - [x] The scroll position is restored.
  - [x] `?open=` still opens the lesson and its parents.
  - [x] Open rows are kept per course (`treeMemory.test.ts`).

### Left for a person

- Drag with a mouse and on a touch screen in a real browser.
- The browser's real Back button on a long course.
- The known limit in Implementation Notes C (leaving the course page by
  Back can save the list's scroll).
