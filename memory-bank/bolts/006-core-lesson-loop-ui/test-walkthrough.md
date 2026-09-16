---
stage: test
bolt: 006-core-lesson-loop-ui
created: 2026-09-16T11:00:00Z
---

## Test Report: Core Lesson Loop UI

### Summary

- **Tests**: 64/64 passed (`flutter test test/ --exclude-tags=e2e`), 0 failures, 0 skipped
- **Analyzer**: `flutter analyze` — No issues found
- **Coverage**: Not measured via `flutter test --coverage` (no coverage tooling configured in this project, consistent with `002-auth-onboarding-ui`'s prior test report). Scope is smoke/interaction-level per `coding-standards.md`'s "UI screens get smoke/widget-level coverage" guidance for UI, plus direct unit coverage of `FakeLessonApi`'s account-state logic (crown level/streak/skill-unlock), which is closer to the ledger-style logic `coding-standards.md` asks for fuller coverage on.

### Test Files

- [x] `test/features/lesson/screens/skill_tree_dashboard_screen_test.dart` - locked/active/completed nodes render with crown badges; locked nodes aren't tappable; tapping the active node starts a lesson; fetch failure shows inline error + retry and recovers; returning from a completed lesson reloads the dashboard with updated node state
- [x] `test/features/lesson/screens/lesson_screen_test.dart` - correct/incorrect multiple-choice feedback + bean decrement; listening tap-to-play/replay; sentence-construction word-bank build + grade; local beans hitting 0 immediately shows the out-of-beans modal (no Continue button); Amole refill resumes the lesson; dismissing without refilling returns to the caller with zero `completeLesson` calls; refill disabled when Amole is insufficient
- [x] `test/features/lesson/screens/lesson_complete_screen_test.dart` - base summary (XP/streak/accuracy/daily-goal progress) always renders; no empty/broken section when there's no level-up; crown-level-up and streak-freeze-unlock both show the level-up modal with the correct copy before returning to the caller
- [x] `test/shared/services/fake_lesson_api_test.dart` - unit tests for `FakeLessonApi`'s account-state logic: first completion unlocks the next node; replay increments crown level (capped at 5, unlocking a streak freeze at 5); streak increments at most once per session; `completeLesson`/`refillBeansWithAmole` keep the beans balance in sync
- [x] `test/helpers/controllable_lesson_api.dart` - manual-control `LessonApi` test double (network-boundary mock) used wherever `FakeLessonApi`'s seed timing/data isn't precise enough
- [x] `test/helpers/fake_lesson_audio_player.dart` - recording `LessonAudioPlayer` test double (plugin-boundary mock)
- [x] `test/features/auth/splash_screen_test.dart` - updated (not new): the "valid session" routing assertion now checks for the dashboard's unit-banner text instead of the retired `HomePlaceholderScreen` copy, since `AuthRoutes.home` now points at `SkillTreeDashboardScreen`
- [x] `test/widget_test.dart` - updated (not new): `BunaApp` now also takes a `LessonDependencies` bag

### Acceptance Criteria Validation

- ✅ **Dashboard is the `resolveStartDestination()`/`AuthRoutes.home` target for a valid session**: verified in `splash_screen_test.dart`'s "routes straight to home" test (dashboard content renders, not the old placeholder)
- ✅ **Locked/active/completed nodes are visually distinct, with crown-level badges on completed nodes; locked nodes are not tappable**: verified directly (crown badges "Lv 3"/"Lv 2", lock icon, tapping the locked node is a no-op)
- ✅ **Tapping an active (or completed, for replay) node starts a lesson**: verified for the active node; completed-node replay is exercised by `fake_lesson_api_test.dart`'s crown-level unit tests rather than a second dashboard-tap widget test (same code path, `SkillPathNode`'s `onTap` doesn't distinguish active vs. completed)
- ✅ **A lesson's exercises are all fetched in one request, held in local state, never re-fetched per exercise**: `LessonScreen` calls `startLesson` exactly once in `initState`; grading happens locally against `LessonController`'s in-memory `LessonContent` with no further API calls until `completeLesson` at the very end — confirmed by `ControllableLessonApi.completeLessonCalls` staying empty until the last exercise is answered
- ✅ **All 3 exercise types render and are answerable, with default/selected/correct/incorrect tile states**: verified per-type in `lesson_screen_test.dart`; the shake animation itself is exercised via `ChoiceTile`'s state transition (an `AnimationController` starts on the `selected && incorrect` transition) but its visual motion isn't independently asserted — see Notes
- ✅ **A correct answer advances the lesson; an incorrect answer decrements local beans and never on a correct answer**: verified directly (bean count text drops from 5 to 4 only on the wrong-answer test)
- ✅ **Listening exercises support tap-to-play/replay**: verified — tapping the play icon twice records two `playedUrls` entries on the fake audio player
- ✅ **Local beans hitting 0 immediately interrupts the lesson and shows the out-of-beans modal**: verified — no `Continue` button renders once beans hit 0; the modal shows instead
- ✅ **Out-of-beans modal shows regen timing, offers a disabled-when-unaffordable Amole refill that resumes the lesson, and a dismiss path with no XP for that attempt**: verified — refill resumes at the same exercise with `completeLessonCalls` still empty; "Not now" pops back to the caller with `completeLessonCalls` still empty; refill button shows "Not enough Amole" and is inert when the account can't afford it
- ✅ **Successful completion shows XP earned, progress toward `daily_xp_target`, and the updated streak**: verified in `lesson_complete_screen_test.dart`
- ✅ **A crown-level-up or streak-freeze unlock is reflected; no such change renders no empty/broken section**: verified both branches explicitly
- ✅ **Dismissing the completion summary returns to the dashboard with updated node state**: verified end-to-end in `skill_tree_dashboard_screen_test.dart` (dashboard → lesson → complete → back to dashboard, re-fetching on return)
- ✅ **`flutter analyze` is clean and every new screen/widget has smoke-level widget test coverage**: confirmed — every new screen has a dedicated test file; leaf widgets (`ChoiceTile`, `WordBankBuilder`, `LessonHud`, `SkillPathNode`, `OutOfBeansSheet`, `LevelUpSheet`) are exercised indirectly through the screens that compose them, per `coding-standards.md`'s smoke-level (not exhaustive) UI coverage guidance

### Issues Found

- **`SkillPathNode`'s tap target was too small.** Only the icon circle sat inside the `InkWell`; tapping the node's title label (directly beneath it, and a very natural place to tap) did nothing. Found while writing the dashboard's "tapping the active node starts its lesson" test. **Fixed**: the whole node (crown badge, icon circle, and label) is now one `InkWell`/`Semantics` region. This is a genuine UX fix, not just a test workaround — re-verified with `flutter analyze` (clean) and the full suite.
- **`pumpAndSettle()` timeouts on every out-of-beans/lesson-complete flow test.** `LessonScreen` was hiding stale exercise content behind an indeterminate `CircularProgressIndicator` while the out-of-beans modal or completion hand-off was in flight — an indeterminate spinner runs a non-terminating animation, so `pumpAndSettle()` never saw the frame queue go idle. **Fixed**: replaced with an inert `SizedBox.shrink()`, since that placeholder is only ever visible for a single frame in the real app anyway (the modal/next screen appears immediately on top).
- **Ambiguous `find.text('Continue')` once the level-up modal is showing.** The lesson-complete screen's own `Continue` button stays in the widget tree underneath the modal sheet (bottom sheets overlay rather than replace). Not an app bug — just required the test to target `find.text('Continue').last` (the modal's own button) once both are present.
- **Pre-existing, unrelated to this bolt**: `test/shared/services/http_auth_api_e2e_test.dart` (from `003-auth-onboarding-ui`) had no `@Tags(['e2e'])` annotation despite being explicitly documented in its own file header as requiring a live local backend and being "intentionally excluded from being just another unit test." This meant `flutter test test/ --exclude-tags=e2e` — the exact command specified for this bolt's verification — was running it anyway and failing with connection-refused errors. Added the one-line `@Tags(['e2e'])` annotation so the existing `--exclude-tags=e2e` convention actually works as documented; no other change to that file, and no application code was touched to make this fix.

