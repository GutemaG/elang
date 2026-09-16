---
stage: plan
bolt: 006-core-lesson-loop-ui
created: 2026-09-16T09:00:00Z
---

## Implementation Plan: Core Lesson Loop UI

### Objective

Build the full lesson-loop Flutter screen flow — skill-tree home dashboard, the 3 lesson exercise types with correct/incorrect tile feedback, the out-of-beans/refill interruption, and the lesson-complete/streak/level-up summary — matching the Highland Pulse designs, wired to a documented, swappable `LessonApi` interface backed by a `FakeLessonApi` for this bolt. This becomes the new post-sign-in destination, replacing `HomePlaceholderScreen`. Real backend integration (`001-lesson-service`) is bolt 007, not this bolt.

Covers all 4 stories in this bolt:

- 001-skill-tree-dashboard-screen
- 002-lesson-exercise-screens
- 003-out-of-beans-and-refill-modal
- 004-lesson-complete-streak-and-levelup-modals

### Deliverables

- **Skill-tree dashboard screen** — maps to `4._home_skill_tree_dashboard/`. Top HUD (streak, beans, XP), a scrollable serpentine path of skill nodes (locked / active / completed with crown-level 1-5 badge), locked nodes non-interactive, active/completed nodes tappable into a lesson. Inline error + retry on fetch failure.
- **Lesson exercise screen** — one screen template hosting all 3 exercise types (multiple-choice, listening, sentence-construction) driven by a single `LessonContent` payload fetched once at lesson start and held in a local `LessonController` (the unit brief's `InLessonState`). Tile states (default/selected/correct/incorrect-with-shake) per the "Choice & Match Tiles" component. Listening exercises get a tap-to-play/replay control behind an injectable `LessonAudioPlayer` boundary (not the real audio package directly), so tests never touch a platform channel.
- **Out-of-beans + refill modal** — a modal sheet shown the instant a wrong answer drops local beans to 0, matching `out_of_beans_refill_modal`: refill-with-Amole (disabled when the account can't afford it) and a "Not now" dismiss that returns to the dashboard with no XP awarded for that attempt.
- **Lesson-complete screen + level-up/streak-freeze modal** — maps to `lesson_complete_summary_1/2` (XP earned, streak, accuracy, daily-goal progress) and, when a crown level-up or streak-freeze unlock occurred, an additional `level_up_streak_freeze_modal`-style overlay before returning to the dashboard with refreshed node state.
- **`LessonApi` interface + `FakeLessonApi`** — the documented contract bolt 007 and the real `001-lesson-service` integration will reconcile against (see Technical Approach). Holds enough in-memory mutable state (skill nodes, beans, streak, Amole, daily XP) that the dashboard visibly reflects lesson outcomes.
- **`LessonAudioPlayer` interface + `audioplayers`-backed implementation** — thin playback boundary, mirroring how `AuthApi`/`SecureStorageService` are boundaries the UI depends on through an interface, not a concrete SDK.
- Widget tests for the dashboard, the lesson screen (all 3 exercise types + bean depletion), the out-of-beans modal, and the lesson-complete/level-up screens — written in Stage 3, scoped here.

### Dependencies

- **`001-lesson-service`** (not blocking for this bolt): no real contract exists yet (backend bolts 004/005 are still in progress in this same working tree). `LessonApi` is built as an internal interface/fake exactly like `002-auth-onboarding-ui` treated `AuthApi` before `001-auth-service` existed. Real integration is bolt 007.
- **An audio-playing package** — `audioplayers` (pure-Dart plugin, well-maintained, supports network URLs directly, no extra native setup beyond what Flutter already provides) is added to `pubspec.yaml` in Stage 2, with the same "why this direct dependency" doc-comment convention `google_sign_in_web` used.
- **Stitch "Highland Pulse" exports** — `highland_pulse/DESIGN.md` (values-of-record, already mirrored into `lib/shared/theme/`), `4._home_skill_tree_dashboard/`, `out_of_beans_refill_modal/`, `lesson_complete_summary_1/2/`, `level_up_streak_freeze_modal/`. There is no dedicated Stitch export for the lesson-exercise screen itself — it's built directly from `DESIGN.md`'s "Choice & Match Tiles" component spec (section 4), since no screen export exists to map 1:1.
- **Existing shared code**: `AppColors`/`AppSpacing`/`AppTypography`/`AppTheme`, `TactileButton`, and the "no DI framework, plain constructor-injected dependency bag" pattern from `AuthDependencies`.

### Technical Approach

- **File organization** (per `coding-standards.md`'s `lib/features/lesson/` convention): screens/state/widgets under `lib/features/lesson/`; shared, reusable pieces (models, the `LessonApi`/`FakeLessonApi`/`LessonAudioPlayer` boundary, and any lesson-agnostic widgets) under `lib/shared/`, mirroring exactly how the auth bolt split `lib/features/auth/` vs `lib/shared/`.
- **`LessonApi` contract** (the seam bolt 007 swaps): `getSkillTree()`, `startLesson(lessonId)` (returns all of that lesson's exercises plus the account's current beans in one payload — no per-exercise round trip), `completeLesson(lessonId, correctCount, totalCount, timeSpent, beansRemainingAtEnd)` (awards XP, updates streak/skill-progress/crown level, returns a `LessonCompletionResult`), `getBeansStatus()` and `refillBeansWithAmole()` (for the out-of-beans modal). Answer grading happens **client-side** against the exercise data already fetched at lesson start (each `Exercise` carries its own correct answer) — this is what makes exercise-to-exercise transitions instant per the intent's NFR; a real backend may choose not to ship correct answers to the client for anti-cheat reasons, which is exactly the kind of contract detail bolt 007 / `001-lesson-service`'s Technical Design needs to reconcile, and is flagged explicitly as a known simplification (see Checkpoint Decisions).
- **Domain models** (sealed classes, matching `AuthResult`'s existing pattern): `Exercise` is a sealed class (`MultipleChoiceExercise`, `ListeningExercise`, `SentenceConstructionExercise`); `SkillTreeNode`/`SkillNodeState` (locked/active/completed); `LessonContent`; `LessonCompletionResult`; `BeansStatus`; `RefillResult` (sealed: `RefillSuccess`/`RefillFailure`).
- **`InLessonState` as `LessonController extends ChangeNotifier`**: holds the fetched `LessonContent`, current exercise index, local `beansRemaining`, running correct/wrong counts, and per-exercise answer/feedback state. One tap grades an answer (select-and-submit for multiple-choice/listening; a "Check" button once a sentence is built for sentence-construction); a "Continue" affordance then advances — except when the graded answer was wrong **and** it just brought local beans to 0, in which case the out-of-beans modal is shown immediately instead of a Continue button, per story 003's AC.
- **Bean/XP/streak/crown state lives in `FakeLessonApi`**, not just locally, so the dashboard visibly reflects a completed lesson's effects (node state, crown level, streak, beans) without a real backend. `startLesson` snapshots current beans as `beansAtStart`; `completeLesson` is told `beansRemainingAtEnd` so the fake account's bean balance stays in sync with what happened client-side. An interrupted (out-of-beans, dismissed) attempt never calls `completeLesson`, satisfying "no partial credit."
- **Navigation**: dashboard → lesson is a plain `Navigator.push` (not a named route, since it needs a `lessonId` argument and the project's existing convention is "no routing package" for exactly this kind of small linear flow). Lesson completion uses `pushReplacement` to the lesson-complete screen (so back-navigation can't return into a finished lesson); the level-up/streak-freeze overlay, when applicable, is a modal shown from the lesson-complete screen before its own "Continue" pops back to the dashboard, which reloads the skill tree on return.
- **`AuthRoutes` gets a light touch, not a rewrite**: `AuthRoutes.build` takes an added `required WidgetBuilder homeBuilder` parameter instead of hardcoding `HomePlaceholderScreen` for the `home` route. `main.dart` builds a `LessonDependencies` bag alongside `AuthDependencies` and supplies `homeBuilder: (context) => SkillTreeDashboardScreen(...)`. `splash_screen.dart` and `sign_in_screen.dart` are untouched — they only ever referenced the `AuthRoutes.home` route **name**, never the widget behind it.
- **Audio boundary**: `LessonAudioPlayer` (interface) + `AudioplayersLessonAudioPlayer` (real, `audioplayers`-backed). `LessonScreen` depends only on the interface, exactly like `SecureStorageService`/`AuthApi` — this is what keeps widget tests free of platform-channel calls (mock at the network/DB/plugin boundary only, per `coding-standards.md`).
- **Testing** (scoped in Stage 3, noted now): `flutter_test` widget tests per screen against `FakeLessonApi` and a recording `FakeLessonAudioPlayer`, not against real network/plugins — matching the auth bolt's testing convention exactly.

### Acceptance Criteria

- [ ] Dashboard is the `resolveStartDestination()`/`AuthRoutes.home` target for a valid session, replacing `HomePlaceholderScreen`
- [ ] Locked/active/completed nodes are visually distinct, with crown-level badges on completed nodes; locked nodes are not tappable
- [ ] Tapping an active (or completed, for replay/crown-level) node starts a lesson
- [ ] A lesson's exercises are all fetched in one request at lesson start, held in local state, never re-fetched per exercise
- [ ] All 3 exercise types render and are answerable, with default/selected/correct/incorrect tile states matching the design, including a shake animation on incorrect
- [ ] A correct answer advances the lesson; an incorrect answer decrements local beans and never on a correct answer
- [ ] Listening exercises support tap-to-play/replay before answering
- [ ] Local beans hitting 0 immediately interrupts the lesson and shows the out-of-beans modal instead of accepting further answers
- [ ] The out-of-beans modal shows regen timing, offers an Amole refill (disabled when unaffordable) that lets the lesson resume, and a dismiss path that returns to the dashboard with no XP for that attempt
- [ ] Successful lesson completion shows XP earned, progress toward `daily_xp_target`, and the updated streak
- [ ] A crown-level-up or streak-freeze unlock is reflected (inline or via the level-up modal); no such change renders no empty/broken section
- [ ] Dismissing the completion summary returns to the dashboard with updated node state (locked/active/completed, crown level)
- [ ] `flutter analyze` is clean and every new screen/widget has at least smoke-level widget test coverage

### Checkpoint Decisions (Post-Plan — no human present, decided and documented per the unattended-execution note)

- **Client-side answer grading**: since lesson content is fetched once and exercises must transition instantly (NFR), and `001-lesson-service`'s real contract doesn't exist yet, `FakeLessonApi`'s exercises carry their own correct answers and `LessonController` grades locally. This is called out explicitly as a simplification bolt 007 must reconcile — a real backend may prefer server-side grading per exercise for anti-cheat, which would reintroduce a per-exercise round trip the current NFR forbids, or return content with the answer key included. Not resolved here; flagged for `001-lesson-service`'s Technical Design.
- **No dedicated Stitch export for the lesson-exercise screen**: built directly from `DESIGN.md`'s "Choice & Match Tiles" spec (colors/borders/states) rather than a pixel export, since none exists in `stich-screens/`.
- **Interaction model**: single-tap select-and-grade for multiple-choice/listening; tap-to-build + explicit "Check" for sentence-construction; a "Continue" affordance (not a timed auto-advance) moves to the next exercise after grading, for deterministic, testable state transitions instead of timer-driven UI.
- **Incorrect-then-not-out-of-beans behavior**: an incorrect answer does not repeat the same exercise or requeue it later — it simply advances on "Continue" once acknowledged. Spaced repetition / missed-item review is explicitly out of scope for this intent (SRS is a future intent per `requirements.md`'s constraints).
- **Out-of-beans "Practice for Free Beans" button** (present in the Stitch export) is dropped — it isn't required by any story's acceptance criteria, and its underlying mechanic isn't specified anywhere in this intent's requirements. Only "Refill with Amole" and "Not now" ship.
- **Refill timer is not a live ticking countdown**: the design's export uses a `setInterval`-driven JS countdown; the Flutter modal computes and displays a static "next bean in mm:ss" at build time instead of running a `Timer.periodic`, to avoid pending-timer flakiness in widget tests. Documented as a deviation, not a silently dropped requirement — the AC ("see when beans will regenerate") is still met.
- **Completed nodes are also tappable** (replay, for crown-level progression per FR-6), even though the story's AC only explicitly requires active-node-tap and locked-node-non-interactivity — this is the minimum needed for FR-6 ("Should") to be reachable at all in this bolt's fake-data demo, without it being a new/undocumented flow.
