---
stage: plan
bolt: 033-spell-tiles-ui
created: '2026-09-26T06:35:14Z'
---

## Implementation Plan: spell-tiles-ui

### Objective

A learner can spell a word from character tiles, online and offline,
including a word with repeated characters.

- **Keying:** tiles are keyed by id from the API to the pack and back.
- **Grading:** local, by the spelled text.
- **The screen:** built only from the question kit (intent 018's goal
  for this bolt).
- **The other seven question types** behave exactly as before.

### What changed since this bolt was written (2026-09-20)

- **Grading compares the spelled text, not the id list.** Bolt 032's
  decision D3 says so, and the backend's `SpellTilesExerciseResponse`
  documents it. For example, `Maaloo` has two `a` tiles. A learner who
  taps the other `a` first spells the word exactly, but a straight id
  comparison would mark it wrong.
  - Story 001's technical note says `listEquals(answer,
    e.correctTileIds)`, which is wrong. D3 replaces it.
- **There are seven existing types now, not five.** Intent 019 added
  image choice and audio image choice.
- **The lesson screen is on the question kit** (intent 018). "Tray above,
  bank below, dim on use" is built from `AnswerSlotLine.sentence` and
  pill-shaped `AnswerTile`s. Intent 018's requirements say this bolt adds
  no decoration of its own, and the rules test now enforces that.
- **The seed already serves `spell_tiles`.** Today the app skips those
  exercises as unrenderable, so this bolt makes them playable. The seed
  has "Spell 'Hello'" (ሰላም) and "Spell 'Thank you'" (አመሰግናለሁ), plus a
  per-course spell exercise in every generated lesson.

### Reference designs (FR-11)

- **Layout:** the app's own `WordBankBuilder`, now on the kit: the built
  answer on ruled lines above a wrapping bank of pills, and a used pill
  dims in place.
  - It is read for its layout only and not extended. Units.md's "Note on
    Not Sharing the Word Bank" still stands.
- **Tiles and states:** Duolingo's word-bank chips, as fetched and
  recorded in bolt 044 (story 002 of unit 002):
  - **Idle, used and graded pills:** they come from the kit's tile colour
    language, with no new states.
- **Not borrowed:** Duolingo's per-character "tap to check" hints. The
  story rules out anything but tap, remove and Check.

### Decisions

- **D1: The model.**
  - **The exercise:** `SpellTilesExercise`, with an id, a `prompt`,
    `tiles` and `correctSequence` (tile ids, as served), is added to the
    sealed `Exercise`.
  - **The tiles:** a new sibling `SpellTile(id, text)`, not a reuse of
    `MatchPairsTile`.
    - The shapes match, but the rules differ. A spell tile's text is
      expected to repeat, while a match-pairs tile's is not.
    - The name and doc comment are where that rule lives, so borrowing
      `MatchPairsTile` would hide it.
- **D2: Grading follows 032's D3.** `isAnswerCorrect` maps the built ids
  and `correctSequence` to their texts and compares the two lists.
  - An id that is not one of the exercise's tiles is graded wrong.
  - Using every tile, distractors included, is allowed and graded wrong.
    There is no "too many" hint.
- **D3: The parse.** A new `spell_tiles` case in `_toExercise`, added to
  `known`.
  - It keeps each tile's id and text, and keeps `correct_sequence` as ids.
  - It does not copy the `sentence_construction` branch, which throws the
    ids away.
  - **This also fixes practice.** `getDueItems` parses through
    `_toExercise`, which throws on a type it doesn't know. A due item
    that was a spell exercise would today fail the whole practice
    session's load.
- **D4: The controller stays unchanged.**
  - `toggleWordBankToken` is a generic toggle over a `List<String>`.
    Tile ids are unique within an exercise, so toggling an id adds or
    removes exactly that tile, twin or not.
  - `check()` already grades through `isAnswerCorrect`.
  - The only edit is to its doc comment, to say it also takes a
    spell-tiles tile id. The name still fits, since a tile is a token in
    a bank.
  - **Checkpoint choice:** keep the name (recommended), or add a
    `toggleSpellTile` that forwards to it.
- **D5: The screen: a new `SpellTilesBuilder`** in
  `lib/features/lesson/widgets/spell_tiles_builder.dart`, built only from
  kit pieces.
  - **The tray:** `AnswerSlotLine.sentence`, holding a pill for each
    placed tile id in tap order. Tapping a pill removes that id, so the
    tile it came from comes back, not its twin.
  - **The bank:** a `Wrap` of pills. A pill is used, and cannot be
    tapped, when its own id is placed. Text is never compared.
  - **After Check:** the placed pills take the grade (correct or
    incorrect), and nothing can be tapped, as in the word bank.
  - **Layout:** pills hug their characters, so a wide Fidel character is
    never clipped. The `Wrap` and the ruled lines grow a row at a time,
    so nothing depends on a predicted height.
  - **The prompt:** a `QuestionPrompt` from the served prompt, through
    `splitPrompt`. The seeded "Spell 'Hello'" has no colon, so it shows
    whole, word included.
  - **The lesson screen:** new arms in the prompt and answers switches.
    Check shows for this type as it does for a sentence, enabled once one
    tile is placed.
- **D6: The offline pack.** Both halves of `lesson_pack_store.dart` get a
  `spell_tiles` entry.
  - **Stored shape:** `tiles` as `[{id, text}]`, plus `correctSequence`.
  - The comment on the read side's asymmetry is extended to name this
    type.
- **D7: The fake content.** `FakeLessonApi`'s coffee lesson gains a spell
  exercise with a repeated character, so every test run against the fake
  meets the real risk.
  - **The word:** "Spell 'Fruit'", ፍራፍሬ.
  - **Its tiles:** ፍ twice, ራ and ሬ, plus the distractors ቡ and ና.
  - **The grading check:** the fake's correct sequence uses one ፍ tile
    first, and a test spells it with the other one first.
- **D8: Tests.** The repeated-character tests come first, as the bolt
  asks.
  - **The model:** grading by text.
    - The twin-swapped order is right.
    - The wrong order is wrong.
    - An unknown id is wrong.
    - Distractors are wrong.
  - **The parse:** ids are kept for a repeated word.
  - **The builder and the screen:**
    - Tapping one twin dims only that one, and removing one twin frees
      that tile, not its twin.
    - Check stays disabled until a tile is placed, and disables again
      when the last one is removed.
    - Check makes no network call and goes through the normal grade,
      advance, Beans and XP flow.
    - The graded pills use the kit's colours.
  - **The pack:**
    - a repeated word round-trips with every id
    - it grades after the round trip
    - a pack holding all eight types round-trips
    - tile ids are scoped to their own exercise
  - **Offline, end to end:** download, play offline with zero network
    calls, and queue the completion for sync.
    - The pack store here round-trips every pack through the real JSON
      mappers, which the in-memory fake skips.
    - So this test proves the mapping, not just the object.
  - **Size:** the sweep test gains the spell scenes, plus a 12-tile Afaan
    Oromo word and a Fidel word at 2.0× text on a 320 px phone.
  - **Falsification (story 002's last criterion, done once and
    recorded):**
    1. Remove the read-side case.
    2. Watch it compile and fail at runtime.
    3. Restore it.
- **D9: Untouched.** None of these change:
  - `word_bank_builder.dart`, `SentenceConstructionExercise` and the
    `sentence_construction` parse path, which Test checks by diff
  - any backend file
  - `SyncEngine`, the pending-sync queue and the downloader

### Deliverables

- **`lib/shared/models/exercise.dart`:** `SpellTile`,
  `SpellTilesExercise`, and the grading arm.
- **`lib/shared/services/http_lesson_api.dart`:** the `spell_tiles` case.
- **`lib/shared/services/lesson_pack_store.dart`:** both halves.
- **`lib/shared/services/fake_lesson_api.dart`:** the ፍራፍሬ exercise.
- **`lib/features/lesson/widgets/spell_tiles_builder.dart`:** new.
- **`lib/features/lesson/screens/lesson_screen.dart`:** the prompt,
  answers and Check arms.
- **`lib/features/lesson/state/lesson_controller.dart`:** the doc comment
  only.
- **Tests:**
  - new: `test/features/lesson/spell_tiles_test.dart`
  - extended: `lesson_pack_json_test.dart`, `http_lesson_api_test.dart`,
    `screen_sweep_test.dart`
  - an offline end-to-end test
  - a JSON round-tripping pack-store helper

### Dependencies

- **Bolt 032:** the served contract.
- **Bolts 044 and 045:** the question kit and the lesson screen on it.
- No new packages. No backend change.

### Out of Scope

- Typing the spelling.
- Splitting a Fidel character into its consonant and vowel.
- Any change to grading flow, `sentence_construction` or sync.
- A gallery case: the builder is a feature widget made only of kit pieces
  that are already in the gallery.

### Acceptance Criteria

**Story 001: the spell-tiles exercise screen**

- [ ] The prompt shows the word, with an empty tray and the shuffled
      tiles below it.
- [ ] Tapping a tile adds its character to the tray and dims it.
- [ ] With twins, tapping one dims only that one, and removing one frees
      the tile that was tapped for it.
- [ ] Check is disabled with an empty tray and enables with one tile.
- [ ] Grading is local, by spelled text (032 D3), with no network call,
      and the controller's flow is unchanged.
- [ ] The graded state reuses the kit's tile colours.
- [ ] An 11-tile Afaan Oromo word and a Fidel word don't overflow at a
      large text scale.
- [ ] `word_bank_builder.dart`, `SentenceConstructionExercise` and the
      `sentence_construction` parse path are unchanged.

**Story 002: offline**

- [ ] A lesson with a spell exercise downloads, and the pack contains it.
- [ ] It plays offline with zero network calls.
- [ ] A repeated word round-trips with every tile's own id and still
      grades.
- [ ] The completion queues offline and syncs through the existing
      `SyncEngine`.
- [ ] With the read case removed, it compiles and fails only at runtime.
      The observed message is recorded.

**Bolt**

- [ ] Full suite green, `flutter analyze` clean, and no backend file
      touched.
