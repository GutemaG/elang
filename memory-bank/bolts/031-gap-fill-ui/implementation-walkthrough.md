---
stage: implement
bolt: 031-gap-fill-ui
created: '2026-09-20T16:20:00Z'
---

## Implementation Walkthrough: 002-gap-fill-ui

### Summary

Gap-fill now renders and grades in the client. The sentence appears with an underlined gap that the chosen word drops into, the words below it are ordinary choice tiles, and checking is the existing local grading path. `LessonController` was not touched, as the plan required.

### Structure Overview

The type joins the sealed `Exercise` hierarchy, which turns every dispatch site into a compile error until it is handled — the compiler found all three of them before any test ran. The single new widget is the sentence-with-a-gap; everything else reuses what the choice-based exercise types already use. The offline pack store, which the compiler does not check in both directions, was written in both halves at once.

### Completed Work

- [x] `lib/shared/models/exercise.dart` - `GapFillExercise` as a new arm of the sealed class, index-based like multiple choice, and its `isAnswerCorrect` case
- [x] `lib/shared/services/http_lesson_api.dart` - parses the type, converting `correct_choice_id` to an index the same way the other choice-based types do
- [x] `lib/shared/services/lesson_pack_store.dart` - both the serialize map and the deserialize case, with a comment at the seam explaining why these two must move together
- [x] `lib/shared/services/fake_lesson_api.dart` - a gap-fill in the coffee lesson, with the gap in the *middle* of the sentence
- [x] `lib/features/lesson/widgets/gap_sentence.dart` - **new**. The sentence and its gap
- [x] `lib/features/lesson/screens/lesson_screen.dart` - `_GapFillBody`, plus the new arm in the readiness switch
- [x] `lib/features/lesson/screens/skill_tree_dashboard_screen.dart` - removed an unused import (see Deviations)

### Key Decisions

- **`Text.rich` with a `WidgetSpan` for the gap**, as planned, aligned on the alphabetic baseline so the filled word sits on the line rather than floating above it.
- **The gap is sized to the widest option it could ever hold**, measured with a `TextPainter` at the ambient text scale. The sentence therefore does not reflow when a word is chosen or changed — the learner can re-read it without the words moving.
- **The gap has no fixed height.** It takes the line's own height, so a larger text scale grows it with the text instead of clipping. This is the `011` banner lesson applied directly: a structure that cannot overflow beats a predicted height that the test font cannot validate.
- **The fake's gap is in the middle of its sentence**, which none of the seeded content produces — every seeded gap is at the start or end. The fake is the only place those shapes get exercised, so it should not just mirror the seed.
- **Tapping the chosen word again keeps it chosen.** `selectOption` is idempotent, so this is what falls out naturally; emptying the gap instead would disable Check with no visible cause.

### Deviations from Plan

1. **One out-of-scope line changed.** `flutter analyze` reported a single warning across the project — an unused `language_names.dart` import in `skill_tree_dashboard_screen.dart`, left behind by bolt 029 when the course badge moved that call into its own widget. It is unrelated to this bolt. I removed it rather than leave the project's only warning standing, and am flagging it rather than folding it in silently.

2. **A predicted breakage did not happen.** The plan expected Flutter tests or fakes asserting four exercises per lesson to need updating, by analogy with the eleven backend assertions. Adding a fifth exercise to the fake's coffee lesson broke nothing: no client test asserts that count.

### Dependencies Added

None.

### Developer Notes

`lesson_pack_store.dart` is the seam to be careful with. The serialize half is a switch over the sealed class and will not compile if a type is missed; the deserialize half is a switch over a *string* and will only throw at runtime, inside a downloaded pack, offline — the worst place to find out. There is now a comment saying so at the seam itself.

The rendering was smoke-checked during Implement rather than assumed: rendered at 1.0x, 1.3x and 2.0x on 320dp and 360dp, and with an empty `before` side. No exceptions and no overflow; the widget grows from 78px to 384px across that range. That growth is safe because the exercise body already sits inside a `SingleChildScrollView`, so a tall sentence scrolls instead of overflowing. The throwaway test file was deleted; the real tests belong to Stage 3.

`flutter analyze`: 13 issues, all pre-existing `info`-level lints, zero warnings and zero errors. Flutter suite: 422 passing, unchanged.
