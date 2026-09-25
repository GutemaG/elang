---
stage: plan
bolt: 054-picture-offline-and-credits
created: '2026-09-25T20:02:39Z'
---

## Implementation Plan: image-choice-ui (offline pictures, early loading, credits)

### Objective

- **Offline:** a downloaded lesson carries every picture and the audio
  picture question's clip, so both picture types play with no network.
  Removing a pack frees them, and its size counts them.
- **Early loading:** a lesson's pictures start loading as soon as the
  lesson opens.
- **Credits:** the bundled sample pictures are credited on a new
  "Licences" page in settings.

### Reference designs (FR-11 of intent 018)

- **Downloads:** the app's own pack downloader (bolt 009) is the pattern.
  Pictures and the new clip are fetched, saved and rewritten to local
  paths exactly as listening clips already are.
- **Licences page:** Flutter's standard licence page
  (`showLicensePage`), which lists every package's licence.
  - The credits follow Creative Commons' "TASL" attribution practice:
    title, author, source and licence, plus what was changed. CC BY-SA
    asks for the change.
  - This is the form OpenMoji asks for.
- **Settings row:** the "Licences" row is shaped like the existing
  "Daily goal" and "Course" rows. Settings moves onto the design library
  in bolt 049, not here.

### Decisions

- **D1: How a pack names its files.** Everything for a lesson goes in its
  existing folder, `lesson_packs/{lessonId}/`.
  - **Listening clips:** unchanged, `{exerciseId}{ext}`.
  - **The audio picture question's clip:** named the same way.
  - **Pictures:** `{exerciseId}-picture-{n}{ext}`, where `n` is the
    choice's position.
    - The extension comes from the address's path, so a `?query` never
      ends up in the name.
    - Each address is fetched once per pack, so two choices with the same
      picture share one file. That covers the story's edge case.
- **D2: A failed download saves nothing and leaves nothing behind.**
  - As today, the pack is saved only once every file has arrived.
  - **New:** files this attempt created are deleted if it fails, which
    covers low storage midway.
  - Files from an earlier download of the same lesson are only
    overwritten, so an existing pack stays usable.
- **D3: One list of a pack's device files.** A new pure function,
  `packLocalFiles(content)`, lists every device file a pack refers to:
  - both kinds of clip, and every picture
  - web addresses and bundled `assets/` paths are skipped
  - each file once

  Delete and size both use it. Today each checks only listening clips
  (finding 4). Because the function has no database, a `flutter test` can
  cover it.
- **D4: Pictures load from the device.** `pictureImageFor` gains a third
  case:
  - `http(s)://` is a network image
  - `assets/` is a bundled image
  - anything else is a file on the device, which is how a downloaded
    pack's pictures now look
- **D5: The offline rule for a cached copy follows story 003.** A cached
  copy (not a download) holding either picture type, or a listening
  question, asks for a download when opened offline.
  - **The 053 test this reverses:** bolt 053's test "offline, a cached copy
    with only image choice plays like a pack" asserted the opposite. That
    was the behaviour until this bolt: alt text and still answerable.
  - **Why reverse it:** a picture question shown as descriptions isn't the
    lesson the learner downloaded.
  - **The change:** that one test flips, to expect "download required".
- **D6: Early loading.**
  - **When:** as soon as a lesson or practice session has its content,
    the screen asks Flutter to cache every picture in it, each address
    once.
  - **Matching the tile:** it uses the exact decoded size the tile will
    ask for, so the cached picture is the one the tile draws.
    - That size is worked out by two new helpers, `PictureGrid.tileWidthFor`
      and `PictureTile.decodedImage`. The tile itself now uses the same
      helper.
    - The width comes from the screen, less the page's 20 px margins.
    - If the guess is ever off, the tile just loads the picture itself,
      as it does today.
  - **Failures are ignored.** Flutter drops a failed picture from its
    cache, so the tile tries again when shown. Nothing waits on the early
    load, and leaving the lesson meanwhile raises nothing.
  - **A downloaded pack's pictures** are files on the device, so they
    load with no network request.
  - **A lesson with no pictures** does nothing extra.
- **D7: Which credits file is bundled: `assets/pictures/credits.json`.**
  This is the four-entry copy bolt 053 put beside the bundled pictures.
  - **Why this file:** it credits exactly the pictures the app ships, and
    bolt 053's test keeps each entry identical to
    `backend/sample_pictures/credits.json`.
  - **Why not the other five:** they are only ever served by a local
    backend, and aren't distributed in the app.
  - **Adding a picture:** once it is added to that file, it is listed with
    no code change.
