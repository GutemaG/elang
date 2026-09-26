---
stage: implement
bolt: 033-spell-tiles-ui
created: '2026-09-26T06:48:16Z'
---

## Implementation Walkthrough: spell-tiles-ui

### Summary

- **Spell exercises now play** online, offline and in practice. They were
  already seeded ("Spell 'Hello'", "Spell 'Thank you'", and one per
  generated lesson), and until now the app skipped them.
- **Tiles are keyed by id from the API to the screen to the pack and
  back,** so tapping or removing one twin never touches the other.
- **Grading is local, by the spelled text** (bolt 032, D3). Twins tapped
  in either order spell the word, and are marked right.
- **The screen is built only from the question kit,** so the rules test
  passes with no allow-list.
- **The controller has no code change,** only one doc comment.
- **Checks:** `flutter analyze` reports no issues, and all 1359 tests
  pass (35 new).

### Structure Overview

A spell exercise follows the same path as the other types, and is keyed
by tile id at every step:

1. **The API:** `_toExercise` parses `SpellTilesExercise`, keeping each
   `SpellTile(id, text)`.
2. **The controller:** it holds the tapped ids, in order, as the answer.
   Its existing `toggleWordBankToken` adds or removes an id, and `check()`
   grades through `isAnswerCorrect`.
3. **The screen:** `SpellTilesBuilder` draws the placed ids on the ruled
   line and the tiles in a wrap. It looks up text by id only to label a
   pill.
4. **The pack:** it stores `tiles` as `{id, text}` pairs plus
   `correctSequence`, and reads them back as they were.

### Completed Work

- [x] **`lib/shared/models/exercise.dart`:**
  - **`SpellTile(id, text)`:** a sibling of `MatchPairsTile`, not a reuse
    of it. Its doc comment carries the rule that makes it different: text
    repeats, and a tile is identified only by id.
  - **`SpellTilesExercise`:** a `prompt`, `tiles` and `correctSequence`,
    documented as "*a* correct order, not the only one". `spelled(ids)`
    maps ids to characters in order, or returns `null` for an id that is
    not one of its tiles.
  - **The grading arm in `isAnswerCorrect`:** the answer must be a
    `List<String>` of ids. Its spelled characters must equal those of
    `correctSequence`. An unknown id is graded wrong.
- [x] **`lib/shared/services/http_lesson_api.dart`:**
  - `spell_tiles` joins `known`.
  - **A new case** builds the tiles from id and text and keeps
    `correct_sequence` as ids. A comment says why it is not the
    `sentence_construction` branch.
  - **This also fixes practice.** `getDueItems` parses through the same
    `_toExercise`, which threw on this type, so one spell item would have
    failed the whole practice load.
- [x] **`lib/shared/services/lesson_pack_store.dart`:**
  - **Write and read cases:** both are new, and the comment about the
    read side not being compiler-checked now names this type too.
  - **`packLocalFiles`:** the new type is listed with those that own no
    files.
  - **Formatting:** `dart format` re-wrapped a few long match-pairs lines
    in this touched file, with no change in behaviour.
- [x] **`lib/shared/services/fake_lesson_api.dart`:** the coffee lesson
  gains "Spell 'Fruit'" (ፍራፍሬ).
  - **Tiles:** two ፍ tiles, `f2` shown first and `f1` served first, plus
    ራ, ሬ and the distractors ቡ and ና.
  - **Placement:** before the two picture questions, so the lesson still
    ends with them.
- [x] **`lib/features/lesson/widgets/spell_tiles_builder.dart` (new):**
  - **The tray:** an `AnswerSlotLine.sentence` with one line, holding a
    pill per placed id with the key `placed-<id>`. Its hint reads "Tap the
    characters below to spell it".
  - **The bank:** a `Wrap` of pills with the key `bank-<id>`. A tile is
    `used`, and cannot be tapped, when its own id is placed.
  - **After Check:** the placed pills take `correct` or `incorrect`, and
    nothing can be tapped.
  - **Built only from kit pieces,** with no decoration of its own.
  - **Not built on `WordBankBuilder`,** as the doc comment says, citing
    the intent's note.
- [x] **`lib/features/lesson/screens/lesson_screen.dart`:**
  - **The prompt arm:** `QuestionPrompt` from `splitPrompt`. "Spell
    'Hello'" has no colon, so it shows whole, word included.
  - **The answers arm:** `SpellTilesBuilder`, wired to the unchanged
    `toggleWordBankToken`.
  - **Check:** it now covers "built" types, a sentence or a spelling. It
    is enabled once one tile is placed.
- [x] **`lib/features/lesson/state/lesson_controller.dart`:** only
  `toggleWordBankToken`'s doc comment changes, to say it also takes a
  spell-tiles tile id and why twins toggle independently. Its code and
  every other controller line are unchanged, as story 001's technical
  note hoped.
- [x] **`test/helpers/json_round_trip_pack_store.dart` (new):** a
  `FakeLessonPackStore` that keeps each pack as encoded JSON text, as the
  sqflite store does. With it, an offline test really goes through the
  pack's JSON mapping. The in-memory fake keeps the object itself and
  skips that mapping.
