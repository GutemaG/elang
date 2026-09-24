---
stage: test
bolt: 044-question-kit
created: '2026-09-24T20:22:30Z'
---

## Test Report: question-kit-ui

### Summary

- **Tests**: 809 of 816 pass.
  - This bolt adds 93 tests, all passing: 91 for the kit and 2 in the gallery test.
  - The 7 failures are the same end-to-end tests in `test/shared/services/http_auth_api_e2e_test.dart` that failed before this bolt. They need a backend on `localhost:8000`, and nothing was running there.
- **Coverage**: not measured.
- **Mutation check**: 49 deliberate breakages of the kit, each run against its own tests.
  - After the tests were strengthened, 48 are caught.
  - The one miss changes nothing a learner could see; see Issues Found.
  - Each file was checked to be restored exactly after its run.
- **`flutter analyze`**: the same 13 existing infos as before the bolt, none in new files.

### Test Files

- [x] **`test/shared/widgets/exercise/answer_tile_test.dart` (35)**
  - **States:** each state's face, border, rim and text colour is checked against DESIGN.md component 4. Idle is exactly the design-system tile. Used dims the whole tile. Disabled fades its text and ignores taps.
  - **Grading:** correct shows a green check and incorrect a red cross. Colours ease between states over `AppMotion.state`.
  - **Shapes:**
    - Rows and cells fill the width, even in a loose parent.
    - A row's face is 56 px, with the label 16 px inside the border.
    - A cell centres its label.
    - A pill hugs its label and is fully rounded.
  - **Pill height:** every pill is the same height, Latin or Fidel. It matches `pillHeightOf` at 1.0×, 1.3× and 2.0×, and stays at 48 px with small text.
  - **Graded pills:** grading shows only a colour change, so the pill's width doesn't change. An over-long word shrinks into its pill.
  - **Interaction:**
    - A tap calls `onTap` once, and the face sinks onto its shelf.
    - With `onTap` null, an idle, selected or correct tile doesn't press.
    - An idle tile that can't be tapped fades, but a graded tile keeps its colour.
  - **Shake:**
    - It swings at most 8 px, stops within `AppMotion.shake` and never moves the layout.
    - Match-pair cells shake too.
    - With reduced motion there is no shake, but the colour still changes.
    - A tile first built already wrong shakes once. Selected and correct never shake.
  - **Screen readers:** one button node, with the label and the selected flag. A screen-reader tap works, and the icons aren't read.
  - **Text scale:** a long Fidel label at 1.3× on 320 px, in every shape: no overflow, and it gets the Ethiopic line height.
- [x] **`test/shared/widgets/exercise/exercise_layout_test.dart` (19)**
  - **`ExerciseLayout`:**
    - It uses `AppPage`, with the top bar and the docked bar.
    - There are 24 px between the prompt and the answers, and 20 px margins.
    - The action bar is pinned 24 px from the bottom, and doesn't move with the number of answers.
    - At 360×640 and 1.3× text, a finger drag reaches the last answer, and the bar stays put.
  - **Top bar:**
    - "Exit lesson" calls `onClose` once, and its face lines up with the 20 px margin.
    - It shows the progress value and the beans pill, "3 of 5". With no beans there is no pill, and the bar fills the space.
    - It is the same height as `AppTopBar`, and fits 320 px at 1.3×.
  - **`QuestionPrompt`:**
    - **Styles:** the instruction is `label-lg` muted. The question is bold `headline-md`, 4 px below the instruction. With no question, the instruction becomes the headline.
    - **Heading:** only the headline is read as a heading.
    - **Order:** the pronunciation (in the phonetic style) comes before the translation, each 4 px apart.
    - **Speaker chip:** small, at the start of the question, and it plays when tapped. It only appears when asked for.
    - **Fidel:** it gets the Ethiopic line height. A long Fidel question at 1.3× on 320 px wraps without clipping.
- [x] **`test/shared/widgets/exercise/audio_play_button_test.dart` (8)**
  - **Large:** an 88 px green face on a green shelf, with a white speaker icon.
  - **Press:** a tap plays once, and the face sinks by the shelf depth and comes back.
  - **Playing:** sound waves and a halo, with no animation running.
  - **Small:** a 44 px face, with a tap target of at least 48 px each way.
  - **Disabled:** faded and inert.
  - **Screen readers:** "Play audio" or "Playing audio", with a working screen-reader tap and an optional custom label.
- [x] **`test/shared/widgets/exercise/answer_slot_line_test.dart` (17)**
  - **Sentence:**
    - When empty, it holds two lines, with the muted hint above the first rule.
    - Each rule runs 4 px under a row of pills.
    - Adding words on one line keeps its height. Wrapping adds exactly one line, and the rules match the rows.
    - The rules are grey, then green or terracotta after grading.
    - A placed word can be tapped out.
    - Fidel at 1.3× fits.
  - **Gap:** this repeats every `GapSentence` test on the new widget.
    - The words either side, an empty or a filled gap, and a gap at either end.
    - The width never changes when a word is filled or changed.
    - The line and the word take the grade colour.
    - The Ethiopic line height.
    - No overflow at 320 or 360 px, at 1.0× or 1.3×, and a long sentence wraps.
    - A screen reader hears "blank" or "blank, filled with …".