- **D8: The credits are registered with `LicenseRegistry`.**
  - **Where:** a new `lib/shared/licences/picture_credits.dart` holds:
    - a pure function that turns the credits JSON into licence entries
    - a `registerPictureCredits()` that `main()` calls once, before
      `runApp`
  - **How they read:** each picture is one entry, under a package named
    "Sample pictures". An entry reads, for example:
    - "Water"
    - By Vanessa Boutzikoudi, from OpenMoji
    - the picture's source page
    - Licence: CC BY-SA 4.0, with the licence link
    - Changes: Resized to 512 px and converted to WebP
  - **CC0:** a CC0 picture is listed the same way.
  - **When the file is read:** only when the licence page opens, as
    Flutter's registry works.
- **D9: The "Licences" row in settings.** A row after "Sound" opens
  `showLicensePage` with the app's name, "Buna".

### Deliverables

- **`lib/shared/services/`**
  - `lesson_pack_downloader.dart`: pictures and both kinds of clip,
    fetched once per address, with failure clean-up.
  - `lesson_pack_store.dart`: `packLocalFiles`, which delete and size now
    use.
- **`lib/features/lesson/`**
  - `picture_source.dart`: device files.
  - `screens/lesson_screen.dart`: the offline rule, and early loading.
- **`lib/shared/widgets/exercise/picture_tile.dart`:** the shared size
  helpers, which the tile uses.
- **`lib/shared/licences/picture_credits.dart` (new):** building and
  registering the credits.
- **`lib/main.dart`:** registers them.
- **`lib/features/settings/screens/settings_screen.dart`:** the Licences
  row.
- **`pubspec.yaml`:** bundles `assets/pictures/credits.json`.
- **Tests:** the downloader, `packLocalFiles`, picture sources, the
  offline rule, early loading, the credits and the settings row.

### Dependencies

- Bolt 053: the picture types, tile and pack JSON. Bolt 051: the credits.
- No new packages. `LicenseRegistry`, `showLicensePage`, `precacheImage`
  and `FileImage` are part of Flutter.

### Out of Scope

- Downloading on the web build.
- Loading the next lesson's pictures.
- Credits for pictures admins upload later.
- Moving settings onto the design library (bolt 049).

### Acceptance Criteria

**Story 003: offline packs with pictures**
- [ ] **Downloading:** a lesson with both types saves every picture and
      the audio question's clip, and the pack refers to them by local
      path. A shared picture is fetched once.
- [ ] **Playing offline:** the pack plays with no network, every picture
      loads from the device, and the clip is a local file.
- [ ] **Failed downloads:** any picture or clip that fails means no pack
      is saved, the lesson shows as failed, and the attempt's files are
      removed.
- [ ] **Cached copies:** one holding either type asks for a download when
      opened offline.
- [ ] **Removing a pack** deletes its pictures and clips.
- [ ] **Pack size:** the downloads screen's size includes the pictures.
- [ ] **Saving and loading:** a pack with both types round-trips
      unchanged. Bolt 053's JSON test covers this; one with local paths
      is added.

**Story 004: pictures ready before their question**
- [ ] A lesson starting online asks for every picture it uses, at the
      tile's size.
- [ ] A request that fails blocks nothing, and the tile loads the picture
      again when shown.
- [ ] A downloaded pack's pictures are warmed from the device, with no
      network request.
- [ ] A lesson with no pictures does nothing extra, and leaving
      mid-load raises nothing.

**Story 005: picture credits in the app**
- [ ] Settings has a "Licences" entry.
- [ ] Tapping it opens Flutter's licence page.
- [ ] Each bundled picture is listed with its author, source and licence,
      read from the bundled credits file.
- [ ] A picture added to the file is listed with no code change.

**Baselines**
- [ ] All 903 Flutter tests pass. The only exceptions are the 7
      end-to-end tests that already fail because they need a backend.
- [ ] `flutter analyze` adds nothing to its 13 infos, and `dart format`
      is run on touched files.
- [ ] No existing test changes, except the one 053 test D5 reverses.

### Test Plan

- **Downloader**, with real files in a temp folder:
  - both picture types are saved and rewritten
  - file names follow D1, and a shared picture is fetched once
  - a failure saves nothing and cleans up
  - a re-download that fails keeps the old pack's files
- **`packLocalFiles`:**
  - every kind of file is listed, once each
  - web addresses and assets are skipped
  - a pack with no media has none
- **`pictureImageFor`:** the three kinds of source.
- **Lesson screen:**
  - the offline rule for each type, with D5's reversal
  - a downloaded pack playing with file pictures
  - early loading: which pictures, what size, no repeats, a lesson with
    no pictures, failure and retry, and leaving mid-load
- **Credits:**
  - the entries built from JSON, including a CC0 picture and an added
    picture
  - registration through `LicenseRegistry`
  - the bundled file matches the bundled pictures
- **Settings:** the row is there, and opens the licence page.
