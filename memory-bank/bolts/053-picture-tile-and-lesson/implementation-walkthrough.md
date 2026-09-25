---
stage: implement
bolt: 053-picture-tile-and-lesson
created: '2026-09-25T18:47:51Z'
---

## Implementation Walkthrough: image-choice-ui (picture tile, lessons and practice)

### Summary

The question kit now has a picture answer tile and a grid for 2 to 4 of
them. Both picture question types are read from the API, graded, kept by
the lesson cache and downloaded packs, and played in lessons and practice
in the same frame as the other five types. The fake API and the component
gallery show them with four bundled sample pictures, so neither needs a
backend.

### Structure Overview

The picture tile is not a second tile. It is the existing answer tile with
a new "picture" shape, which draws a square face with the picture inset
instead of a label. So its states, colours, press, shake and screen-reader
behaviour are the same code as every other answer. A thin `PictureTile`
wrapper adds how the picture is shown:
- fitted, never cropped
- decoded at the tile's size
- a placeholder while it loads
- the alt text if it fails

`PictureGrid` lays tiles out two to a row. The lesson screen maps each
picture's address to an image through one small helper, so bolt 054 can
add downloaded files in one place.

### Completed Work

- [x] `lib/shared/widgets/exercise/answer_tile.dart`: the picture shape.
  - a square face with the picture inset 8 px
  - the grade icon in the top corner, on the face colour
  - a faded picture where a row fades its text
  - fallback text in the tile's text colour
  - the label kept as what a screen reader reads
- [x] `lib/shared/widgets/exercise/picture_tile.dart` (new)
  - **`PictureTile`:** the picture, fitted and decoded at tile size, with
    a loading placeholder and an alt-text fallback. Both have keys that
    tests can find.
  - **`PictureGrid`:** two columns 12 px apart, square tiles of one size,
    and a third tile centred. It is at most 400 px wide and centred.
- [x] `lib/shared/models/exercise.dart`: `PictureChoice`,
  `ImageChoiceExercise` and `AudioImageChoiceExercise`. Both are graded by
  index, like multiple choice.
- [x] `lib/shared/services/http_lesson_api.dart`:
  - Both types are known and parsed, for lessons and practice due items.
  - The answer id is turned into an index.
  - Picture and clip addresses resolve against the API through one shared
    helper, which listening now uses too.
- [x] `lib/shared/services/lesson_pack_store.dart`: both types are saved to
  and read from a pack's JSON. Picture addresses are kept as they came.
- [x] `lib/shared/services/fake_lesson_api.dart`:
  - The coffee lesson gains an image choice question with four pictures
    and an audio image choice question with three.
  - One word (ቤት, house) is now due for practice, as a picture question.
    It stays due until a practice session reports it.
- [x] `lib/features/lesson/picture_source.dart` (new): an `assets/` path
  becomes a bundled image, and anything else a network image.
- [x] `lib/features/lesson/screens/lesson_screen.dart`
  - **Image choice:** the prompt is split as usual, above the picture
    grid.
  - **Audio image choice:** only the instruction and the play button show,
    never the word. The layout is listening's, now shared by both.
  - **Answers:** both use the grid, with the same "only the chosen one
    shows its grade, and nothing takes a tap once graded" rule as the
    text choices.
  - **Clip:** the audio type's clip plays once by itself, through the
    existing first-play rule.
  - **Offline:** a cached copy isn't played offline if any question has a
    clip. Before, only listening counted.
- [x] `lib/shared/gallery/gallery_exercise.dart`: a new picture section.
  - a grid of four in idle, selected, correct and incorrect
  - a grid of two in used and disabled
  - a working grid of three with the action bar
  - a loading picture and a failed picture
- [x] `assets/pictures/` (new): water, dog, house and cat, byte-for-byte
  copies of `backend/sample_pictures/`, about 44 KB in all. Also a
  `credits.json` with their four entries.
- [x] `pubspec.yaml`: the four pictures are listed as assets.
- [x] `test/features/lesson/screens/lesson_screen_kit_test.dart`: its
  "answer correctly" helper gains the two types. It is an exhaustive
  switch, so the file would not compile without them.
- [x] `test/shared/widgets/exercise/answer_tile_test.dart`: the label
  text-scale test runs over every tile shape, so it now skips the picture
  shape, which draws no label.

### Key Decisions

- **The tile is a shape of `AnswerTile`, not a new widget with copied
  states.** A grade can't look different on a picture than on a word,
  because it is drawn by the same code.
- **`AnswerTile` checks that a picture comes only with the picture
  shape,** so a picture tile can't be built without one, and a text tile
  can't be given one by mistake.
- **The grade icon sits on a small circle of the face colour,** so a tick
  or cross stays readable over any picture.
- **Pictures are decoded to fit a square at the tile's pixel size,** not
  just its width, so a tall picture isn't decoded larger than it is
  drawn.
- **The grid's 2-to-4 check runs when it builds, not when it is made.**
  That way the gallery and lessons can still build it as a constant.
- **The offline rule now asks "does any question play a clip?"** It
  reuses the same helper that starts a clip, so the next type with audio
  is covered without another edit.

### Deviations from Plan

- **Two existing test files changed, each only for the new types.**
  - **The kit test:** it has to compile. Its frame and overflow tests
    gain the seven types in the Test stage.
  - **The answer tile test:** it loops over every tile shape, so it now
    skips the picture shape. Its scaled text is covered by the new picture
    tests.
- **`assets/pictures/credits.json` is new.** The pictures are CC BY-SA, so
  their credits travel with the copies. It isn't bundled into the app;
  bolt 054 decides how the credits appear there.
- **The fake's due word is removed once reviewed.** Without that, it would
  stay due forever after practising it in the demo.

### Dependencies Added

None. Resizing, bundled images and network images are part of Flutter.

### Developer Notes

- **Checks:**
  - `flutter analyze` shows the same 13 infos as before.
  - The suite is 825 passing, plus the 7 end-to-end tests that need a
    running backend.
  - The tile was rendered once to an image from a throwaway test, which
    was then deleted. Pictures decode, sit inside the square uncropped,
    and the third tile is centred.
- **Not reformatted:** `lesson_pack_store.dart` was already not in `dart
  format` style, so only the new lines follow it. The rest of the file was
  left as it was, so the diff shows only this bolt's changes.
- **Until bolt 054:**
  - A downloaded pack's picture questions still load their pictures, and
    the audio type its clip, from the network.
  - Offline, the pictures show their descriptions and can still be
    answered.
- **Flutter web:** pictures on R2 need the bucket's CORS rule (finding 3),
  which has not been changed.
