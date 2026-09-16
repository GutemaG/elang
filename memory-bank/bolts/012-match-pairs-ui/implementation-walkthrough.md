---
stage: implement
bolt: 012-match-pairs-ui
created: '2026-09-17T06:55:00Z'
---

## Implementation Walkthrough: Match-Pairs UI

### Summary

Added `match_pairs` as a 4th exercise type across the client's model, HTTP-parsing, offline-cache, controller, and screen layers, using the same "build an answer via taps, one atomic Check" model already used by the other 3 exercise types rather than the live per-pair feedback originally sketched at Inception (see `implementation-plan.md`'s Technical Approach for the reasoning).

### Structure Overview

Follows the existing exercise-type extension pattern exactly: the sealed `Exercise` class gets one more subtype, every exhaustive `switch` over it (Dart's compiler enforces this) gets one more case, and the new widget mirrors `WordBankBuilder`'s shape (stateless, controller-driven, tap callback) rather than introducing a new pattern.

### Completed Work

- [x] `lib/shared/models/exercise.dart` — added `MatchPairsTile` (small `{id, text}` value type) and `MatchPairsExercise` (prompt, two tile columns, `correctPairs` map) to the sealed `Exercise` hierarchy; extended `isAnswerCorrect` with a `Map<String, String>` comparison case
- [x] `lib/shared/services/http_lesson_api.dart` — `_toExercise` parses the real `match_pairs` response shape (`left_tiles`/`right_tiles`/`correct_pairs`) into the new model
- [x] `lib/shared/services/lesson_pack_store.dart` — `_exerciseToJson`/`_exerciseFromJson` extended so a `match_pairs` exercise round-trips through the local offline cache; `LessonPackDownloader` needed no changes (it only special-cases `ListeningExercise`, everything else already passes through)
- [x] `lib/features/lesson/state/lesson_controller.dart` — added `armedLeftTileId` (transient UI selection state, not part of the graded answer) and `selectMatchPairsTile` (tap-to-link/unlink, building up the `Map<String, String>` answer); reset alongside the existing answer/feedback state when advancing to the next exercise
- [x] `lib/features/lesson/widgets/match_pairs_builder.dart` (new) — two-column tap-to-link widget; five tile visual states (unselected/armed/linked pre-check, correct/incorrect post-check) reusing this codebase's existing tile color language
- [x] `lib/features/lesson/screens/lesson_screen.dart` — wired `MatchPairsExercise` into the exercise-type `switch`; new `_MatchPairsBody`; `_ActionBar`'s "ready to Check" condition extended (ready once every left tile is linked)
- [x] `lib/shared/services/fake_lesson_api.dart` — added one `match_pairs` demo exercise to the "Coffee & Hospitality" lesson, for local-dev/demo parity with the other 3 types (not a story requirement, low-cost addition)

### Key Decisions

- **Atomic grading, not live per-pair feedback** (see `implementation-plan.md`): reusing the exact model every other exercise type already uses, rather than inventing a new interaction paradigm that exists nowhere else in this codebase.
- **All linked tiles share one uniform post-check color**, not per-pair distinct colors: this app's design system has no established per-item color-coding language, and introducing one for a single exercise type would be inconsistent with everything else. Correct/incorrect is still visually unambiguous — every linked tile turns the same green or red the other exercise types already use for a whole-exercise verdict.
- **`armedLeftTileId` lives on the controller, not in a `StatefulWidget`**: keeps `MatchPairsBuilder` a `StatelessWidget` driven entirely by the controller, matching `WordBankBuilder`'s existing shape rather than introducing a second state-management style for one exercise type.
- **Right-tile taps are ignored with nothing armed**: simplest rule that keeps the mapping unambiguous; tapping a right tile can't accidentally start an orphaned half-pair.

### Deviations from Plan

None — the plan's flagged UX correction (atomic grading vs. live per-pair feedback) was approved at the Stage 1 checkpoint before this stage began, so nothing here is an unplanned deviation.

### Dependencies Added

None.

### Developer Notes

- `MatchPairsTile` needs stable ids (unlike `MultipleChoiceExercise.options`' plain `List<String>`) specifically because the two columns are shuffled independently — worth remembering if a future exercise type is tempted to reuse a plain string list for something similarly two-sided.
- `flutter analyze`: clean except the same 4 pre-existing `prefer_initializing_formals` info-lints present before this bolt (unrelated files, not touched).
- Full existing Flutter test suite (123 tests, including the pre-existing `e2e`-tagged ones) still passes with zero changes needed to any existing test — confirms the sealed-class extension didn't silently break an exhaustive switch anywhere untested.
