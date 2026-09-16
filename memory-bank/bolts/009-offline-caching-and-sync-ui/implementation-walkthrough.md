---
stage: implement
bolt: 009-offline-caching-and-sync-ui
created: '2026-09-16T23:50:00Z'
---

## Implementation Walkthrough: Offline Caching & Sync UI (part 1)

### Summary

Downloaded lesson packs (content + listening-exercise audio) now persist locally via `sqflite`, and a lesson opened while offline plays from that cache instead of the network -- with a distinct "download this lesson first" state when it wasn't cached. Also fixed a real, otherwise-breaking gap: `HttpLessonApi.completeLesson` now sends the `client_completed_at` field bolt 008 made required backend-side.

### Structure Overview

Three new plugin-boundary services under `lib/shared/services/` (mirroring `LessonAudioPlayer`'s existing pattern: an abstract interface, a real plugin-backed implementation, a `Fake*` test double): `ConnectivityMonitor` (online/offline detection), `LessonPackStore` (local persistence of a downloaded pack), and `LessonPackDownloader` (orchestrates fetching + audio download + persistence, exposes per-lesson status as a `ChangeNotifier`). Everything else is a threading-through of these three services into the existing dependency-injection chain (`LessonDependencies` → `main.dart`/`SkillTreeDashboardScreen`/`LessonScreen`), plus two small existing-code fixes (the `client_completed_at` gap, and `LessonAudioPlayer` learning to play a local file path).

### Completed Work

- [x] `pubspec.yaml` — added `sqflite`, `path_provider` (promoted from transitive), `connectivity_plus`
- [x] `lib/shared/models/skill_tree.dart`, `lib/shared/models/lesson_content.dart` — added nullable `contentVersion`
- [x] `lib/shared/services/lesson_api.dart` — `completeLesson` gained required `clientCompletedAt`
- [x] `lib/shared/services/http_lesson_api.dart` — parses `content_version`; sends `client_completed_at`
- [x] `lib/shared/services/fake_lesson_api.dart` — signature updated to match the interface
- [x] `lib/features/lesson/state/lesson_controller.dart` — captures `DateTime.now().toUtc()` as `clientCompletedAt` at completion time
- [x] `lib/shared/services/connectivity_monitor.dart` — new `ConnectivityMonitor` interface + `ConnectivityPlusMonitor`
- [x] `lib/shared/services/lesson_pack_store.dart` — new `LessonPackStore` interface + `SqfliteLessonPackStore` (one table, JSON-blob content column)
- [x] `lib/shared/services/lesson_pack_downloader.dart` — new `LessonPackDownloader`: fetches via `LessonApi`, downloads listening-exercise audio via `http` into `path_provider`'s app-documents directory, rewrites `ListeningExercise.audioUrl` to the local path, persists via `LessonPackStore`
- [x] `lib/shared/services/lesson_audio_player.dart` — `AudioplayersLessonAudioPlayer.play` branches remote URL vs. local file path
- [x] `lib/features/lesson/lesson_dependencies.dart` — wires the 3 new services' real defaults
- [x] `lib/features/lesson/screens/skill_tree_dashboard_screen.dart` — per-node download-status icon overlay (`_DownloadAffordance`), calls `refreshDownloadedStatuses()` on load
- [x] `lib/features/lesson/screens/lesson_screen.dart` — offline branch (`_loadLessonContent`), new `LessonNotDownloadedOfflineException` + `_DownloadRequiredState`
- [x] `lib/main.dart` — threads the 3 new dependencies through to the dashboard
- [x] `test/helpers/fake_connectivity_monitor.dart`, `test/helpers/fake_lesson_pack_store.dart` — new test doubles
- [x] Updated all existing test call sites broken by the 2 signature/schema changes (`fake_lesson_api_test.dart`, `http_lesson_api_test.dart`, `controllable_lesson_api.dart`, `lesson_screen_test.dart`, `skill_tree_dashboard_screen_test.dart`)

### Key Decisions

- **Audio URL rewritten in place, not tracked separately**: `LessonPackDownloader` rewrites `ListeningExercise.audioUrl` to the downloaded file's local path *before* handing the `LessonContent` to `LessonPackStore.save`. This means `LessonPackStore` itself never needs a separate "local audio paths" concept, and `AudioplayersLessonAudioPlayer.play` needs only one small branch (scheme-based) to handle both cases identically whether the content came from the network or a cached pack.
- **Download affordance kept plain**: a small icon-button overlay (`_DownloadAffordance`) on each skill-tree node, not a new Highland Pulse-styled component — matches the plan's explicit call to prioritize the capability over polish for this bolt.
- **`sqflite` single-JSON-blob table**: one row per lesson, content serialized as JSON rather than normalized columns — there's exactly one shape to round-trip, so normalizing would add complexity with no query benefit (same reasoning the backend's own ADR-3 used for its `exercises` table).

### Deviations from Plan

None. The plan's explicitly-deferred items (14-day staleness re-check, skill-tree unlock visibility) remain deferred as planned — `contentVersion` is stored and threaded through, ready for a later pass to act on.

### Dependencies Added

- [x] `sqflite` — local pack storage
- [x] `path_provider` — promoted from transitive to direct; resolves where downloaded audio files live
- [x] `connectivity_plus` — online/offline detection

### Developer Notes

- `AudioplayersLessonAudioPlayer.play` distinguishes local vs. remote purely by URL scheme (`http://`/`https://` vs. anything else) — a bare local file path never has a scheme, so this is unambiguous without needing a separate flag threaded through `Exercise`.
- `SqfliteLessonPackStore`'s database and `LessonPackDownloader`'s audio-file directory both resolve lazily on first use (`path_provider`/`sqflite` calls only happen inside real method calls, never in a constructor) — this is why widget tests that construct `LessonDependencies()` without overriding the new services (e.g. `widget_test.dart`, `splash_screen_test.dart`) don't crash even though they never inject fakes for them: those tests never navigate far enough to trigger an actual plugin call.
- `flutter analyze`: clean except one pre-existing, unrelated info-lint in `http_lesson_api.dart` (present before this bolt).
- Full existing Flutter suite (89/89) re-run and passing after every signature/schema change, not just the directly-touched tests.
