---
stage: test
bolt: 045-lesson-screen-on-kit
created: '2026-09-24T21:19:36Z'
---

## Test Report: question-kit-ui (lesson screen on the kit)

### Summary

- **Tests:** 825 of 832 pass.
  - This bolt adds 56 tests, all passing: 26 for the lesson on the kit,
    and 30 that port the old gap test's full range of widths and text
    sizes to the kit's gap.
  - The 7 failures are the same end-to-end tests in
    `test/shared/services/http_auth_api_e2e_test.dart` as before this bolt.
    They need a backend on `localhost:8000`.
  - From 809 before the bolt: 40 tests went with the deleted
    `GapSentence`, and 56 were added.
- **Coverage:** not measured.
- **Mutation check:** 33 deliberate breakages of the lesson screen, its
  builders and the kit change, run against the lesson screen, kit, exit and
  review tests.
  - The first run caught 32. The miss was closed with a new check, and now
    all 33 are caught.
  - Each file was checked to be restored exactly after its run.
- **`flutter analyze`:** the same 13 existing infos, none in changed files.

### Test Files

- [x] **`test/features/lesson/screens/lesson_screen_kit_test.dart` (26, new)**
  - **One frame:**
    - In one lesson with all five types, the top bar, the prompt's place,
      the action bar and the first answer's left edge are identical for
      every type.
    - The top bar shows progress (1 of 3, then 2 of 3) and the beans left,
      which drop by one on a wrong answer.
    - Choice rows are 12 px apart.
  - **Prompts:**
    - A bare word with a gloss asks the gloss and shows the word.
    - "Complete the sentence: 'I want water'" is split into two lines.
    - The backend's "How do you say 'Hello' in Amharic?" is one headline.
  - **Per type:**
    - **Gap fill:** the chosen word fills the gap in the grade colour. Only
      the chosen tile shows the grade, and no tile takes a tap once graded.
    - **Sentence:**
      - Check is disabled until a word is placed.
      - A placed word sits on the answer line, and its bank tile is dimmed.
      - Once checked, the placed words and the line take the grade and are
        locked.
    - **Match pairs:**
      - Side-by-side tiles are the same height (Fidel beside Latin, at 1.3×).
      - Armed is selected, a wrong pair is incorrect and then idle again,
        and a right pair is locked correct.
  - **No overflow:** every type, before and after answering, at 320 and
    360 px, at 1.0× and 1.3× text.
  - **Audio plays by itself:**
    - It plays once when a listening question appears. An answer or a
      rebuild doesn't replay it; the button does.
    - It plays when a listening question comes next, and again when a
      missed one comes back. The mistake review itself plays nothing.
    - Questions without audio play nothing.
    - After an out-of-beans refill, the answered question doesn't play
      again.
    - The button shows "playing" until the clip has started. With two quick
      taps it stays on until the second has started.
    - A clip that fails to play throws nothing, and play can be tapped
      again.
  - **Continue:**
    - A double tap on the last question saves the lesson once, even while
      the save is still in flight.
    - A double tap mid-lesson moves on one question.
  - **Other pages:**
    - Loading is `LoadingState` on `AppPage`, with the close button.
    - A failed load is `ErrorState`, and Try again then loads the lesson.
    - Offline without a download is `EmptyState` with Go back.
    - The mistake review is a `SheetHero` with the "1 mistake" badge. Its
      top bar and Continue sit exactly where a question's do.
- [x] **`test/shared/widgets/exercise/answer_slot_line_test.dart` (+30)**:
  the gap at 1.0×, 1.15×, 1.3×, 1.5× and 2.0×, on 320, 360 and 412 px, in
  Fidel and in Latin. This is the full range the deleted `GapSentence`
  test ran.
- [x] **`test/shared/widgets/exercise/answer_action_bar_test.dart`**: the
  held space also has no "Check" text in it.
- [x] **`test/features/lesson/screens/lesson_screen_test.dart`**: passes,
  with the three changes described at Implement:
  - `_gapTile` finds the new tile type.
  - The listening test expects the first play.
  - The mistake badge reads "2 mistakes".
- [x] **Unchanged and passing:** `lesson_exit_test`,
  `lesson_screen_cache_test` and `review_mode_test`, and
  `prompt_parts_test` (moved).
- [x] **`test/design/design_rules_test.dart`:** passing, with the allow-list
  at 53 entries.

### Acceptance Criteria Validation

- ✅ **All five types are built only from the kit.** The frame test finds `ExerciseLayout`, `QuestionPrompt`, `AnswerTile` and `AnswerActionBar` in every type. The old widgets no longer exist.
- ✅ **The same top bar, prompt, margins, tile spacing and action bar position.** The frame test compares every type against the first; the spacing test checks the 12 px rows.
- ✅ **`ChoiceTile`, `_MatchPairsTileChip`, `_WordChip`, `ExercisePromptHeader` and `GapSentence` are deleted.** The files are gone and nothing imports them. Only two kit test names still mention them, as history.
- ✅ **Mistake review, loading, error and offline use the library.** Covered by the other-pages tests.
- ✅ **Every lesson behaviour test passes**, changed only as listed above.
- ✅ **The lesson exercise widgets are off the allow-list.** `lesson_screen.dart` keeps only `rawSheetOrDialog`, until bolt 048, as agreed at Plan.
- ✅ **A question with audio plays once by itself, and the button replays it.** Covered by the audio tests.

### Issues Found

**Two bugs, found by the new tests and fixed in this stage:**
1. **Try again crashed.** The retry handler updated the screen in a way
   that returns a pending load, which Flutter rejects. The tap threw, and
   the error page stayed. It now starts the load first and then updates the
   screen.
2. **"Playing" could switch off too early.** With two quick taps on play,
   the first clip starting turned "playing" off while the second was still
   loading. The button now stays on until every requested play has started.

**One gap in the tests, found by the mutation check and closed:**
- Letting choice tiles take taps after grading went unnoticed, because
  the controller ignores the extra tap. That tile would have looked
  unfinished. The gap-fill test now checks that no tile takes a tap once
  graded.

### Notes

- **Checked by eye** during Implement: screenshots with the real fonts, at
  400 px and 1.0× text and at 360 px and 1.3×. They cover every type
  unanswered, graded right and wrong, a match pair armed and wrong, the
  built sentence, and the mistake review.
- **Still to check on a phone** (bolt 049): the first play of a clip on a
  real device and on the web, where a browser may block sound that plays
  by itself. A blocked play is ignored, and the button still works.
