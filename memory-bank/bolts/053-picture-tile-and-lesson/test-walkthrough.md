---
stage: test
bolt: 053-picture-tile-and-lesson
created: '2026-09-25T19:59:38Z'
---

## Test Report: image-choice-ui (picture tile, lessons and practice)

### Summary

- **Tests:** 903 Flutter tests pass. There were 825 before the bolt, and
  78 are new.
  - The only failures are the same 7 end-to-end tests as before. They need
    a backend running on port 8000.
- **Checks:**
  - `flutter analyze` shows the same 13 infos as before, and nothing new.
  - `dart format` finds nothing to change in any file this bolt wrote.
- **Coverage:** not measured.
- **Mutation check:** 46 deliberate breakages of the new code.
  - **Where:** the tile, the grid, the models, parsing, the pack JSON, the
    fake API, the picture source, the lesson screen and the gallery.
  - **First run:** 44 were caught. One was missed, and one was skipped
    because the script's search string matched two lines.
  - **After fixes:** the gap was closed with a stronger test, the script
    was fixed, and all 46 are now caught.
  - Each file was checked to be restored exactly after its run.

### Test Files

- [x] **`test/shared/widgets/exercise/picture_tile_test.dart`** (40, new)
  - **States:** in all six states, the face, border, shelf and corner
    radius match a text tile's.
  - **Grade icon:** a check or a cross in the top end corner, which is the
    top left in a right-to-left language. Idle and selected show neither.
  - **Fading:**
    - Used dims the whole tile.
    - Disabled fades the picture and ignores taps.
    - Once graded, the other pictures fade and the graded one doesn't.
    - A tappable picture isn't faded.
  - **Press and tap:**
    - A tap calls `onTap` once, and the tile sinks onto its shelf and
      returns.
    - No press without `onTap`, and no tap when used.
  - **Shake:** a picture graded wrong shakes once without moving the
    layout. With reduced motion it doesn't shake, but still changes colour.
  - **Screen readers:**
    - One button, read as its description, selected once chosen.
    - The picture, its fallback text and the grade aren't read twice.
    - A screen-reader tap chooses it.
  - **The picture:**
    - The face is square, with the picture 8 px inside the border.
    - It is fitted, never cropped.
    - It is decoded at the tile's size in device pixels, and never
      enlarged.
    - A quiet placeholder shows while it loads.
    - A failed picture shows its description in the state's text colour,
      and can still be chosen.
    - A picture tile must have a picture, and only a picture tile takes
      one.
  - **The grid:**
    - 2, 3 and 4 pictures are two to a row, one square size, 12 px apart.
    - The third of three is centred.
    - It is 400 px wide at most, and centred.
    - Fewer than 2 or more than 4 pictures is caught.
  - **Small screens:** at 320 and 360 px, at 1.0× and 1.3× text, every
    tile is over 48 px, and 200 characters of Fidel fallback text don't
    overflow.
- [x] **`test/features/lesson/screens/lesson_screen_pictures_test.dart`**
  (12, new)
  - **Image choice:**
    - The split prompt sits above the grid, in the server's order.
    - There is no play button.
    - Bundled pictures load from the app, and others from the network.
  - **Grading:**
    - A right tap grades only that picture and costs nothing.
    - A wrong tap shakes that picture and costs a bean.
    - No picture takes a tap after grading.
    - A missed question comes back ungraded after the others, and is
      reported as missed.
  - **Audio image choice:**
    - Only the instruction and the play button show. Even written as
      "…: 'ውሻ'", the word never shows.
    - The clip plays once by itself, not again on a rebuild or an answer,
      and the button replays it.
    - It plays when it is the next question, and again when it comes back
      after a miss, but not on the review page.
    - It is graded by index.
  - **Practice:** both types are graded in a practice session, and each
    word's result is reported.
  - **Offline, a cached copy:**
    - With only image choice, it plays.
    - With an audio image choice, it asks for a download.
- [x] **`test/shared/services/http_lesson_api_pictures_test.dart`** (6,
  new)
  - Both types are read with their prompt or instruction, clip, pictures
    in order, and answer index.
  - `/media` pictures resolve against the API, and https pictures are kept
    as they are.
  - Listening clips still resolve the same way after the shared helper.
  - A made-up future type beside both picture types is skipped and
    counted, and the rest keep their order.
  - A practice due word comes with its picture question.
