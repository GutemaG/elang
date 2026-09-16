---
stage: implement
bolt: 006-core-lesson-loop-ui
created: 2026-09-16T10:30:00Z
---

## Implementation Walkthrough: Core Lesson Loop UI

### Summary

Built the skill-tree home dashboard, the lesson exercise screen (all 3 exercise types sharing one template), the out-of-beans/refill modal, and the lesson-complete summary with an optional crown-level-up/streak-freeze modal — matching the Highland Pulse designs. Everything runs against a documented `LessonApi` interface and a stateful `FakeLessonApi`, since `001-lesson-service` isn't implemented yet. The dashboard is now the app's post-sign-in destination.

### Structure Overview

New domain models live in `lib/shared/models/` (skill tree, exercises, lesson content, completion result, beans/refill), and the `LessonApi`/`FakeLessonApi`/`LessonAudioPlayer` boundary lives in `lib/shared/services/`, mirroring exactly how `002-auth-onboarding-ui` split `AuthApi`/`FakeAuthApi` out of `lib/features/auth/`. All lesson-loop screens, the `LessonController` state holder (the unit brief's `InLessonState`), and lesson-specific widgets live under a new `lib/features/lesson/` feature folder, per `coding-standards.md`'s file-organization convention. `AuthRoutes` and `main.dart` received a light touch (not a rewrite) so the dashboard becomes the `home` route's destination without any auth screen needing to change.

### Completed Work

- [x] `lib/shared/models/skill_tree.dart` - `SkillNodeState`, `SkillTreeNode`, `SkillTreeResponse` — the dashboard's data shape
- [x] `lib/shared/models/exercise.dart` - sealed `Exercise` hierarchy (multiple-choice/listening/sentence-construction) plus client-side grading (`isAnswerCorrect`)
- [x] `lib/shared/models/lesson_content.dart` - `LessonContent`, the single-fetch lesson payload
- [x] `lib/shared/models/lesson_completion_result.dart` - `LessonCompletionResult`, including the crown-level-up/streak-freeze flags the summary and level-up modal read
- [x] `lib/shared/models/beans_status.dart` - `BeansStatus`, `RefillResult` (sealed `RefillSuccess`/`RefillFailure`)
- [x] `lib/shared/services/lesson_api.dart` - the `LessonApi` interface bolt 007 and `001-lesson-service` reconcile against
- [x] `lib/shared/services/fake_lesson_api.dart` - stateful in-memory `LessonApi` implementation (seed curriculum, beans, streak, Amole, XP, crown levels) standing in for `001-lesson-service`
- [x] `lib/shared/services/lesson_audio_player.dart` - `LessonAudioPlayer` interface plus the real `audioplayers`-backed implementation
- [x] `lib/features/lesson/lesson_dependencies.dart` - the `LessonDependencies` bag (mirrors `AuthDependencies`'s plain constructor-injected pattern)
- [x] `lib/features/lesson/state/lesson_controller.dart` - `LessonController` (`InLessonState`): current exercise index, local beans, answer/feedback state, check/continue/resume-after-refill
- [x] `lib/features/lesson/widgets/choice_tile.dart` - the "Choice & Match Tile" component (default/selected/correct/incorrect, shake animation)
- [x] `lib/features/lesson/widgets/word_bank_builder.dart` - sentence-construction's tap-to-build word bank + built-answer tray
- [x] `lib/features/lesson/widgets/lesson_hud.dart` - the streak/beans/XP HUD pills
- [x] `lib/features/lesson/widgets/skill_path_node.dart` - the locked/active/completed path node, with crown-level badge
- [x] `lib/features/lesson/widgets/out_of_beans_sheet.dart` - story 003's modal content
- [x] `lib/features/lesson/widgets/level_up_sheet.dart` - story 004's crown-level-up/streak-freeze modal content
- [x] `lib/features/lesson/screens/skill_tree_dashboard_screen.dart` - story 001: fetches and renders the skill tree, error+retry, starts a lesson, reloads on return
- [x] `lib/features/lesson/screens/lesson_screen.dart` - story 002 (+ triggers story 003): hosts all 3 exercise types against one fetched `LessonContent`, shows the out-of-beans modal the instant beans hit 0, hands off to the summary on completion
- [x] `lib/features/lesson/screens/lesson_complete_screen.dart` - story 004: XP/streak/accuracy/daily-goal summary, plus the level-up modal when applicable
- [x] `lib/features/auth/auth_routes.dart` - `AuthRoutes.build` now takes a `homeBuilder` parameter instead of hardcoding `HomePlaceholderScreen`
- [x] `lib/main.dart` - constructs `LessonDependencies` and supplies the dashboard as the `home` route's builder
- [x] `pubspec.yaml` - adds `audioplayers` (listening-exercise playback), used only behind `LessonAudioPlayer`

### Key Decisions

- **Client-side answer grading**: each `Exercise` carries its own correct answer so `LessonController.check()` grades locally with zero network round trips, satisfying the "no per-exercise call" NFR without a real backend contract to defer to yet. Flagged explicitly in `implementation-plan.md`'s Checkpoint Decisions as an open item for `001-lesson-service`'s Technical Design.
- **`FakeLessonApi` owns account-level state** (skill nodes, beans, streak, Amole, XP), not just `LessonController` — otherwise the dashboard could never show a completed lesson's effect on node state/crown level without a real backend.
- **Single "Check" then "Continue" interaction model** across all 3 exercise types, instead of an immediate-submit-and-auto-advance model — makes every state transition explicit and deterministically testable, and keeps the incorrect/correct tile state visible until the learner acknowledges it (matching the design's tile states being a distinct visual moment, not a flash).
- **The whole skill-path node (icon + label) is one tap target**, not just the icon circle — found during Stage 3 testing that a smaller tap target didn't match how a learner would naturally tap the node (see Deviations).
- **Out-of-beans/level-up are `showModalBottomSheet` overlays, not routes** — keeps the underlying `LessonScreen`/`LessonCompleteScreen` in the widget tree, so "dismiss without refilling" is a plain double-pop (close sheet, then pop the lesson) rather than needing route-result plumbing.

### Deviations from Plan

- **Out-of-beans refill countdown renders once at build time, not as a live ticking `Timer`** — already flagged in the plan's Checkpoint Decisions; confirmed during implementation as the right call (a `Timer.periodic` would also have made widget tests need to fake-clock or risk pending-timer failures).
- **`SkillPathNode`'s tap target was widened to the whole node (icon + label), not just the icon**, discovered while writing the dashboard's navigation test: tapping the node's title label (a very natural interaction) originally did nothing, since only the icon `Container` sat inside the `InkWell`. Fixed by wrapping the whole node in one `InkWell`/`Semantics` region — this is a real UX improvement over the original layout, not just a test workaround.
- **The lesson screen's "hide stale content while the modal/summary takes over" placeholder is an empty `SizedBox`, not a loading spinner** — an indeterminate `CircularProgressIndicator` runs a non-terminating animation, which is fine visually but meant `pumpAndSettle()` could never settle for as long as the out-of-beans modal or the completion hand-off was in flight. Caught in Stage 3; fixed in the same file.
- **No dedicated Stitch export existed for the lesson-exercise screen** (already flagged in the plan) — built directly from `DESIGN.md`'s "Choice & Match Tiles" spec.

### Dependencies Added

- [x] `audioplayers: ^6.1.0` - listening-exercise audio playback, used only behind `lib/shared/services/lesson_audio_player.dart`'s `LessonAudioPlayer` interface so no screen or test touches the plugin directly

### Developer Notes

- `FakeLessonApi`'s seed curriculum is 4 nodes (2 completed with crown levels 3/2, 1 active, 1 locked) across one unit, with the active node's lesson (`lesson-coffee`) deliberately containing one of each exercise type so the full loop is exercisable end-to-end from the dashboard alone.
- `FakeLessonApi.completeLesson` requires `beansRemainingAtEnd` specifically so the fake's account-level beans balance stays consistent with whatever the client-side `LessonController` decremented during the attempt — this is the one place local and "server" bean state get reconciled.
- Once `001-lesson-service` publishes its real contract, only `lib/shared/services/fake_lesson_api.dart` needs replacing with a real `LessonApi` implementation (bolt 007) — no screen, controller, or widget built against the interface should need to change. The one open question that implementation will need to resolve is whether the real contract ships correct answers to the client at all (see Key Decisions above).
- `test/helpers/controllable_lesson_api.dart` and `test/helpers/fake_lesson_audio_player.dart` are the new test doubles (network/plugin-boundary mocks only, per `coding-standards.md`), alongside the existing `FakeLessonApi` itself (used directly, with `latency: Duration.zero`, wherever the seed data's exact shape is what's under test).
- `test/shared/services/http_auth_api_e2e_test.dart` (a pre-existing file from `003-auth-onboarding-ui`, unrelated to this bolt) was missing an `@Tags(['e2e'])` annotation, so `flutter test test/ --exclude-tags=e2e` was running it anyway and failing on connection-refused errors (no local backend running). Added the one-line tag so the exclude flag does what its name says; no other change to that file.
