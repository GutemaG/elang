---
stage: plan
bolt: 053-picture-tile-and-lesson
created: '2026-09-25T15:04:32Z'
---

## Implementation Plan: image-choice-ui (picture tile, lessons and practice)

### Objective

Add a picture answer tile and its grid to the question kit. Then play both
picture question types in lessons, and so in practice, in the same frame
as the other five types. Both types are parsed from the API, graded like
multiple choice, and kept intact by the lesson cache.

### Reference designs (FR-11 of intent 018)

- **`highland_pulse/DESIGN.md`, component 4, is the primary reference.**
  Every face, border, rim, radius and colour comes from it through
  `AnswerTile`. Nothing new is drawn.
- **Duolingo, "Select the correct image"**
  ([Revyl Atlas screen map](https://revyl.com/atlas/duolingo/)). This is
  one of Duolingo's core templates, and the first in a lesson's sequence.
  - **Borrowed:**
    - The prompt names the word, and below it is a grid of square picture
      cards, two across on a phone.
    - One card is chosen.
    - The cards are the same raised, bordered tiles as its text answers.
  - **Not borrowed:**
    - Duolingo prints the word under each picture. Buna shows the picture
      alone (answer 2a), so the question tests meaning.
    - Duolingo has a separate Check button. Buna grades on the tap, like
      its other choice questions.
    - Duolingo's blue selected colour. Buna's selected colour stays gold.
- **LibreLingo's picture "cards" challenge**
  ([`DeckChallenge`, `OptionDeck.svelte` and `OptionCard.svelte`](https://github.com/kantord/LibreLingo/tree/lluis-v1.8.1/apps/web/src/components)),
  from its source code.
  - **Borrowed:**
    - A 1:1 picture area inset 8 px inside a card.
    - Two columns on a phone.
    - The question "Which of these is ‘…’?" above the cards.
    - Unchosen cards fade once one is picked; in Buna that is the kit's
      existing faded state after grading.
  - **Not borrowed:**
    - `object-fit: cover`, which crops. Buna letterboxes instead (story
      001: never cropped).
    - The scale-up on the active card. Buna uses the kit's shelf press.

### Decisions

- **D1: The picture tile is `AnswerTile` with a new shape.** This is how it
  shares the states without copying them.
  - `AnswerTileShape.picture` and an optional `picture` widget are added to
    `AnswerTile`.
  - With that shape, the tile draws the picture in a square face, inset
    8 px, instead of the label. So it keeps every existing behaviour:
    - the six states, their colours and their eased change
    - the press and the shelf
    - the shake, which is skipped with reduced motion
    - the semantics: button, enabled and selected
  - The label becomes the alt text and is what a screen reader reads.
  - A graded tile shows its check or cross in the top corner, as a row
    shows it at the end.
  - The picture's fallback text takes the tile's text colour, through
    `DefaultTextStyle`.
- **D2: `PictureTile`, in `picture_tile.dart`,** is the thin, public
  wrapper for the picture shape. It takes:
  - an `ImageProvider` rather than a URL, so tests pass in-memory pictures
    and bolt 054 can pass downloaded files
  - the alt text
  - the state
  - `onTap`

  It shows the picture in three ways:
  - **Fitted:** `BoxFit.contain`, so a picture is letterboxed and never
    cropped.
  - **Decoded at tile size:** `ResizeImage`, sized to the tile's width in
    device pixels.
  - **While loading:** a quiet placeholder in the tile's inset colour.
  - **If it fails:** the alt text, centred, and the tile still takes a
    tap.
- **D3: `PictureGrid`** lays out 2 to 4 tiles:
  - two columns, 12 px apart both ways
  - every tile the same size and square
  - three tiles sit two then one, the last centred
  - on wide screens, the grid is at most 400 px wide and centred, so
    pictures don't grow past a comfortable size

  At 320 px wide, each tile is about 138 px, well over the 48 px tap
  target.
- **D4: The models, in `exercise.dart`.**
  - A `PictureChoice(imageUrl, altText)`.
  - `ImageChoiceExercise(id, prompt, choices, correctOptionIndex)`.
  - `AudioImageChoiceExercise(id, audioUrl, instruction, choices,
    correctOptionIndex)`.
  - `isAnswerCorrect` grades both by index, like multiple choice.
  - `LessonController` needs no change: `chooseOption` grades, and a wrong
    answer costs a bean and is requeued.
- **D5: Parsing, in `http_lesson_api.dart`.**
  - Both types are added to the known set and to `_toExercise`, which
    practice's due items use too.
  - `image_url` and `audio_url` resolve against the API base, as audio
    already does. A `/media/...` path works locally, and an https URL is
    kept as it is.
  - Choices keep the server's order, and the answer id becomes an index.
  - A type the app doesn't know is still skipped and counted. A new test
    uses a made-up future type to prove it.
- **D6: The lesson screen.**
  - **`image_choice`:** `QuestionPrompt` shows the prompt, split as other
    prompts are. For example, "Choose the picture: 'ውሻ'" shows the
    instruction and the word.
  - **`audio_image_choice`:** only the instruction and the large play
    button, laid out like listening. If a prompt is written as
    "Instruction: 'word'", only the instruction shows, so the word is
    never given away.
  - **Answers:** both use a `PictureGrid` of `PictureTile`s, with the same
    `choiceStateOf` rule as `_choices`. Only the chosen tile shows its
    grade, and no tile takes a tap once graded.
  - **Audio:** `_clipOf` gains the audio type, so the clip plays once by
    itself, not again when answered or rebuilt, and the button replays
    it.
  - **Where pictures come from:** a small `pictureImageFor(source)` in
    `lib/features/lesson/` maps a source to an image:
    - http or https becomes a network image
    - an `assets/` path becomes an asset image, used by the fake API and
      the gallery

    Bolt 054 adds downloaded files.
- **D7: Sample pictures bundled with the app.** Four of bolt 051's
  pictures are copied into `assets/pictures/`: water, dog, house and cat,
  about 44 KB in all.
  - The fake API's picture lessons and the gallery use them, so both work
    without a backend or the network.
  - A test checks each copy is byte-for-byte the same as
    `backend/sample_pictures/`, so they stay covered by `credits.json`.
    Bolt 054 shows those credits in the app.
- **D8: Downloaded lessons and the lesson cache: what changes now.**
  - **Both types are saved and read back.** `packExerciseToJson` is an
    exhaustive switch, so leaving them out would not compile.
    `packExerciseFromJson` is a string switch, and without the new types
    it would throw on a cached copy offline. The lesson cache uses the
    same JSON.
  - **Offline rule:** a cached copy with an `audio_image_choice` needs
    the network for its clip, as listening does. So offline it isn't
    played in place of a download. This is a one-line addition to the
    existing rule.
  - **Left for bolt 054 (story 003):**
    - downloading pictures and the new type's audio into packs
    - pack size and delete
    - the cached-copy rule for pictures

    Until then, a downloaded picture question still loads its pictures
    from the network. Offline, it shows the alt text and can still be
    answered.
- **D9: The fake API** gains:
  - one `image_choice` and one `audio_image_choice` in the coffee lesson,
    after the existing five
  - a picture question among the practice due items, so practice shows
    one too

### Deliverables

- **`lib/shared/widgets/exercise/`**
  - `answer_tile.dart`: the picture shape.
  - `picture_tile.dart` (new): `PictureTile` and `PictureGrid`.
- **`lib/shared/models/exercise.dart`:** `PictureChoice`, both exercise
  types, and grading.
- **`lib/shared/services/`**
  - `http_lesson_api.dart`: parsing both types.
  - `fake_lesson_api.dart`: the sample questions.
  - `lesson_pack_store.dart`: JSON for both types.
- **`lib/features/lesson/`**
  - `screens/lesson_screen.dart`: prompt, answer and clip arms for both
    types, and the offline rule for the audio type.
  - `picture_source.dart` (new): where a picture is loaded from.
- **`lib/shared/gallery/gallery_exercise.dart`:** the tile in every state,
  grids of 2, 3 and 4, and a loading and a failed picture.
- **`assets/pictures/`:** the four pictures, listed in `pubspec.yaml`.
- **Tests:**
  - **New:** `picture_tile_test.dart` and a picture-question lesson test.
  - **Additions:** parsing, pack JSON, fake API and the asset copies.
  - **Frame test:** the frame test and the overflow tests, extended to
    seven types.

### Dependencies

- Bolt 050: the API shape. Bolt 051: the sample pictures and their
  credits.
- No new packages. `ResizeImage`, `AssetImage` and `NetworkImage` are
  part of Flutter.

### Out of Scope

- Downloading pictures into packs, early loading, and the licences page
  (bolt 054).
- Flutter web drawing pictures from R2 needs the bucket's CORS rule
  (finding 3). Without it, the web shows alt text. The rule isn't
  changed here.

### Acceptance Criteria

**Story 001: the picture tile in the kit**
- [ ] `PictureTile` has `AnswerTile`'s six states, with the same press,
      shelf, shake and colours, and a picture in place of the label.
- [ ] 2, 3 and 4 tiles sit in a 2×2 grid, three as two then one. Every
      tile is the same size, 12 px apart.
- [ ] Pictures are fitted without cropping and decoded at tile size.
- [ ] A loading picture shows a quiet placeholder. A failed one shows its
      alt text and still takes a tap.
- [ ] A screen reader reads the alt text, with the button and selected
      state.
- [ ] The gallery shows every state, grids of 2, 3 and 4, and a loading
      and a failed picture.
- [ ] Nothing overflows at 320 and 360 px, at 1.0× and 1.3× text, and
      every tile is at least 48 px.
- [ ] The rules test passes with no new allow-list entries.

**Story 002: picture questions in lessons and practice**
- [ ] **`image_choice`:** the split prompt above the grid.
- [ ] **`audio_image_choice`:**
  - Only the instruction and the play button show, with no written word.
  - The clip plays once by itself, not again when answered or rebuilt,
    and the button replays it.
- [ ] **Grading:**
  - A tap grades only that tile, and a wrong tile shakes.
  - No tile takes another tap once graded.
  - A wrong answer loses a bean and the question comes back later.
- [ ] **The frame:** in a lesson with all seven types, the frame test
      finds the same top bar, prompt place, action bar and answer edge for
      each.
- [ ] **Practice:** a due word with a picture question shows and grades
      there, and its review progress is sent.
- [ ] **Local pictures:** a `/media/...` picture resolves against the API
      base.
- [ ] **Older apps:** a type the app doesn't know is skipped and counted
      in `unrenderableCount`, and the lesson completes.
- [ ] **Overflow:** nothing overflows at 320 and 360 px, at 1.0× and 1.3×
      text, before and after answering.

**Baselines**
- [ ] All 825 Flutter tests pass. The only exceptions are the 7 end-to-end
      tests that already fail because they need a backend.
- [ ] `flutter analyze` adds nothing to its 13 infos, and `dart format` is
      run on touched files.
- [ ] No existing test changes, except where a new type is added to a
      list.

### Test Plan

- **`picture_tile_test.dart`:**
  - the six states' colours and icons, matched against a text tile's
  - press and tap, and no tap when used or disabled
  - the shake, and no shake with reduced motion
  - semantics
  - loading and failed pictures, and a failed tile's tap
  - `ResizeImage` at the tile's pixel width, and `BoxFit.contain`
  - the grid at 2, 3 and 4 tiles: sizes, 12 px gaps, the centred third,
    and at least 48 px
  - no overflow at the four sizes
- **Lesson tests:**
  - both types' prompts, and the audio type's missing word
  - the audio type's first play, no replay on rebuild or when answered,
    and replay from the button
  - right and wrong taps, a lost bean and the requeue
  - the seven-type frame and overflow tests
  - practice with a picture question
- **Parsing tests:** both types, the answer index, `/media` and https
  addresses, practice due items, and the made-up future type.
- **Pack JSON test:** both types round trip.
- **Fake API and asset test:** the fake API's picture questions are
  valid, and the bundled pictures match the backend's.
