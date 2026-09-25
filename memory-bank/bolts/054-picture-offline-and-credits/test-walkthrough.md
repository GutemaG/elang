---
stage: test
bolt: 054-picture-offline-and-credits
created: '2026-09-25T20:37:19Z'
---

## Test Report: image-choice-ui (offline pictures, early loading, credits)

### Summary

- **Tests:** all 952 Flutter tests pass.
  - 903 were passing before the bolt, and 42 are new.
  - The 7 end-to-end tests passed too this time, because a backend was
    running on port 8000.
- **Checks:**
  - `flutter analyze` shows the same 13 infos as before.
  - `dart format` finds nothing to change in any file this bolt wrote.
- **Coverage:** not measured.
- **Mutation check:** 34 deliberate breakages of the new code.
  - **Where:** the downloader, the pack's file list, picture sources, the
    lesson screen, the size helpers, the credits, the settings row and
    `pubspec.yaml`.
  - **First run:** 31 were caught.
  - **After fixes:** the three gaps were closed with new tests, and all
    34 are now caught.
  - Each file was checked to be restored exactly after its run.

### Test Files

- [x] **`test/shared/services/lesson_pack_downloader_pictures_test.dart`**
  (13, new): real files in a temp folder.
  - **Saving:**
    - Both types save every picture and the clip.
    - The pack points at the saved files, each holding what its own
      address served.
    - Prompts, alt text, answers and the skipped-type count are kept.
  - **File names:**
    - `{exercise}-picture-{n}` and `{exercise}`.
    - The path's extension, with no `?query`, and none when the address
      has none.
  - **A shared picture** is fetched once, and both choices use its file.
  - **Other lessons:**
    - A listening clip is still `{exercise}.mp3`.
    - A lesson whose only media is image choice still downloads.
    - A lesson with no media makes no request.
  - **The file list:** every file the pack refers to is one the download
    saved.
  - **A failed download:**
    - A failed picture, clip or later picture means failed, nothing saved,
      and no files left.
    - A failed re-download keeps the earlier pack and all its files.
    - A file only the failed attempt created is removed again.
- [x] **`test/shared/services/pack_local_files_test.dart`** (4, new)
  - Every kind of clip and picture is listed, a shared one once.
  - http, https and assets are skipped.
  - A pack of the four text types has no files.
  - The list survives the pack's JSON round trip.
- [x] **`test/features/lesson/picture_source_test.dart`** (4, new)
  - http and https are network pictures.
  - `assets/` is bundled.
  - A Unix or Windows path is a device file.
  - A file whose name merely contains "https" is still a file.
- [x] **`test/features/lesson/screens/lesson_screen_picture_loading_test.dart`**
  (10, new)
  - **A downloaded pack, offline:**
    - It plays its pictures as device files and its clip from the device.
    - Its pictures are loaded early from the device.
  - **A cached copy, offline:**
    - With only an audio picture question, it asks for a download.
    - With no media, it still plays.
  - **Early loading:**
    - Every picture is asked for when the lesson opens, each once. That
      is 3 cache entries for 4 uses.
    - The tile then draws exactly those cached copies, with no second
      copy.
    - A lesson with no pictures asks for nothing.
    - A failed picture is dropped, blocks nothing, and its tile asks again
      and shows its description.
    - Leaving before the pictures arrive raises nothing.
    - Practice loads its pictures early too.
- [x] **`test/shared/licences/picture_credits_test.dart`** (8, new)
  - **Building the entries:**
    - One per picture, in order, under "Sample pictures".
    - The exact paragraphs: title, author and source, source link, licence
      and link, and changes.
    - A CC0 picture is listed.
    - An added picture is listed with no code change.
    - Blank fields are left out.
  - **Registering them:**
    - The file is read only when the page asks for it.
    - An unreadable file lists nothing and raises nothing.
    - The real bundled file credits exactly the bundled pictures, with
      each author, source and licence.
- [x] **`test/features/settings/screens/settings_licences_test.dart`** (2,
  new)
  - The "Licences" row sits after "Sound".
  - Tapping it opens the licence page for "Buna". "Sample pictures" is
    listed there, and opens to the credit's author and licence lines.
- [x] **`test/shared/widgets/exercise/picture_tile_test.dart`** (1 added):
  `tileWidthFor` matches the width the grid really lays out, from narrow
  to capped wide.
- [x] **Changed in Implement, and passing:**
  - `lesson_screen_pictures_test.dart`: the reversed offline test.
  - `fake_lesson_api_pictures_test.dart`: the `pubspec.yaml` list.

### Acceptance Criteria Validation

**Story 003: offline packs with pictures**
- ✅ **Downloading saves every picture and the clip, and the pack refers
  to them by local path:** covered by the downloader tests.
- ✅ **With no network, every picture shows and the clip plays:** covered
  by the offline pack tests.
- ✅ **A failed picture or clip saves no pack and reports failure:**
  covered by the failure tests. The attempt's files are also removed.
- ✅ **A cached copy with either type asks for a download offline:**
  covered by the cache tests and the reversed 053 test.
- ✅ **Removing a pack deletes its pictures and clips:** delete now uses
  `packLocalFiles`, which is tested.
- ✅ **The pack size includes the pictures:** also through
  `packLocalFiles`.
- ✅ **A pack with both types round-trips unchanged:** covered by the pack
  JSON tests (053) and the round trip with local paths.

**Story 004: pictures ready before their question**
- ✅ **Every picture is requested when an online lesson loads:** covered
  by the early-loading tests.
- ✅ **A failure blocks nothing, and the tile loads the picture again:**
  covered by the failure test.
- ✅ **A downloaded pack's pictures are warmed from the device:** covered
  by the offline pack test.
- ✅ **A lesson with no pictures does nothing extra:** covered.

**Story 005: picture credits in the app**
- ✅ **Settings has a "Licences" entry:** covered by the settings test.
- ✅ **It opens Flutter's licence page, listing the picture credits:**
  covered by the settings test.
- ✅ **Each picture shows its author, source and licence from the credits
  file:** covered by the credits tests.
- ✅ **A picture added to the file is listed with no code change:**
  covered by the credits tests.

**Baselines**
- ✅ **Tests:** every earlier test passes.
- ✅ **Checks:** `flutter analyze` has no new issues, and `dart format`
  was run on the touched files.
- ✅ **Existing tests:** the only changes are the two planned in
  Implement.

### Issues Found

**No bugs found in the new code.** The mutation check found three gaps in
the tests, now closed:
- **Image choice alone:** a lesson whose only media was an image choice
  question wasn't downloaded, and no test noticed.
- **The 400 px cap in `tileWidthFor`:** removing it went unnoticed. In the
  grid, the layout caps the width anyway, but early loading on a wide
  screen relies on the helper.
- **The heading:** "Sample pictures" was only checked against its own
  constant.

### Notes

- **The deleting half of delete and size isn't run by a test.**
  - Both live in the `sqflite` store, which a `flutter test` can't open.
    What they now depend on, `packLocalFiles`, is tested directly.
  - A device check would confirm it end to end: download "Coffee &
    Hospitality" against a backend serving pictures, check the size on
    Downloads, then delete it.
- **`main()` isn't run by any test,** so registering the credits at start
  is covered only by the registration tests.
  - The mutation check left that line alone.
  - Opening Settings, then Licences, in the running app shows it.
