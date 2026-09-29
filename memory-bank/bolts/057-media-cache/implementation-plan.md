---
stage: plan
bolt: 057-media-cache
created: '2026-09-29T08:39:52Z'
---

## Implementation Plan: media-cache

### Objective

- A question's clip plays from a file on the device, so it starts as soon
  as the question appears.
- Pictures load from the same files.
- Every clip and picture of a lesson starts downloading the moment the
  lesson's data is known.

### The user's decisions (2026-09-29)

- **U1:** Audio and pictures both.
- **U2:** The dashboard fetches the next lesson's media ahead, on mobile
  data too.
- **U3:** Up to 500 MB, one limit for the whole app (all courses). The user
  can clear it from the phone's app settings.
- The user asked to go straight on to Implement once the plan was written.

### What the code says (checked before planning)

- **F1: Auto-play exists.** `_LessonQuestionState.initState` plays the
  question's clip after its first frame, and the play button shows
  "playing" until `play()` returns.
- **F2: It streams.** `AudioplayersLessonAudioPlayer.play` hands a web
  address to `UrlSource`. Nothing is kept, so every play, replay and
  restart waits on R2.
- **F3: Pictures are memory only.** `pictureImageFor` gives a
  `NetworkImage`; `_loadPicturesEarly` decodes them early, but a restart
  starts from nothing.
- **F4: Downloaded lessons are used offline only.** Online,
  `_loadLessonContent` takes the lesson copy or the network, so a
  downloaded lesson's files are ignored and fetched again.
- **F5: Two versions.** A skill node's `contentVersion` is the latest edit
  in any of its lessons; a lesson's own is that lesson's. A pack stores the
  lesson's, so a pack is current when it equals the loaded content's.
- **F6:** The lesson copy cache and the dashboard's prefetch of lesson data
  (`_prefetchLessons`) already exist; they carry web addresses only.

### Decisions

- **D1: `MediaCache`** (`lib/shared/services/media_cache.dart`), an
  interface with `fileFor(url)` and `warm(urls)`, and `DiskMediaCache`.
  - Files live in the app's cache folder
    (`getApplicationCacheDirectory()/media_cache`), which Android's "Clear
    cache" empties; nothing breaks, files download again.
  - Named by the SHA-1 of the address plus its extension.
  - Written to `name.part`, then renamed: a failed download leaves nothing.
    Leftover `.part` files are removed when the cache opens.
  - Two requests for one address share one download.
  - At most 500 MB. After a write, the least recently used files go first,
    never the one just written. "Used" is the file's modified time, set on
    each hit, so the order survives a restart.
  - `warm` downloads three at a time. A new batch goes to the front of the
    queue, so the lesson being opened beats a background warm.
  - Separate from downloaded lessons, which keep their own folder and are
    never evicted.
- **D2: `CachingLessonAudioPlayer`** wraps the real player. A web address
  plays from `fileFor`; if the download fails it streams as before, so the
  sound still plays. A play asked while an older one is still downloading
  wins: the older one never starts. Local paths play as now.
- **D3: `CachedPicture`**, an `ImageProvider` reading `fileFor`'s file.
  `pictureImageFor(source, cache: ...)` gives it for a web address when a
  cache is passed, and `NetworkImage` otherwise, so the tests and the
  gallery stay as they are.
