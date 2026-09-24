---
stage: plan
bolt: 045-lesson-screen-on-kit
created: '2026-09-24T20:31:26Z'
---

## Implementation Plan: question-kit-ui (lesson screen on the kit)

### Objective

Rebuild the lesson screen and its five question types on the kit from
bolt 044. After this bolt every question has the same top bar, prompt,
margins, tile spacing and action bar. The old tile, chip and prompt widgets
are deleted. Behaviour does not change: grading on tap, the shake, dimmed
used words, match-pair arming, the held action-bar space, the exit prompt
and the out-of-beans flow all work as before.

### Reference designs (FR-11)

- **The five question types:** the references chosen in bolt 044 (DESIGN.md
  component 4, the Duolingo lesson screen and LibreLingo's challenge panel).
  Nothing new is borrowed for them.
- **Mistake review:** no Stitch mockup draws it.
  - **Fetched:** Duolingo opens a mistake review with its mascot and one
    line naming how many mistakes are coming ("You'll review 10 mistakes"),
    then one button to start ([screensdesign.com Duolingo breakdown](https://screensdesign.com/showcase/duolingo-language-lessons)).
  - **Borrowed:** an illustration first, the count as the first thing seen,
    one short line, one action.
  - **Built with:** `SheetHero`'s layout (the out-of-beans and level-up
    mockups), so it looks like the rest of the app's pop-ups. The replay
    icon stands in for mascot art, with the count in a `CountBadge`.
- **Loading, error and offline:** the library's `LoadingState`,
  `ErrorState` and `EmptyState` (NN/g empty-state guidance, chosen in
  bolt 043).

### Deliverables

**`lesson_screen.dart`**
- **Page:** `AppPage` replaces the `Scaffold`.
- **Every question:** `ExerciseLayout`, with:
  - **Top bar:** `ExerciseTopBar`. Close calls `Navigator.maybePop`, so the
    `PopScope` exit prompt still asks. The progress value is unchanged. The
    beans pill shows only when `usesBeans` (not in practice or review).
  - **Prompt:** `QuestionPrompt`, filled per type as below.
  - **Action bar:** `AnswerActionBar`. `TileFeedback` maps to `AnswerGrade`.
    Check shows only for a built sentence, and is enabled once a word is
    placed. Other types hold its space, as today. The "Couldn't save your
    progress" line becomes its `notice`.
- **Prompts, per type:**
  - **Multiple choice:** `splitPrompt(prompt)`. When the prompt is a bare
    word with a gloss (the fake's "ቡና" / "What does this word mean?"), the
    gloss is the instruction and the word is the question. The backend's
    "How do you say 'Hello' in Amharic?" stays one headline.
  - **Listening:** the instruction as the headline, then the large
    `AudioPlayButton`, centred, with today's "Tap to play/replay" line under
    it.
  - **Sentence:** today's `_translatePrompt` rule, unchanged.
  - **Match pairs and gap fill:** `splitPrompt(prompt)`.
- **Answers, per type:**
  - **Multiple choice, listening, gap fill:** `AnswerTile` rows, 12 px apart, as today and in the gallery.
    Only the chosen tile shows correct or incorrect, as today. Tiles stop
    taking taps once graded.
  - **Gap fill:** `AnswerSlotLine.gap` above the rows, taking the grade.
- **Listening's playing state:** the button shows "playing" from the tap
  until `LessonAudioPlayer.play` returns, so a slow clip still answers the
  tap. `LessonAudioPlayer` does not change.
- **Mistake review:** the same top bar as the questions, then `SheetHero`
  (replay icon, tertiary tone, the count badge, "Let's review your
  mistakes" and today's body line), with Continue docked where Check and
  Continue always sit.
- **Loading:** `LoadingState(message: 'Loading lesson')`.
- **Error:** `ErrorState`, titled "Couldn't load this lesson.", with a "Try
  again" button that loads again. A close button in the top bar leaves.
- **Offline, not downloaded:** `EmptyState` ("You're offline", today's
  message), with a "Go back" `AppButton`.

**`word_bank_builder.dart`**
- The built sentence is `AnswerSlotLine.sentence`, with the placed words as
  pill `AnswerTile`s that take the grade once checked.
- The bank is pill `AnswerTile`s: `used` once placed, idle otherwise, and
  not tappable once checked.
- `_WordChip` is deleted.

**`match_pairs_builder.dart`**
- Cell `AnswerTile`s. The states map as follows:
  - armed → selected
  - matched → correct (locked)
  - wrong pair → incorrect, which shakes
- `_MatchPairsTileChip` and `_ChipStyle` are deleted.

**Removed**
- `choice_tile.dart`: `ChoiceTile` is deleted.
- `gap_sentence.dart`: deleted, with its tests. `answer_slot_line_test`
  already repeats every one of them (bolt 044).
- `exercise_prompt_header.dart`: `ExercisePromptHeader` is deleted.
  `splitPrompt` and `PromptParts` move unchanged to
  `lib/features/lesson/prompt_parts.dart`. Their test moves to
  `prompt_parts_test.dart`, unchanged.

**Rules allow-list:** from 64 file-and-rule entries to 53.
- Removed completely: `choice_tile.dart`, `match_pairs_builder.dart` and
  `word_bank_builder.dart`.
- `lesson_screen.dart` keeps only `rawSheetOrDialog`, for the exit and
  out-of-beans sheets. Bolt 048 moves those sheets to `showAppSheet` and
  `SheetHero` (unit 003, story 003). Moving them now would double the
  sheets' padding and restyle half a sheet ahead of its story.

### Dependencies

- **Bolt 044's kit:** everything is built from it. Nothing is added to the
  kit.
- **`LessonController`:** read only. No change to its state or grading.
- **Library widgets:** `AppPage`, `SheetHero`, `CountBadge`, `AppButton`,
  `LoadingState`, `ErrorState` and `EmptyState`, all from bolts 042–043.

### Technical Approach

- **The one frame:** a single `_QuestionFrame` in `lesson_screen.dart`
  builds `ExerciseLayout` for every type. Each type only supplies its
  prompt and answers, so the frame cannot drift between types.
- **Mapping:** one function turns `TileFeedback` into `AnswerGrade?`, and
  one turns "selected, checked, feedback" into `AnswerTileState`. Every
  type uses them.
- **Tests:** they change only where they found a replaced type.
  - `_gapTile` finds `AnswerTile` instead of `ChoiceTile`.
  - The exercise-prompt test is renamed to the new file.
  - Every other lesson test (the screen, exit, cache and review) runs
    unchanged. Their text, icon and tooltip finders already match the kit.
- **New tests, in `lesson_screen_test.dart`:**
  - All five types use the same frame: the same top bar, margins, prompt
    gap and action bar position.
  - A double tap on Continue advances once.
  - Close asks before leaving mid-lesson (already in `lesson_exit_test`;
    re-run, not duplicated).
  - The listening button shows "playing" until the clip starts.
  - The mistake review, loading, error (with Try again) and offline states.
  - No overflow at 320 and 360 px, at 1.0× and 1.3× text, for each type.
- **Checked by eye:** a screenshot of each type before and after, as in
  bolt 044.

### Acceptance Criteria

- [ ] All five types are built only from `ExerciseLayout`, `QuestionPrompt`, `AnswerTile`, `AudioPlayButton`, `AnswerSlotLine` and `AnswerActionBar`
- [ ] Side by side, the five types have the same top bar, prompt style, margins, tile spacing and action bar position
- [ ] `ChoiceTile`, `_MatchPairsTileChip`, `_WordChip`, `ExercisePromptHeader` and `GapSentence` are deleted, and nothing refers to them
- [ ] The mistake review uses `SheetHero`'s layout; loading, error and offline use `LoadingState`, `ErrorState` and `EmptyState`
- [ ] Every lesson behaviour test passes, changed only where it found a replaced type
- [ ] The lesson exercise widgets are off the allow-list; `lesson_screen.dart` keeps only `rawSheetOrDialog`, until bolt 048
- [ ] A question with audio plays it once by itself when it appears; the button replays it
- [ ] `flutter analyze` shows the same 13 infos, and the suite passes apart from the 7 end-to-end tests that need a backend

### Checkpoint Decisions (2026-09-24)

- **Approved as written**, including both decisions: `lesson_screen.dart`
  keeps `rawSheetOrDialog` until bolt 048, and a bare-word multiple-choice
  prompt takes the standard question size.
- **Added: audio plays by itself.** A question with audio plays its clip
  once when it first appears on screen, and again when a missed question
  comes back. The play button replays it. A rebuild, a tap on an answer or
  the grade never replays it.
  - Today only listening questions carry audio. The rule is written for
    any question with audio, so the planned audio-and-picture type gets it
    too.
  - A clip that fails to play is ignored; the learner can still tap play.
  - The existing listening test asserted that nothing plays until the tap.
    It changes to expect the automatic play, then a replay on each tap.
- **Image question types:** set up as intent 019 after this bolt.

### Not in this bolt

- **The image question types** (read the question and pick a picture;
  hear a clip and pick a picture). They need new content types on the
  backend, image storage, admin editors, offline pack images and an image
  tile in the kit. They are proposed as a new intent, planned after this
  bolt so they build on the finished lesson screen.
- The spell-from-tiles screen (bolt 033) and the lesson sheets (bolt 048).