- [x] **`test/features/lesson/spell_tiles_test.dart` (new, 23 tests):**
  - **Grading** (7 tests):
    - the served order is right
    - twins swapped are right
    - the wrong order is wrong
    - an extra distractor, a missing character or nothing at all is
      wrong
    - an unknown id is wrong, not a crash
    - an answer of another shape is wrong
    - `spelled()` maps ids to characters
  - **The API** (2 tests):
    - a served `Maaloo` parses with every twin's id, is no longer counted
      as unrenderable, and grades twins either way
    - a practice item that is a spell exercise loads
  - **The fake** (1 test): its spell word repeats a character.
  - **The screen** (7 tests):
    - the prompt, an empty tray and the tiles in served order, all kit
      pills; the tray sits between prompt and bank
    - tapping one ፍ dims only that one, and the other can still be placed
    - removing the second ፍ frees `f2`, not `f1`, and the line keeps its
      order
    - Check is disabled while empty, enabled with one tile, and disabled
      again when it is removed
    - twins swapped: graded right on the device, nothing sent to the API,
      correct colours, everything locked, and the lesson finishes with 2
      of 2
    - a wrong spelling: incorrect colours, a bean spent, the review
      screen, and a retry that starts empty and finishes the lesson
    - every tile placed, distractors included: Check grades it wrong,
      with no hint
  - **Large text** (5 tests):
    - 12-tile Afaan Oromo and Fidel words, each at 320 and 360 px at 2.0×
      text, empty and fully placed, with Check still reachable
    - a wide Fidel pill is at least as wide as a Latin one, and neither is
      clipped
  - **Offline** (1 test):
    - a spell lesson downloads into the JSON store, and the twins come
      back with their own ids
    - it plays offline with no API call, twin order swapped
    - the completion is queued, then sent once the device is back online
- [x] **`test/shared/services/lesson_pack_json_test.dart`:**
  - **The fixture** now includes a `Maaloo` spell exercise, and the "every
    type" checks name the new type.
  - **A new `spell tiles` group** (4 tests):
    - every tile keeps its own id and order
    - it grades after the round trip, twins either way
    - its stored shape
    - two spellings in one pack that reuse the same tile ids both
      round-trip and grade, so ids are scoped per exercise
- [x] **Changed for the new type:**
  - **`lesson_screen_kit_test.dart`:** the "one frame for every question
    type" and small-screen checks now run all eight types, and its answer
    helper spells by id.
  - **`screen_sweep_test.dart`:** a 12-tile spell scene with a twin,
    before and after answering, at both sizes and scales (8 tests).
  - **`fake_lesson_api_pictures_test.dart`:** the fake coffee lesson's
    type list includes the spell exercise, which this bolt added there on
    purpose.
  - **`http_lesson_api_test.dart`:** a comment that said client support
    was "still pending in bolt 033" is reworded.

### Key Decisions

- **`SpellTile` is its own class, not `MatchPairsTile` (D1).** The shapes
  match, but the rules differ, and the name is where the rule lives.
- **Grading by text (D2),** following bolt 032's D3 rather than story
  001's older `listEquals` on ids. The twin-swapped test exists to catch
  a regression to id grading.
- **No controller change (D4).** The toggle was already correct for
  unique ids. Only the doc comment now says it takes tile ids.
- **The offline test uses a JSON store.** With the in-memory fake, the
  offline test would pass even with the pack's read case missing. The
  falsification below shows that, with the JSON store, the offline test
  also catches it.

### Falsification (story 002, last criterion)

This was done once and is recorded here; it is not a shipped test.

1. **Removed** the `case 'spell_tiles':` from `packExerciseFromJson`.
2. **It still compiled:** `flutter analyze lib` found no issues. The
   write side's sealed switch is checked by the compiler; the read side's
   string switch is not.
3. **Five tests failed at runtime** with `Bad state: Unknown exercise
   type in cached pack: spell_tiles`:
   - the offline end-to-end test
   - the every-type round trip
   - the three spell round-trip tests
4. **Restored** the case and checked the file byte for byte.

### Deviations from Plan

- **The fake's spell exercise sits before the picture questions,** not at
  the end, so the fake lesson still ends with them. Its id stays
  `coffee-8`, and the existing ids are unchanged.
- **One more test file changed** than the plan listed:
  `fake_lesson_api_pictures_test.dart` pins the fake lesson's type list.

### Dependencies Added

- None. No backend file, `word_bank_builder.dart`,
  `SentenceConstructionExercise`, sentence parse path, `SyncEngine`, queue
  or downloader changed. `git diff` confirms it.

### Developer Notes

- **Screen readers:** twin pills have the same label ("ፍ"), so a screen
  reader reads them alike. That is expected, since either one is right.
- **Seeded content:** the two hand-seeded Amharic spell words (ሰላም,
  አመሰግናለሁ) have no repeated character. Afaan Oromo words such as
  `Maaloo` do, and so may the generated per-course spell exercises. The
  fake, the tests and the sweep cover twins regardless.