- **D4: Warm on load.** `_startLesson` warms every clip and picture of the
  lesson in question order (a question's clip before its pictures), Practice
  included.
- **D5: Downloaded lessons online.** Online, a pack whose `contentVersion`
  equals the loaded content's gives its exercises (local files); everything
  else (beans, versions) comes from the loaded content.
- **D6: Dashboard.** After its lesson-data prefetch, the dashboard warms
  the media of the first active lesson.
- **D7: Wiring.** `LessonDependencies.mediaCache`; the default audio player
  is the caching one. `LessonScreen` and `SkillTreeDashboardScreen` take an
  optional `mediaCache`, so every existing test builds unchanged.
- **D8: Dependency.** `crypto` goes from transitive to direct (3.0.7, the
  locked version) for the file names.

### Out of scope

- A "Clear cached media" button in Settings (the phone's own "Clear cache"
  does it).
- Downloading a lesson copying files already in the cache.
- Cache headers on R2 (a production change).

### Acceptance criteria

- **A. Cache**
  - [ ] A miss downloads once and saves; a hit makes no request.
  - [ ] Two requests at once make one download.
  - [ ] A failed download (HTTP error) leaves no file and throws.
  - [ ] Over the limit, the least recently used files are removed, never
    the newest; a hit makes a file recent.
  - [ ] A file removed by the phone is downloaded again.
  - [ ] `warm` fetches in order, skips non-web sources, and drops failures.
- **B. Audio**
  - [ ] A web clip plays from its cached file.
  - [ ] A failed download streams the address instead.
  - [ ] A newer play replaces an older one still downloading.
- **C. Pictures**
  - [ ] With a cache, a web picture loads from the cached file.
- **D. Lesson**
  - [ ] Opening a lesson warms its clips and pictures in question order.
  - [ ] Online, a current downloaded lesson plays from its files; a stale
    one does not.
- **E. Dashboard**
  - [ ] The next lesson's media are warmed after its data is fetched.
- **F. Checks**
  - [ ] `flutter analyze` clean; `flutter test` passes.
  - [ ] On a phone: audio starts at once on a second open, and after a
    restart (left for a person).

---

## Implementation Notes (Stage 2)

Built as planned (D1-D8).

### New

- **`lib/shared/services/media_cache.dart`**
  - `MediaCache` (`fileFor`, `warm`) and `DiskMediaCache`.
  - Also `isWebAddress`, `extensionOfUrl` (moved here from the lesson
    downloader, which now uses it) and `cacheFileName` (SHA-1 plus
    extension).
  - An in-memory index of the folder (size and last use per file) is
    built once, on first use, from the folder itself. A hit updates it and
    sets the file's modified time. Eviction runs after each download.
  - `warm` de-duplicates, drops non-web sources, and puts the new batch in
    front of anything still waiting. Failures go to `debugPrint` only.
- **`CachingLessonAudioPlayer`** in `lesson_audio_player.dart`. Each play
  takes a number; after its file arrives, a play that is no longer the
  latest does not start.
- **`CachedPicture`** in `picture_source.dart`: equal by address and cache,
  so the early load and the tile share one decode. A failed load is dropped
  by Flutter's image cache, so the tile tries again when shown.
- **`lessonMediaOf(content)`** in `lesson_screen.dart`: a lesson's clips
  and pictures in question order. The screen and the dashboard both use
  it.

### Changed

- **`LessonScreen`** (both constructors) takes `mediaCache`.
  - `_startLesson` warms the lesson's media before the first question
    shows.
  - Pictures, early and in the grid, use `CachedPicture` when there is a
    cache.
  - `_withPackFiles`: online, a downloaded pack with the same lesson
    `contentVersion` as the loaded content gives its exercises. A lesson
    with no clips or pictures skips the pack lookup.
- **`SkillTreeDashboardScreen`** takes `mediaCache` and passes it to
  lessons and Practice. After the lesson-data prefetch it warms the first
  open lesson's media from its saved copy. The prefetch loop now `break`s
  at its limit instead of returning, so the warm still runs.
- **`LessonDependencies.mediaCache`** (`DiskMediaCache` by default). The
  default audio player is `CachingLessonAudioPlayer` around the
  `audioplayers` one. `main.dart` passes the cache to the dashboard.
- **`pubspec.yaml`**: `crypto: ^3.0.7`, direct (was transitive; the lock
  file only changes its `dependency:` line).

### Tests

- `test/shared/services/media_cache_test.dart` (13): names, hit and miss,
  after a restart, one shared download, failure leaves nothing, a file the
  phone cleared, leftover `.part` files, least recently used eviction, one
  file over the limit, eviction order after a restart, and `warm` (order,
  three at a time, skips, newer batch first, failures).
- `test/shared/services/caching_lesson_audio_player_test.dart` (4).
- `test/features/lesson/picture_source_test.dart` (+3): the cached
  provider, and a real PNG decoded from its saved file.
- `test/features/lesson/screens/lesson_screen_media_test.dart` (4): warm
  order, nothing to warm, a current pack played online, a stale one not.
- `skill_tree_dashboard_offline_test.dart` (+1): the next lesson's media
  warmed.
- New helper `test/helpers/fake_media_cache.dart`.

## Checks (Stage 2)

- `flutter analyze`: no issues.
- `flutter test`: 1406 passed. The 7 failures in
  `http_auth_api_e2e_test.dart` need a backend on port 8000 (connection
  refused); nothing in this bolt touches auth.
- `media_cache_test.dart` run 5 more times: passed each time (it writes
  real files, so its waits use the real clock).

---

## Test Report (Stage 3)

Implement approved 2026-09-29.

### Runs

| Suite | Result |
|---|---|
| `flutter analyze` | no issues |
| `flutter test --exclude-tags e2e` | 1406 passed |
| `http_auth_api_e2e_test.dart` | 7 of 8 fail: no backend on port 8000 (connection refused); not touched by this bolt |
| `media_cache_test.dart`, repeated | passed 6 of 6 runs |

### Acceptance criteria

- **A. Cache** (`media_cache_test.dart`)
  - [x] A miss downloads once and saves; a hit makes no request, after a
    restart too.
  - [x] Two requests at once make one download.
  - [x] A failed download leaves no file and throws; it is tried again
    next time.
  - [x] Over the limit, the least recently used files go first, never the
    newest; a hit makes a file recent; the order survives a restart.
  - [x] A file removed by the phone is downloaded again.
  - [x] `warm` fetches in order, three at a time, skips non-web sources,
    puts a newer batch first, and drops failures.
- **B. Audio** (`caching_lesson_audio_player_test.dart`)
  - [x] A web clip plays from its cached file.
  - [x] A failed download streams the address instead.
  - [x] A newer play replaces an older one still downloading.
- **C. Pictures** (`picture_source_test.dart`)
  - [x] With a cache, a web picture is decoded from its saved file.
- **D. Lesson** (`lesson_screen_media_test.dart`)
  - [x] Opening a lesson warms its clips and pictures in question order.
  - [x] Online, a current downloaded lesson plays from its files; a stale
    one does not.
- **E. Dashboard** (`skill_tree_dashboard_offline_test.dart`)
  - [x] The next lesson's media are warmed after its data is fetched.
- **F. Checks**
  - [x] `flutter analyze` clean; `flutter test` passes (e2e aside, above).
  - [ ] On a phone: audio starts at once on a second open and after a
    restart. Not tried yet.

### Left for a person

- On a phone: open a lesson with audio twice, and again after closing the
  app; the clip should start at once, with Wi-Fi off the second time for
  a clip already heard.
- Android Settings > Apps > Buna > Storage > Clear cache, then open a
  lesson: it should download again and play normally.