### Notes

- Per `coding-standards.md`, mocking is confined to the network/plugin boundary: `LessonApi` (`FakeLessonApi` directly, or `ControllableLessonApi` where finer control is needed) and `LessonAudioPlayer` (`FakeLessonAudioPlayer`). `LessonController`, `SkillTreeDashboardScreen`, `LessonScreen`, and `LessonCompleteScreen` all run as real code against those fakes in every test — no domain/state logic is mocked.
- The shake animation on an incorrect tile is a real, driven `AnimationController` (`ChoiceTile`), but no test asserts its intermediate frame positions — only the end-state (incorrect styling + icon) is checked, consistent with this bolt's smoke-level UI coverage scope rather than pixel/frame-level animation testing.
- Completed-node replay (crown-level increment) is proven at the `FakeLessonApi` unit level (`fake_lesson_api_test.dart`), not via a second full dashboard→lesson→complete widget test, since the dashboard/lesson-screen code path for a completed node is identical to the active-node path already covered — only the fake's own bookkeeping differs, which is exactly what the unit tests isolate.
- `flutter test --coverage` was not run (no coverage tooling set up in this project, same gap noted in `002-auth-onboarding-ui`'s test report); "64/64 passed" and `flutter analyze`'s clean result are the two concrete, observed signals reported here.
