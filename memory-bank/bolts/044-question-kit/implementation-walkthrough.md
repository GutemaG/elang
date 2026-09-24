---
stage: implement
bolt: 044-question-kit
created: '2026-09-24T19:49:36Z'
---

## Implementation Walkthrough: question-kit-ui

### Summary

The question kit is built. It has six pieces:
- the frame
- the prompt
- one answer tile with six states and three shapes
- the play button
- the answer line, as ruled lines or a gap
- the action bar, with its feedback panel

All six are in the gallery, with working demos. No screen uses them yet: the lesson moves onto them in bolt 045, so nothing a learner sees has changed.

### Structure Overview

**The kit lives in `lib/shared/widgets/exercise/`**, as agreed at the Plan checkpoint.

**It takes plain values and callbacks,** such as progress, beans, a grade, `onTap` and `onPressed`. It knows nothing about `LessonController` or the audio player. Bolt 045 connects it to the lesson.

**Its own grade type,** `AnswerGrade`, carries the result into the action bar and the answer line.

**The answer tile's colours** come from one table, keyed by state. Its shape sets only the radius, padding and alignment. The tile presses through the shared `TactilePressable`.

### Completed Work

**The kit, in `lib/shared/widgets/exercise/`**
- [x] **`exercise_layout.dart`**
  - **`ExerciseLayout`:** the question frame on `AppPage`. It has the top bar, then the prompt, a 24 px gap and the scrolling answers, with the action bar in the dock.
  - **`ExerciseTopBar`:** close ("Exit lesson"), then the lesson progress bar, then the beans pill. It uses `AppTopBar`'s height and side padding.
  - **`QuestionPrompt`:** the one prompt style.
    - It has an instruction line and the question as a heading.
    - It can also show the speaker chip, a pronunciation line and a translation line.
    - Fidel lines get the extra line height.
- [x] **`answer_tile.dart`**
  - **`AnswerTile`**, with its states and shapes (`AnswerTileState` and `AnswerTileShape`).
  - Colours ease between states.
  - The shake plays once.
  - A tile that can't be tapped doesn't press, and its text fades.
  - A screen reader hears one node: the label, with the button and selected flags.
  - `pillHeightOf` gives the one pill height at the current text scale.
- [x] **`audio_play_button.dart`: `AudioPlayButton`**
  - A round green tactile button, large or small, with a still "playing" look.
  - A screen reader hears "Play audio", or "Playing audio" while playing.
  - The small size keeps a 48 px tap target.
- [x] **`answer_slot_line.dart`: `AnswerSlotLine`**
  - **`.sentence`:** ruled lines that hold at least two rows of pills, with the hint when empty.
  - **`.gap`:** the gap-fill sentence. It keeps `GapSentence`'s fixed gap width and "blank" wording for screen readers, and now colours the filled word by grade.
  - In both forms, the line is warm grey until graded, then green or terracotta.
- [x] **`answer_action_bar.dart`**
  - **`AnswerGrade`:** the result type.
  - **`AnswerActionBar`:**
    - **Before grading:** Check, or its held space.
    - **After grading:** the panel above a green or terracotta Continue.
    - It can show an optional notice line.
  - **`AnswerFeedbackPanel`:** "Correct!" or "Not quite", on mint or blush. It slides up and is announced to screen readers.

**Theme**
- [x] **`lib/shared/theme/app_motion.dart`:** the feedback panel's slide timing.
- [x] **`lib/shared/theme/app_shadows.dart`:** a tile shelf in any rim colour that flattens when pressed, for tiles whose rim changes with their state.

**Gallery**
- [x] **`lib/shared/gallery/gallery_exercise.dart`** (new): the "Question kit" section.
  - A whole question in a phone frame, which grades on tap.
  - Every prompt variant, in Latin, Fidel and Afaan Oromo.
  - Every tile state in every shape, and a tile that shakes when tapped.
  - The play buttons.
  - A sentence to build and check, and a gap to fill, each with its graded looks.
  - Every state of the action bar.
- [x] **`lib/shared/gallery/component_gallery.dart`:** lists the new section.
- [x] **`lib/shared/gallery/gallery_surfaces.dart`:** its phone frame is now public, so the kit's section can reuse it.

### Key Decisions

- **Graded tiles keep full colour** (decision 3). Only an idle or selected tile that can't be tapped fades. So after grading, the unchosen options fade and the chosen one stays bright.
- **Colours ease over `AppMotion.state`,** as `ChoiceTile`'s did, rather than switching in one frame.
- **The shake is only painted.** It never moves the layout, runs once, and is skipped with reduced motion. A tile first built already wrong still shakes once.
- **One pill height.** Every pill is sized for Fidel's taller line, so Latin and Fidel words line up, and the answer line can rule its lines to match exactly.
- **No backend or controller changes.** The panel shows whatever grade it is given.

### Deviations from Plan

- **A pill shows its grade by colour only, with no check or cross.** In the screenshots, an icon on each placed word widened the checked sentence and could push words onto a new line as it was graded.
  - So bolt 045 can colour a checked sentence's words green or red without them moving.
  - Rows and cells still show the icon.
- **The gap's filled word takes the grade colour.** This matches the tiles and the line under it.

### Dependencies Added

None.

### Developer Notes

**Visual check.** The section was rendered with the real fonts at 400 px with 1.0× text, and at 360 px with 1.3× text. It was also rendered after grading. One bug was found and fixed:
- The empty sentence line's hint was stretched to the full held height, so the first rule ran through it.
- The content now sits at the top.

**IPA characters.** Neither bundled font has IPA letters such as "ɨ", so they show as empty boxes in tests. On a device the system font fills them in. The gallery uses plain romanisation.

**Suite.** `flutter analyze` shows the same 13 existing infos. The full suite passes 716 tests, with the same 7 end-to-end failures, which need a backend on `localhost:8000`. The whole-gallery tests already cover the new section at both phone sizes and both text scales.

**The kit's own tests** come in the Test stage.
