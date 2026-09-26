---
stage: test
bolt: 033-spell-tiles-ui
created: '2026-09-26T06:59:41Z'
---

## Test Report: spell-tiles-ui

### Summary

- **Tests:** all 1,359 Flutter tests pass. 35 are new in this bolt.
  - **The e2e flake:** the end-to-end sign-in test ("a garbage Google ID
    token…") failed once in one full run, as in bolts 047 and 049. It
    passed alone and in the next full run.
- **Checks:**
  - `flutter analyze`: no issues.
  - `dart format`: nothing to change in any touched file.
- **Coverage:** not measured.
- **Mutation check:** 23 deliberate breakages of the new code, each run
  against:
  - the spell tests
  - the pack round-trip tests
  - the API tests
  - the lesson kit tests
  - the rules test

  **Results:**
  - **First run:** 22 caught.
  - **After one new check:** 23 caught.
  - **Restored after each run:** every file was checked, and the run was
    left to finish.
- **What the breakages cover:** most of them bring back the bug this
  bolt exists to prevent, by keying tiles by text somewhere along the
  path:
  - grading by ids instead of by spelled text
  - the parser collapsing twin tiles into one, or using the text as the
    id
  - the pack writer collapsing twins, or the reader using the text as
    the id
  - the bank dimming, or refusing, every tile that shares the tapped
    tile's text
  - removing a placed twin freeing the first matching tile instead of
    its own

  The rest break the grade colours, locking after Check, the hint, the
  labels, the Check wiring, the answer wiring and the prompt. All are
  caught.

### Test Files

- [x] **`test/features/lesson/spell_tiles_test.dart`** (23, new)
  - **Grading by text:**
    - the served order is right
    - the twins swapped are right
    - the wrong order is wrong
    - an extra distractor, a missing character or an empty answer is
      wrong
    - an unknown id is wrong
    - an answer of another shape is wrong
    - `spelled()` maps ids to characters
  - **The API:**
    - `Maaloo`, with two `a` and two `o` tiles, parses with every id, is
      no longer skipped, and grades either twin order
    - a practice item that is a spell exercise loads
  - **The fake:** its spell word repeats a character.
  - **The screen:**
    - the layout, from kit pieces
    - one twin dims alone
    - removing a twin frees its own tile
    - Check is disabled while empty, enabled with one tile, and disabled
      again when it is removed
    - twins swapped grade right on the device with no API call; the line
      and the placed pills take the correct colours and lock; the lesson
      finishes with 2 of 2
    - a wrong spelling takes the incorrect colours, costs a bean, comes
      back for review, and is retried from an empty tray
    - every tile placed is graded wrong, with no hint
  - **Large text:**
    - 12 Afaan Oromo tiles and 12 Fidel tiles, each at 320 and 360 px at
      2.0× text, empty and fully placed
    - a wide Fidel pill is not clipped
  - **Offline:**
    - download into a JSON-backed pack store, with the twins' ids intact
    - play offline with no API call
    - the completion is queued, then sent when the device is back online
- [x] **`test/shared/services/lesson_pack_json_test.dart`** (4 new, and
  the fixture updated)
  - The every-type fixture now holds eight types.
  - A repeated word keeps every id and its order.
  - It grades after the round trip, twins either way.
  - Its stored shape.
  - Ids are scoped per exercise.
- [x] **`lesson_screen_kit_test.dart`:** the one-frame and small-screen
  checks run all eight types.
- [x] **`screen_sweep_test.dart`:** a 12-tile spell scene with a twin,
  before and after answering (8 tests).
- [x] **`fake_lesson_api_pictures_test.dart`:** the fake lesson's type
  list includes the spell exercise.

### Acceptance Criteria Validation

**Story 001: the spell-tiles exercise screen**

- ✅ **The layout:** the prompt shows the word, with an empty tray and the
  shuffled tiles below it.
- ✅ **Tapping a tile** adds its character to the tray and dims it.
- ✅ **Twins:** tapping one dims only that one, and the other stays
  tappable.
- ✅ **Removing a twin** frees the tile that was tapped for it, not its
  twin.
- ✅ **Check** is disabled with an empty tray and enables with one tile.
- ✅ **Grading is local:**
  - no network call on Check
  - `LessonController`'s grade, advance, Beans and XP flow is unchanged
    (only a doc comment changed)
  - grading compares the spelled text, per bolt 032's D3, which replaces
    this story's older id-list note
- ✅ **The graded state** reuses the kit's tile colours, on the line and
  on the pills.
- ✅ **No overflow** for an 11-character Afaan Oromo word (12 tiles) or a
  Fidel word at 2.0× text on 320 and 360 px.
- ✅ **Unchanged in the diff:** `word_bank_builder.dart`,
  `SentenceConstructionExercise` and the `sentence_construction` parse
  path.

**Story 002: offline**

- ✅ **The download** succeeds, and the pack contains the exercise.
- ✅ **Offline,** it renders and grades with zero network calls.
- ✅ **A repeated word** round-trips with every tile's own id, and still
  grades.
- ✅ **The completion** queues offline and syncs on reconnect through the
  existing `SyncEngine`.
- ✅ **Falsification:** with the read case removed, it compiles
  (`flutter analyze lib` clean) and fails only at runtime. Five tests
  failed with `Bad state: Unknown exercise type in cached pack:
  spell_tiles`, including the offline end-to-end test. The case was
  restored and checked byte for byte.

**Bolt**

- ✅ **Checks:** full suite green, `flutter analyze` clean, and no backend
  file touched.

### Issues Found

- **The line's own grade colour was not checked** (mutation #19).
  Dropping `grade:` from the tray left only the pills coloured. Both
  screen tests now check the line's grade too.
- **No bugs found in the app code.**

### Notes

- **Not checked on a device.** The spell screen was not tried on a real
  phone. It can join the device checklist in bolt 049's test report:
  - a lesson with "Spell 'Hello'" or "Spell 'Thank you'"
  - an Afaan Oromo spell word with twins
