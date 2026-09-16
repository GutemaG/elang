---
stage: plan
bolt: 009-offline-caching-and-sync-ui
created: '2026-09-16T23:30:00Z'
---

## Implementation Plan: Offline Caching & Sync UI (part 1)

### Objective

Deliver stories 001 (download lesson packs) and 002 (take a downloaded lesson with zero connectivity) — the two stories that make offline lesson-taking real. Story 003 (pending-sync queue), 004 (status indicator), and 005 (download management screen) are bolt `010`, deliberately deferred since they need offline-completed attempts to exist first.

### Deliverables

**New dependencies** (`pubspec.yaml`) — none of these are in the project yet, `tech-stack.md` doesn't name one, so this bolt picks and documents the choice (no formal ADR stage on a simple-construction-bolt, so the rationale lives here):
- `sqflite` — local storage for downloaded lesson packs. Chosen over `drift` for this project's first-ever local-SQL need: a couple of simple tables, no need for `drift`'s code-gen/type-safety machinery yet. Revisit if bolt 010's pending-sync queue turns out to want richer querying.
- `path_provider` — already a *transitive* dependency (via `audioplayers`' `AudioCache`, see `answer_feedback_player.dart`'s doc comment on that prior investigation); promoted to a *direct* dependency here since this bolt uses it directly to resolve a local directory for downloaded audio files.
- `connectivity_plus` — standard Flutter connectivity-detection package; the project has no existing choice to reuse.

**Model changes**:
- `SkillTreeNode`/`LessonContent` gain `contentVersion` (`DateTime`) — mirrors bolt 008's backend `content_version` field.
- `LessonApi.completeLesson` gains `required DateTime clientCompletedAt` — mirrors bolt 008's now-required `client_completed_at`. `HttpLessonApi` currently sends no such field, so **this is a required fix, not optional polish**: the real backend will reject every completion call without it.

**New services** (plugin-boundary interfaces, matching this codebase's existing `LessonAudioPlayer`/`AnswerFeedbackPlayer` pattern — real implementation + `Fake*` test double, never mocked at the domain layer):
- `ConnectivityMonitor` (`connectivity_monitor.dart`): `Future<bool> isOnline()` + `Stream<bool> onConnectivityChanged`. Real impl wraps `connectivity_plus`.
- `LessonPackStore` (`lesson_pack_store.dart`): persists a downloaded `LessonContent` (serialized) plus local file paths for any listening-exercise audio, keyed by `lessonId`. Real impl (`SqfliteLessonPackStore`) uses one `sqflite` table for pack metadata/JSON and plain files (under `path_provider`'s app-documents directory) for audio.
- `LessonPackDownloader` (`lesson_pack_downloader.dart`): orchestrates `LessonApi.startLesson` + downloading each listening exercise's `audioUrl` via `http`, then `LessonPackStore.save(...)`. Exposes per-lesson download status (`notDownloaded` / `downloading` / `downloaded` / `failed`) via a `ChangeNotifier` so the dashboard can show progress.

**Threaded through existing code**:
- `LessonController._finishLesson()` captures `DateTime.now().toUtc()` as `clientCompletedAt` right when it's called and sends it — identical value whether this is a normal online completion or (bolt 010) a queued offline one being replayed later; this bolt only wires the *online* path correctly, since there's no queue yet to replay from.
- `LessonScreen.initState()`: replaces the single `widget.lessonApi.startLesson(...)` call with a small helper that checks `ConnectivityMonitor.isOnline()` first. Online → unchanged (calls the API). Offline → tries `LessonPackStore.load(lessonId)`; found → builds `LessonContent` with audio URLs rewritten to local file paths; not found → a new, distinct "download this lesson first" screen state instead of a generic error.
- `AudioplayersLessonAudioPlayer.play(url)`: branches on whether `url` has an `http`/`https` scheme; local file paths (no scheme) use `ap.DeviceFileSource` instead of `ap.UrlSource`.
- `SkillTreeDashboardScreen`: a small per-node download affordance (icon + status), wired to `LessonPackDownloader`. Kept visually simple (an icon button, not a new designed component) — polish is a later concern, not blocking the offline capability itself.
- `LessonDependencies`: wires the 3 new services' real defaults, with optional overrides (same pattern as `feedbackPlayer`/`audioPlayer` already use).

### Dependencies

- `001-offline-sync-service` (bolt 008, complete): the amended `content_version` field and `client_completed_at` requirement this bolt's model/API changes mirror.
- `002-core-lesson-loop-ui`'s existing `LessonController`/`LessonScreen`/exercise engine: extended, not replaced.

### Technical Approach

- Downloaded packs store the *fully resolved* `LessonContent` (post-parsing, same shape `startLesson` already returns) rather than raw JSON — avoids a second parsing code path for the offline case.
- Only listening exercises have remote audio to download; multiple-choice/sentence-construction exercises have no network dependency once the lesson JSON itself is cached.
- The 14-day pack-staleness re-check (requirements.md FR-1) is **not** implemented in this bolt — `content_version` is threaded through and stored so a later bolt can compare it, but the actual "is this pack stale, should I re-download" decision needs a moment where the app is confirmed online, which doesn't cleanly fit alongside "make offline-taking work" without scope creep. Flagged explicitly, not silently dropped — revisit as a small follow-up story if not picked up by bolt 010.
- Skill-tree *unlock* visibility while offline (FR-1's other resolved open question) is a natural side effect of this bolt's `LessonScreen`/`ConnectivityMonitor` wiring — the dashboard itself isn't changed to fetch differently, so it already just shows whatever was last fetched online, no extra work needed.

### Acceptance Criteria

- [ ] A user can tap a download affordance on an unlocked skill node and see its lesson pack (content + audio) download, with a visible in-progress state
- [ ] A downloaded lesson, opened with the device offline, plays fully (all 3 exercise types, correct grading, Beans bookkeeping) with zero network calls
- [ ] An un-downloaded lesson, opened while offline, shows a clear "download required" state rather than hanging or crashing
- [ ] `completeLesson` sends a real `client_completed_at` on every call (online path) — the app no longer breaks against the amended backend
- [ ] Skill-tree/lesson-content responses' `content_version` field is parsed and stored, ready for a future staleness check

### Checkpoint Decisions (flagged for visibility, not requiring a pause)

- **`sqflite` over `drift`**: see Deliverables above.
- **14-day staleness re-check deferred**: see Technical Approach above.
- **Download affordance is a plain icon button**, not a new Highland Pulse-styled component — this bolt prioritizes the underlying capability over visual polish.
