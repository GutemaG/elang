---
stage: plan
bolt: 044-question-kit
created: '2026-09-24T18:51:40Z'
---

## Implementation Plan: question-kit-ui

### Objective

Build the question kit: one frame, one prompt, one answer tile, one audio
button, one answer line and one action bar. Every question type will be
built from these. Every piece and state appears in the gallery.

**The lesson screen does not change in this bolt.** Bolt 045 rebuilds it on
the kit and deletes `ChoiceTile`, `_MatchPairsTileChip`, `_WordChip` and
`ExercisePromptHeader`. So no screen looks different yet. The rules test's
allow-list stays at 64 entries, and every existing test passes untouched.

### Reference designs (FR-11)

No Stitch mockup draws a lesson screen, so the layout and interaction come
from the references below. Every colour, radius, shelf and font still comes
from Highland Pulse.

- **`highland_pulse/DESIGN.md`, the primary reference**
  - **Component 4, Choice & Match Tiles:**
    - **Default:** white face, 2 px `#E5DDD0` border, 3 px `#D5CCBD` rim.
    - **Selected:** `#FFF7ED` face, 2 px `#E08722` border, 3 px `#C47318` rim.
    - **Correct:** `#E8F8F0` face, 2 px `#1B5E3B` border.
    - **Incorrect:** `#FDF0EE` face, 2 px `#D84A38` border, a soft horizontal shake.
  - **Shapes:** choice tiles have a 20 px radius, and chips are pills.
  - **Component 1:** Check and Continue are primary push buttons. "End lesson" red is the destructive variant.
  - **Typography:** a pronunciation line goes under Fidel in `body-sm` 500 `#786A5E`. Fidel gets 15–20 % extra line height.