- [x] **`test/shared/services/fake_lesson_api_pictures_test.dart`** (13,
  new)
  - **The bundled pictures:**
    - They are byte-for-byte the credited originals.
    - The folder holds only those four.
    - Their credits match the originals' entries exactly.
    - `pubspec.yaml` lists exactly these four, and they are in the app
      bundle.
  - **The coffee lesson:**
    - It ends with one question of each picture type.
    - Every picture question has 2 to 4 distinct, described, bundled
      pictures and an answer among them.
    - Water answers the water question, and the audio question never
      writes its word.
  - **Practice:**
    - One word is due, as a picture question.
    - It stays due until reported, and only its own report clears it.
    - A new fake starts with it due again.
    - The limit is respected.
- [x] **`test/design/gallery_pictures_test.dart`** (4, new)
  - All six states are shown as pictures.
  - Grids of 2, 3 and 4 are shown.
  - A loading picture and a failed one are shown, and both can be chosen.
  - The three-picture demo grades on the tap at 360×640 with 1.3× text,
    and Continue resets it.
- [x] **`test/shared/services/lesson_pack_json_test.dart`** (3 added)
  - Both types are added to the "every type" list, and so to the
    every-type round trip.
  - Each type keeps every field through real JSON text, and still grades.
  - The stored type names and picture fields are pinned.
- [x] **`test/features/lesson/screens/lesson_screen_kit_test.dart`**
  (changed, and passing)
  - The frame test and the four small-screen tests now run all seven
    types, before and after answering.
  - The top bar, prompt, action bar and first answer sit in the same
    place for all seven.
- [x] **`test/shared/widgets/exercise/answer_tile_test.dart`** (changed in
  Implement, and passing): the label text-scale loop skips the picture
  shape, which draws no label.

### Acceptance Criteria Validation

**Story 001: the picture tile in the kit**
- ✅ **Six states, with the same press, shelf, shake and colours as
  `AnswerTile`, and a picture in place of the label:** covered by the
  tile tests.
- ✅ **2, 3 and 4 tiles in a 2×2 grid, three as two then one, one size,
  12 px apart:** covered by the grid tests.
- ✅ **Fitted without cropping and decoded at tile size:** covered by the
  picture tests.
- ✅ **A loading placeholder, and a failed picture that shows its alt text
  and still takes a tap:** covered by the picture tests.
- ✅ **A screen reader reads the alt text, as a button, with its selected
  state:** covered by the screen-reader tests.
- ✅ **The gallery shows every state, grids of 2, 3 and 4, and a loading
  and a failed picture:** covered by the gallery tests.
- ✅ **No overflow at 320 and 360 px, at 1.0× and 1.3×, and every tile at
  least 48 px:** covered by the grid and gallery tests.
- ✅ **The rules test passes with no new allow-list entries.**

**Story 002: picture questions in lessons and practice**
- ✅ **`image_choice`: the split prompt above the grid.**
- ✅ **`audio_image_choice`: the instruction and play button only; the
  clip plays once by itself, not again when answered or rebuilt, and the
  button replays it.**
- ✅ **Grading:** a tap grades only that tile, and a wrong one shakes. No
  tile takes another tap. A wrong answer loses a bean and the question
  comes back.
- ✅ **The frame:** it is the same for all seven types.
- ✅ **Practice:** a picture question is graded and its result is
  reported. Due items are parsed with their pictures.
- ✅ **Local pictures:** `/media/...` resolves against the API.
- ✅ **Older apps:** an unknown type is skipped and counted.
- ✅ **Overflow:** there is none at 320 and 360 px, at 1.0× and 1.3×,
  before and after answering.

**Baselines**
- ✅ **Tests:** all earlier tests pass, apart from the same 7 end-to-end
  tests.
- ✅ **Checks:** `flutter analyze` has no new issues, and `dart format`
  was run on the touched files.
- ✅ **Existing tests:** the only changes add the new types to a list,
  or skip the picture shape in one loop.

### Issues Found

**No bugs found in the new code.** The mutation check found one gap in
the tests, now closed:
- Raising the grid's 400 px limit went unnoticed. The wide-screen test
  compared the grid's width with the limit's own constant, so it checked
  itself. It now expects 400 px.

### Notes

- **What the tests can't show:**
  - **Real decoding.** Widget tests can't decode real pictures without
    extra setup, so the tile tests use an in-memory picture. The bundled
    WebP files are checked byte by byte and loaded from the bundle. A
    one-off render during Implement showed them drawn correctly.
  - **Real network pictures.** In the lesson tests, network pictures never
    arrive, so those tiles show their descriptions. That also exercises
    the most text a tile can hold.
- **Not yet tested on a device.**
  - A quick manual check would confirm it end to end: run the app against
    the fake API and open "Coffee & Hospitality" (its last two questions).
  - The Practice card also now has one picture word.
