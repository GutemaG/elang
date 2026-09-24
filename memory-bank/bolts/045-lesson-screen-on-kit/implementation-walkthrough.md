---
stage: implement
bolt: 045-lesson-screen-on-kit
created: '2026-09-24T21:00:00Z'
---

## Implementation Walkthrough: question-kit-ui (lesson screen on the kit)

### Summary

The lesson screen now builds every question from the kit in one frame. The
old tile, chip, prompt-header and gap-sentence widgets are gone. A question
with audio plays its clip by itself when it appears. The loading, error,
offline and mistake-review screens use the design library. The lesson
controller is untouched.

### Structure Overview

- **`LessonScreen`** decides which page to show:
  - loading, failed or offline: a status page with a close button
  - finished or out of beans: an empty page under the summary or sheet
  - between the questions and the retries: the mistake review
  - otherwise: the current question
- **The question** is one widget for every type. It builds the frame (top
  bar, prompt, answers, action bar) and asks the type only for its prompt
  and its answers.
  - A new question widget starts at every step of the lesson, a retried
    question too. That gives each its own scroll position and its own
    first play of the audio.
- **Two small mappings**, in `answer_states.dart`, turn the controller's
  result into the kit's grade and each choice's look. Every type uses them.
- **The sentence builder and match pairs** stay as their own widgets, now
  drawing kit tiles.

### Completed Work

- [x] `lib/features/lesson/screens/lesson_screen.dart`: rebuilt on `ExerciseLayout`, `QuestionPrompt`, `AnswerTile`, `AudioPlayButton`, `AnswerSlotLine.gap` and `AnswerActionBar`; the status pages on `AppPage` with `LoadingState`, `ErrorState` (with Try again) and `EmptyState`; the mistake review on `SheetHero`; the first play of a question's audio; a guard against a second Continue tap while the first is handled
- [x] `lib/features/lesson/widgets/word_bank_builder.dart`: the built sentence on `AnswerSlotLine.sentence` and the bank as pill tiles; `_WordChip` removed
- [x] `lib/features/lesson/widgets/match_pairs_builder.dart`: cell tiles, laid out a row at a time; `_MatchPairsTileChip` removed
- [x] `lib/features/lesson/widgets/answer_states.dart` (new): the grade and choice-state mappings
- [x] `lib/features/lesson/prompt_parts.dart`: `splitPrompt` and `PromptParts`, moved unchanged from `exercise_prompt_header.dart`
- [x] Removed: `choice_tile.dart`, `gap_sentence.dart` and `exercise_prompt_header.dart` (`ExercisePromptHeader`)
- [x] `lib/shared/widgets/exercise/answer_action_bar.dart`: the held space no longer carries the word "Check"
- [x] `test/design/design_rules_test.dart`: allow-list from 64 file-and-rule entries to 53

### Key Decisions

- **Audio plays by itself** (added at the Plan checkpoint):
  - **When:** once, as a question with a clip appears, including a missed
    question coming back. A rebuild, an answer or the grade never replays
    it. After an out-of-beans refill the question is already answered, so
    it does not play again.
  - **Which questions:** any question with a clip. Today that is only
    listening. The rule is written so the planned audio-and-picture type
    gets it with no extra work.
  - **Failures:** a clip that fails to play is ignored. The learner can
    still tap play.
  - **Playing state:** the button shows "playing" from the tap (or the
    first play) until the clip has started.
- **Match pairs are laid out by rows, not columns.** Kit tiles give Fidel
  its extra line height, so a Fidel tile is taller than a Latin one. As two
  free columns, the rows drifted out of line (seen in the screenshots).
  Each row now holds a pair of equal-height tiles. A screen reader now
  reads left, right, left, right, which is the page's reading order.
- **The held action-bar space has no label.** It used to hold an invisible
  "Check". The lesson tests check that a match-pair or gap-fill question
  never shows Check, and the invisible word was still in the page, so it
  failed them. The kit's test now also checks that the word is absent.
- **The mistake badge reads "1 mistake" or "2 mistakes"**, not a bare
  number. In the library's small badge a lone digit was hard to read.
- **Continue ignores a second tap while the first is handled.** On the
  last question the first tap saves the lesson over the network. A second
  tap in that time used to send the save again. The server ignores a
  repeat, but the offline queue would have taken it twice.
- **"Try again" on a failed load** starts the load again from the top.
  Before, the error had no way out except the back gesture.

### Deviations from Plan

- **Rows 12 px apart**, not 8. That is today's spacing and the gallery's;
  the plan's "8 px" was a slip, corrected in the plan.
- **The match-pair layout** changed from columns to rows, as above.
- **One kit file changed** (`answer_action_bar.dart`), for the held space.

### Dependencies Added

- None.

### Developer Notes

- **Tests changed:**
  - `_gapTile` finds `AnswerTile` instead of `ChoiceTile`.
  - The listening test expects the automatic play, then a replay per tap
    (the new requirement).
  - The mistake-review test finds the badge's "2 mistakes".
  - The prompt test moved with `splitPrompt`, unchanged.
- **`gap_sentence_test.dart` is deleted.** Its 40 tests go down with the
  widget. `answer_slot_line_test` covers each case, but at fewer text
  sizes: 320 and 360 px, at 1.0× and 1.3×. The old test also ran 412 px
  and 1.15×, 1.5× and 2.0×. The Test stage ports that full matrix to the
  gap.
- **Suite:** 769 pass. The 7 failures are the same end-to-end tests that
  need a backend. The drop from 809 is exactly the 40 deleted gap tests.
- **`flutter analyze`:** the same 13 infos.
- **Screenshots, checked by eye** (real fonts; 400 px at 1.0× and 360 px
  at 1.3×): every type unanswered, graded right and wrong, a match pair
  armed and wrong, the built sentence, and the mistake review.