- **Duolingo lesson screen**, from two write-ups of its design system: [open-design `duolingo/DESIGN.md`](https://github.com/nexu-io/open-design/blob/main/design-systems/duolingo/DESIGN.md) and [oh-my-design Duolingo](https://oh-my-design.kr/design-systems/duolingo). A [design guide by Blake Crosley](https://blakecrosley.com/guides/design/duolingo) adds the feedback timing.
  - **Borrowed, one action per screen:** a close button, the progress bar and hearts along the top. Then the prompt, then the answers, then one button pinned at the bottom.
  - **Borrowed, answer tiles:** a 2 px border with a thicker bottom lip. The selected state changes both the border and the face. Word-bank tiles are the same tile made into a pill.
  - **Borrowed, before an answer:** Check is disabled until there is something to check, and it keeps its place.
  - **Borrowed, after checking:** a tinted panel slides up at the bottom, over about 200 ms. It is light green with green text for right, or light red with red text for wrong. The button below it becomes Continue in the matching colour.
  - **Borrowed:** the progress bar eases forward (already in `AppProgressBar`).
  - **Not borrowed:** Duolingo's blue "selected" colour. Buna's selected colour stays gold, per DESIGN.md.
  - **Not borrowed:** Duolingo puts the text on the left and the button on the right, in one full-width band. Buna stacks the panel above a full-width Continue. This keeps the same dock as every other page, and the button stays a thumb-sized target at 1.3× text.
- **LibreLingo**, an open-source language app. Studied its source: [`ChallengePanel.svelte`, `ListeningChallenge.svelte` and `ChipsChallenge`](https://github.com/kantord/LibreLingo/tree/lluis-v1.8.1/apps/web/src/components).
  - **Borrowed:** one shared bottom panel for every challenge type. It has three looks (neutral, success and failure), a bold message line and the primary action. This is `AnswerActionBar`.
  - **Borrowed, the listening button:** a large primary button with a speaker icon, placed beside or above the answer area and always replayable.
  - **Borrowed, chip challenge:** the answer row above a separate bank of word chips. Tapping moves a word between the two, which is today's behaviour.
  - **Not borrowed:** autoplay when the question appears, "Skip" and "Can't listen now". These would change behaviour.

### Deliverables

**Where the kit lives: `lib/shared/widgets/exercise/`**

This differs from the bolt's listed folder, `lib/features/lesson/widgets/exercise/`. There are two reasons:
- The rules test lets only `lib/shared/` draw borders, radii and shelves. A tile in `lib/features/` would either break the rules or add allow-list entries, and the list may only shrink.
- The gallery lives in `lib/shared/`. It shouldn't import from a feature.

The kit knows nothing about `LessonController` or `LessonAudioPlayer`. It takes plain values and callbacks, and bolt 045 connects them. `splitPrompt` stays in the lesson feature, unchanged, and its tests too.

**Story 001: frame and prompt** (`exercise_layout.dart`)
- **`ExerciseLayout`**, built on `AppPage`:
  - **Top bar:**
    - a close `AppIconButton` with the tooltip "Exit lesson", which calls `onClose`. The lesson will pass `maybePop`, so its `PopScope` still asks before leaving.
    - `AppProgressBar`
    - a beans `StatPill`, only when beans are given
    - It uses `AppTopBar`'s height and side padding, so it lines up with every other top bar.
  - **Content:** `prompt`, then 24 px, then `answers`, in the scrolling content.
  - **Dock:** `actionBar`.
- **`QuestionPrompt`**
  - **Its fields:** `instruction`, `question`, `translation`, `pronunciation` and `onPlayAudio` (the speaker chip).
  - **With a question:** the instruction is one muted `label-lg` line. The question sits below it in bold `headline-md`, with the speaker chip at its start when given. The translation goes under the question in `body-md` muted, and the pronunciation in `AppTypography.phonetic`.
  - **Without a question:** the instruction alone is the headline.
  - Fidel lines use `AppTypography.forText`, so they get the Ethiopic line height and wrap without clipping.
  - The question is marked as a heading for screen readers.

**Story 002: answer tile** (`answer_tile.dart`)
- **`AnswerTile`**: it takes `label`, `state`, `shape` and `onTap`.
  - **`AnswerTileState`:**
    - **idle:** white face, `tileBorder`, `tileShelf` rim
    - **selected:** `answerSelected` face, `secondaryBrand` border, `activeNodeShelf` rim
    - **correct:** `answerCorrect` face, `primaryContainer` border and text, `primaryBevel` rim, and a check icon
    - **incorrect:** `answerIncorrect` face, `tertiaryBrand` border and text, `tertiaryBevel` rim, a cross icon, and the shake
    - **used:** the whole tile at 35 % opacity, as today's used word-bank chips
    - **disabled:** idle look with text at 60 %, as `ChoiceTile` looks today when it can't be tapped
  - **Graded rims:** DESIGN.md gives no rim for graded tiles. They use the border colour's bevel, as the selected tile does.
  - **`AnswerTileShape`:**
    - **row:** full width, label left, icon right, minimum height 56. For multiple choice, listening and gap fill.
    - **pill:** hugs its label and is fully rounded. It has one fixed height, from the scaled Ethiopic line height, so pills line up on a ruled line. For the word bank and spell tiles.
    - **cell:** fills its column, label centred, minimum height 56. For match pairs.
  - **Press:** through `TactilePressable` with the 3 px tile shelf, the same press as buttons and cards.
  - **With `onTap == null`:** no press and no tap.
  - **Screen readers:** one node: the label, with the button flag and the selected flag. Selected, correct and incorrect all count as selected, as `ChoiceTile` and the match chip do today. The icons are hidden.
  - **Shake:** runs once over `AppMotion.shake` when a tile turns incorrect. It is skipped with reduced motion.

**Story 003: audio, answer line and action bar**
- **`audio_play_button.dart`: `AudioPlayButton`**
  - A round tactile button: `primaryContainer` face, `primaryBevel` shelf, white speaker icon, pressed through `TactilePressable`.
  - **Sizes:** large (88 px, as today's listening button) and small (48 px, the prompt's speaker chip).
  - **`playing` state:** the icon changes to sound waves and a green halo appears. It is static, with no looping animation.
  - **Screen readers:** "Play audio", or "Playing audio" while playing.
  - `onPressed` is the caller's; the lesson will pass today's `audioPlayer.play(url)`.
- **`answer_slot_line.dart`: `AnswerSlotLine`**, in two forms:
  - **`AnswerSlotLine.sentence`:** ruled lines the built sentence's pills sit on.
    - It keeps at least two lines' height, so the page doesn't jump as words are added. It grows by a line when the words wrap.
    - When empty, it shows today's hint, "Tap words below to build your answer".
  - **`AnswerSlotLine.gap`:** the sentence with its gap.
    - It takes over `GapSentence`'s behaviour: one `Text.rich`, a gap as wide as the widest option so the sentence never reflows, and "blank" / "blank, filled with …" for screen readers.
    - `GapSentence` itself stays until bolt 045.
  - **Line colours:** in both forms, the line is `tileShelf` until graded, then green or terracotta. Today's built-sentence tray also changes its border on grading.
- **`answer_action_bar.dart`: `AnswerActionBar`**
  - **Before grading:**
    - With `onCheck` set, it shows Check (`AppButton.primary`), disabled until `canCheck`.
    - Otherwise it holds a Check button's height, empty and hidden from screen readers, so nothing jumps.
  - **After grading (`grade` set):**
    - **Correct:** a panel on the `answerCorrect` face with a `primaryToneBorder` border, a check `IconBadge` and "Correct!" in green `headline-sm`. Continue is `AppButton.primary`.
    - **Incorrect:** the `answerIncorrect` face with a `tertiaryToneBorder` border, a cross badge and "Not quite" in terracotta. Continue is `AppButton.destructive`, today's red Continue.
    - The panel slides up over the new `AppMotion.feedback` (200 ms, from Duolingo). It appears at once with reduced motion.
    - The panel is announced as a live region, so a screen reader hears the result.
  - **`notice`:** an optional terracotta line above the button, for today's "Couldn't save your progress. Tap Continue to try again."
  - **The grade** is a new kit enum, `AnswerGrade` (correct or incorrect). Bolt 045 fills it from `LessonController.feedback`, and nothing is added to the controller.

**Theme**
- **`AppMotion.feedback`** (200 ms, ease-out): the feedback panel's slide.
- **No new colours:** every value above is an existing token.

**Gallery and tests**
- **`lib/shared/gallery/gallery_exercise.dart`** (new):
  - **`ExerciseLayout`:** a framed phone showing a whole question.
  - **`QuestionPrompt`:** every variant, in Latin and in Fidel.
  - **`AnswerTile`:** every state in every shape.
  - **`AudioPlayButton`:** both sizes, at rest and playing.
  - **`AnswerSlotLine`:** empty, filled, and both graded looks, in both forms.
  - **`AnswerActionBar`:** held space, Check disabled, Check enabled, correct, incorrect, and with a notice.
  - Interactive demos are included where state matters: tap tiles to select, build a sentence, fill the gap, and grade.
- **Stage 3 tests,** in `test/shared/widgets/exercise/`: one file per kit file. Plus the gallery checks at 360×640 and 430×932, at 1.0× and 1.3× text.

### Dependencies

- **Bolts 042 and 043** (complete): `AppPage`, `AppTopBar`, `AppIconButton`, `AppButton`, `TactilePressable`, `AppProgressBar`, `StatPill`, `IconBadge`, `AppShadows.tile`, the tile colours and `AppMotion`.
- **No new packages.**

### Technical Approach

**One tile, drawn from data.** A table gives each state its face, border, rim, text colour and icon, the way `AppTone` does for cards. Each shape gives its radius, padding and alignment. A new state or shape can't drift in colour from the rest.

**The press is shared.** Tiles and the audio button use `TactilePressable`, so they sink and spring back like buttons and cards. Graded, used and disabled tiles have no tap handler, so they don't press.

**The shake doesn't move the layout.** It is a `Transform.translate`, which paints but doesn't lay out. It runs once and stops, and it is skipped with reduced motion, so tests still settle.

**The action bar never jumps.** Before grading, it always takes the Check button's height, whether or not Check shows. After grading, the panel grows above Continue with a slide, and the answers above scroll within a shorter area. Nothing in the answer area moves.

**Fixed-height pills make the lines.** Pill height comes from the scaled Ethiopic line height, the same method as `StatPill.heightOf`. So a Latin pill and a Fidel pill are the same height, and the answer line can rule its lines at exactly one pill height plus the run spacing.

**Everything uses tokens.** The kit lives in `lib/shared/widgets/`, which is exempt from every rule except the colour rule. So it may draw decoration, but every colour must be a token.

### Acceptance Criteria

**Story 001: frame and prompt**
- [ ] `ExerciseLayout` has the top bar (close through `onClose`, `AppProgressBar`, beans `StatPill`), the prompt, scrolling answers and the docked action bar, on `AppPage`.
- [ ] `QuestionPrompt` shows the instruction as one muted line with the question large and bold below. Without a question, the instruction is the headline.
- [ ] The translation, speaker chip and pronunciation each appear in a fixed place. The pronunciation is muted `body-sm` 500.
- [ ] `splitPrompt` and its tests are unchanged.
- [ ] A long Fidel question wraps with the Ethiopic line height and nothing is clipped.
- [ ] The gallery shows `ExerciseLayout` and every `QuestionPrompt` variant, in Latin and Fidel.

**Story 002: answer tile**
- [ ] Idle, selected, correct, incorrect, used and disabled match DESIGN.md component 4 using only tokens.
- [ ] Row, pill and cell shapes are each suited to their question types.
- [ ] Correct shows a check, incorrect a cross, and incorrect shakes once within `AppMotion.shake`. There is no shake with reduced motion.
- [ ] With `onTap == null`, taps do nothing and the tile shows it can't be tapped.
- [ ] A screen reader reads the label with button and selected flags.
- [ ] A Fidel label at 1.3× text grows and never clips or overflows.
- [ ] The gallery shows every state in every shape.

**Story 003: audio, answer line and action bar**
- [ ] `AudioPlayButton` is a large round tactile button with a shelf, a press and a playing state, and it calls the given `onPressed`.
- [ ] `AnswerSlotLine` shows the ruled lines with placed pills, or the gap with its word, and keeps `GapSentence`'s fixed gap width and screen-reader wording.
- [ ] Before grading, Check shows when asked, disabled until there is an answer. Otherwise its space is held.
- [ ] After grading, "Correct!" (mint, green) or "Not quite" (blush, terracotta) sits above Continue in the matching variant.
- [ ] The panel comes only from the grade it is given.
- [ ] One tap on Continue calls `onContinue` once.

**Whole bolt**
- [ ] The gallery shows every new component and state, with no overflow at 360×640 and 430×932, at 1.0× and 1.3× text.
- [ ] The rules test passes and the allow-list is not longer than 64 entries.
- [ ] `flutter analyze` shows no new issues. The full suite passes, apart from the same 7 end-to-end tests that need a backend on `localhost:8000`.

### Decisions to confirm

1. **Where the kit lives.**
   - **Plan:** `lib/shared/widgets/exercise/` rather than `lib/features/lesson/widgets/exercise/`, for the rules-test and gallery reasons above.
   - This is the only change to the bolt as planned.
2. **The audio button's "playing" state.**
   - `LessonAudioPlayer.play` only says when playback has started, not when it ends.
   - **Plan:** the button shows whatever `playing` it is given. In bolt 045, the lesson will show "playing" from the tap until `play()` returns, which covers the wait while a remote clip loads.
   - Showing it until the clip ends would need a change to the audio player, which this intent rules out.
3. **Graded tiles keep their full colour.**
   - Today, a graded `ChoiceTile` can't be tapped, so its green or red text is also dimmed to 60 %.
   - **Plan:** only idle tiles that can't be tapped are dimmed, so the result reads clearly.
4. **Match pairs will shake too.** Today only choice tiles shake on a wrong answer. With one tile, a wrong match pair shakes the same way, which is the consistency this intent asks for. This shows in bolt 045.
5. **No confetti.** DESIGN.md mentions small confetti on a correct tile. No story asks for it, and it would be an endlessly animated layer. It is left out; the check icon and the panel carry the result.