- [x] **`test/shared/widgets/exercise/answer_action_bar_test.dart` (12)**
  - **Before grading:** Check is a primary button, disabled until `canCheck`. Without Check, the same height is kept, empty, hidden from screen readers and not tappable. There is no panel.
  - **Right:** "Correct!" in green on mint, with a check badge, above a primary Continue.
  - **Wrong:** "Not quite" in terracotta on blush, with a cross badge, above a destructive Continue.
  - **Panel motion:** it grows over `AppMotion.feedback`, then stops. With reduced motion it is there at once.
  - **Screen readers:** the result is announced as a live region.
  - **Continue:** one tap calls `onContinue` once, and the bar returns to Check.
  - **Grade:** a new grade replaces the panel.
  - **Notice:** it sits between the panel and the button, in terracotta.
  - **Fit:** every state fits 320 px at 1.3×.
- [x] **`test/design/component_gallery_test.dart` (+2)**, at 360×640 with 1.3× text:
  - The question demo grades a tapped answer, and Continue resets it.
  - The sentence demo builds "I want coffee" from the word bank and checks it as right.
  - The existing whole-gallery tests also lay out the new section at both phone sizes and both text scales.
- [x] **`test/design/design_rules_test.dart`**: unchanged and passing. The allow-list is still 64 entries.
- [x] **`test/features/lesson/widgets/exercise_prompt_header_test.dart`**: unchanged and passing, so `splitPrompt` keeps its behaviour.

### Acceptance Criteria Validation

**Story 001: frame and prompt**
- ✅ **`ExerciseLayout` has the top bar, the prompt, scrolling answers and the docked bar, on `AppPage`.** Tested in `exercise_layout_test`.
- ✅ **The instruction is a muted line and the question large and bold; without a question, the instruction is the headline.** Tested in `exercise_layout_test`.
- ✅ **The translation, speaker chip and pronunciation each have a fixed place, and the pronunciation is muted `body-sm` 500.** Tested in `exercise_layout_test`.
- ✅ **`splitPrompt` is unchanged.** Its tests pass untouched.
- ✅ **A long Fidel question wraps, and nothing is clipped.** Tested in `exercise_layout_test`.
- ✅ **The gallery shows the layout and every prompt variant, in Latin and Fidel.** Covered by the gallery, the gallery tests and the screenshots.

**Story 002: answer tile**
- ✅ **The six states match component 4, using tokens only.** Tested in `answer_tile_test`. The rules test's colour rule covers the tokens.
- ✅ **Row, pill and cell shapes.** Tested in `answer_tile_test`.
- ✅ **A check or cross appears, and one shake within `AppMotion.shake`, with none under reduced motion.** Tested in `answer_tile_test`. A pill shows its grade by colour, as agreed at Implement.
- ✅ **With `onTap` null, taps do nothing and the tile shows it.** Tested in `answer_tile_test`.
- ✅ **A screen reader reads the label, with the button and selected flags.** Tested in `answer_tile_test`.
- ✅ **A Fidel label at 1.3× grows and never clips.** Tested in `answer_tile_test`.
- ✅ **The gallery shows every state in every shape.** Covered by the gallery.

**Story 003: audio, answer line and action bar**
- ✅ **The round tactile play button, with a shelf, a press and a playing state, calls `onPressed`.** Tested in `audio_play_button_test`.
- ✅ **The ruled lines with placed pills, and the gap keeps `GapSentence`'s behaviour.** Tested in `answer_slot_line_test`.
- ✅ **Before grading, Check is disabled until there is an answer; otherwise its space is held.** Tested in `answer_action_bar_test`.
- ✅ **After grading, the panel sits above Continue in the matching variant.** Tested in `answer_action_bar_test`.
- ✅ **The panel comes only from the grade it is given.** Tested in `answer_action_bar_test`.
- ✅ **One tap on Continue calls `onContinue` once.** Tested in `answer_action_bar_test`. The controller's guard against a double tap is unchanged, and bolt 045 tests it through the lesson.

**Whole bolt**
- ✅ **The gallery shows every piece and state with no overflow**, at 360×640 and 430×932, at 1.0× and 1.3× text.
- ✅ **The rules test passes, with the allow-list at 64 entries.**
- ✅ **`flutter analyze` is unchanged, and the suite passes** apart from the 7 end-to-end tests that need a backend.

### Issues Found

**Two sizing bugs in the kit, fixed in this stage.** Both appeared only in a parent with a fixed height, such as a sheet or a test host. They were hidden in the scrolling lesson page.
1. **The empty answer line stretched to fill all the height it was offered.** Its content alignment filled the space. It now takes exactly its own height.
2. **The play button did the same,** because of how it centres its face in the 48 px tap target. It now keeps its own height.

**Four gaps in the tests, found by the mutation check and closed:**
- **Shake distance:** the limit was checked against the kit's own constant, so a bigger shake still passed. It is now checked against 8 px.
- **Pill tap target:** the 48 px minimum only matters with small text. It is now tested at 0.7×.
- **Loose parents:** rows and cells are now also tested in a loose parent.
- **Prompt gap:** the 24 px gap was checked against the kit's own constant. It is now checked against 24.

**One breakage is not caught, and doesn't need to be.** Removing the row's explicit full width changes nothing, because the row's own label already fills the width. This is an equivalent change, not a missing test.

**Test mistakes, corrected:**
- A drag started on an answer that had already scrolled off screen.
- A paint colour was compared without converting it to the same 32-bit form.
- A wrapped sentence was taller than the test screen.
- A baseline was checked to a tenth of a pixel.
- Gallery taps went to the same word elsewhere on the page; they are now scoped to their demo.

### Notes

- **Checked by eye:** the section was rendered with the real fonts at 400 px and 1.0× text, at 360 px and 1.3× text, and after grading. The throwaway test used for this is not in the repo.
- **Still to check on a phone** (bolt 049): the shake and the panel's slide at real frame rates.
- **Bolt 045** moves the lesson onto the kit. It will then test the lesson's exit prompt, its handling of a double tap on Continue, and the playing state while a clip loads.
