---
stage: implement
bolt: 054-picture-offline-and-credits
created: '2026-09-25T20:16:42Z'
---

## Implementation Walkthrough: image-choice-ui (offline pictures, early loading, credits)

### Summary

- **Downloads:** a downloaded lesson now saves every picture and the
  audio picture question's clip. Removing a pack frees them, and its size
  counts them.
- **Offline:** a cached copy holding a picture question asks for a
  download when opened offline.
- **Early loading:** a lesson starts loading its pictures as soon as it
  opens, at the size the tiles will draw them.
- **Credits:** settings has a "Licences" row that opens Flutter's licence
  page, where the bundled pictures are credited.

### Structure Overview

The downloader walks every clip and picture a lesson uses. It saves each
address once into the lesson's folder, and points the exercises at the
saved files. It deletes what it created if anything fails.

The pack store asks one pure function which device files a pack refers
to, for both delete and size. The picture source treats anything that
isn't a web address or a bundled asset as a device file.

For early loading, the lesson screen and the tile share two size helpers,
so both arrive at the same cached picture. The credits are read from the
bundled credits file only when the licence page opens.

### Completed Work

- [x] `lib/shared/services/lesson_pack_downloader.dart`
  - Downloads listening clips, the audio picture question's clip, and
    every picture.
  - File names follow D1, and each address is fetched once per pack.
  - A failed download deletes the files this attempt created, and keeps
    any an earlier download saved.
- [x] `lib/shared/services/lesson_pack_store.dart`: `packLocalFiles` lists
  every device file a pack refers to, each once, skipping web addresses
  and assets. It is exhaustive over the question types, so a new type
  won't compile until it is considered. Delete and size now both use it.
- [x] `lib/features/lesson/picture_source.dart`: `http(s)` is a network
  picture, `assets/` a bundled one, and anything else a device file.
- [x] `lib/features/lesson/screens/lesson_screen.dart`
  - **The offline rule:** a cached copy with any clip or picture question
    asks for a download.
  - **Early loading:** each picture in the lesson or practice session is
    requested once, at the tile's decoded size.
  - **Failures:** early-load failures are ignored, and nothing waits on
    it.
- [x] `lib/shared/widgets/exercise/picture_tile.dart`
  - `PictureTile.pictureSideFor` and `PictureTile.decodedImage` work out
    the decoded size.
  - `PictureGrid.tileWidthFor` works out a tile's width.
  - The tile and grid now use these helpers themselves, so they behave
    exactly as before.
- [x] `lib/shared/licences/picture_credits.dart` (new)
  - Builds one licence entry per credited picture, under "Sample
    pictures":
    - its title
    - its author and source
    - the source link
    - its licence and the licence link
    - what was changed
  - `registerPictureCredits` adds them to Flutter's licence registry, and
    reads the file only when the page opens.
  - A file that can't be read leaves the page working.
- [x] `lib/main.dart`: registers the credits before the app starts.
- [x] `lib/features/settings/screens/settings_screen.dart`: a "Licences"
  row after "Sound", shaped like the rows above it. It opens the licence
  page titled "Buna".
- [x] `pubspec.yaml`: bundles `assets/pictures/credits.json`.
- [x] `test/features/lesson/screens/lesson_screen_pictures_test.dart`:
  bolt 053's "a cached copy with only image choice plays offline" is
  reversed to expect "download required", as D5 planned.
- [x] `test/shared/services/fake_lesson_api_pictures_test.dart`: the
  `pubspec.yaml` list check now expects the credits file too.

### Key Decisions

- **One size helper for both the tile and early loading.** A loaded
  picture is only reused if its cache key matches exactly. A second copy
  of the calculation would drift, and every early load would become
  wasted work.
- **Only created files are cleaned up.** Deleting the whole folder would
  also destroy a working earlier download of the same lesson.
- **Early loading doesn't wait for its result.** Flutter drops a picture
  that failed, even when it was resized. I checked Flutter's own code: a
  resized picture removes its own cache entry on error. So there is
  nothing to undo, and the tile retries when shown.
- **Credits are read lazily and never break the page.** The licence page
  must open even if the credits file is missing.

### Deviations from Plan

- **File extensions:** listening clips now take theirs from the address's
  path, as pictures do. Before, it was taken from the last dot anywhere
  in the address.
  - This is the same for every normal address. An address with a query
    string no longer leaks it into the file name.
  - An address with no extension now gets none, rather than `.mp3`. The
    player and pictures read files by content, not by name.
- **Otherwise none.** Both test changes were planned: the D5 reversal,
  and the `pubspec.yaml` list gaining the credits file.

### Dependencies Added

None.

### Developer Notes

- **Checks:**
  - `flutter analyze` shows the same 13 infos as before.
  - The suite is 903 passing, plus the 7 end-to-end tests that need a
    running backend.
- **Not reformatted:** `settings_screen.dart`, `lesson_pack_store.dart` and
  `lesson_pack_downloader.dart` were already not in `dart format` style.
  Only the new lines follow their existing style, so the diff shows only
  this bolt's changes.
- **Early loading's width:** the width used is the screen less the page's
  20 px margins. On a layout that differs, such as a wide tablet, the
  tiles just load their own pictures.
