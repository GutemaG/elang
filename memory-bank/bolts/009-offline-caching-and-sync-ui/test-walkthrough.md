---
stage: test
bolt: 009-offline-caching-and-sync-ui
created: '2026-09-17T00:20:00Z'
---

## Test Walkthrough: Offline Caching & Sync UI (part 1)

### Summary

Added dedicated coverage for the 3 new services and the 2 screens' offline
branches introduced in Stage 2 (Implement), on top of the existing suite's
signature-fixup updates from that stage. Full suite: **99/100 passing** --
the 1 failure (`http_auth_api_e2e_test.dart`, tag `e2e`) requires a real
running backend and is pre-existing/unrelated to this bolt (unchanged by
this bolt's diff; fails the same way with or without these changes since
no backend is running in this environment).

### New Test Coverage

- [x] `test/shared/services/lesson_pack_downloader_test.dart` (new, 6 tests):
  - a lesson with no listening exercises downloads with zero HTTP audio calls
  - a lesson with a listening exercise downloads its audio and rewrites `audioUrl` to the local file (verifies the file exists on disk with the right bytes)
  - a failure fetching the lesson itself leaves it `failed` with nothing saved
  - a non-200 audio download leaves the lesson `failed` with nothing saved
  - `statusFor` defaults to `notDownloaded` for a lesson never touched
  - `refreshDownloadedStatuses` reflects packs already saved from a previous session
- [x] `test/features/lesson/screens/lesson_screen_test.dart` (+2 tests):
  - offline with a downloaded pack plays from the cache instead of the network (proven by leaving the api's `lessonContent` unset, so a fall-through to the network path would throw)
  - offline with this lesson never downloaded shows the "download required" state, not a generic error, and "Go back" returns to the caller
- [x] `test/features/lesson/screens/skill_tree_dashboard_screen_test.dart` (+2 tests):
  - a previously-downloaded lesson shows the downloaded icon as soon as the dashboard loads
  - tapping the download affordance on an un-downloaded lesson downloads it and updates the icon

### Test Helper Changes

- [x] `test/helpers/controllable_lesson_api.dart` -- added `startLessonError` (mirrors the existing `completeLessonError`/`skillTreeError` pattern) so a download failure can be simulated
- [x] `pubspec.yaml` -- added `path_provider_platform_interface` as a direct dev dependency (was already transitive via `path_provider`) so `lesson_pack_downloader_test.dart` can swap `PathProviderPlatform.instance` for a fake pointing at a real temp directory -- the plugin boundary, letting the audio-file-write path run for real without touching a device/emulator

### Deliberate Scope Decisions

- **`SqfliteLessonPackStore` and `ConnectivityPlusMonitor` have no dedicated unit tests.** Both are thin real-plugin wrappers behind an interface (`LessonPackStore`/`ConnectivityMonitor`) whose `Fake*` counterpart is what every screen test actually exercises -- the same pattern already established for `AudioplayersLessonAudioPlayer` (also untested directly). Testing `sqflite` against a real database would require adding `sqflite_common_ffi` purely for test infrastructure, which is a bigger scope decision than this bolt's two stories call for. `LessonPackDownloader`, which owns the actual orchestration logic (status transitions, audio rewrite, failure handling), is fully tested against a real temp-directory filesystem instead.
- **`_downloadAudioAndRewrite`'s temp-directory approach also covers the "audio downloads to real disk" path** that `SqfliteLessonPackStore` itself doesn't get a dedicated test for -- so the one plugin genuinely exercised for real (`path_provider`, via the fake platform-interface swap) is the one this bolt's logic most depends on getting right.

### Verification

- `flutter analyze`: clean (1 pre-existing, unrelated info-lint in `http_lesson_api.dart`, present before this bolt)
- `flutter test`: 99/100 passing; the 1 failure is the pre-existing `e2e`-tagged backend-integration test, unrelated to and unchanged by this bolt

### Success Criteria (from bolt.md)

- [x] A downloaded lesson pack (all 3 exercise types + audio) plays fully offline with correct grading and Beans/XP bookkeeping -- content-loading path tested directly; grading/Beans/XP bookkeeping reuses `LessonController`, already covered by story 002/003's existing tests once content loads
- [x] Cached packs survive app restart -- `LessonPackStore.load`/`save` round-trip tested via `LessonPackDownloader`'s tests and the offline-cache lesson-screen test; the underlying `sqflite` persistence itself is a thin wrapper (see Deliberate Scope Decisions)
- [x] Attempting an un-downloaded lesson while offline shows a clear "download required" state, not a hang or crash -- tested directly
