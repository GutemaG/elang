---
stage: test
bolt: 049-settings-downloads-and-sweep
created: '2026-09-26T06:29:34Z'
---

## Test Report: screen-migration-ui (settings, downloads and the sweep)

### Summary

- **Tests:** all 1,324 Flutter tests pass.
  - **The full suite:** the end-to-end sign-in test ("a garbage Google ID
    token…") failed once in one full run, as in bolt 047. It passed alone
    and in every other full run.
  - **New in this bolt:** 211 tests.
    - `screen_sweep_test.dart`: 173
    - `settings_and_downloads_on_kit_test.dart`: 27
    - `reduced_motion_test.dart`: 8
    - the rules test: 3 (the unused-widget check, its sample-file
      self-test, and the class-body self-test)
  - **Removed:** 5 tests: the 3 `TactileButton` tests and the rules
    test's two allow-list checks.
- **Checks:**
  - `flutter analyze`: no issues, down from 13 infos.
  - `dart format`: nothing to change in any file this bolt touched.
- **Coverage:** not measured.
- **Mutation check:** 42 deliberate breakages, each run against:
  - the settings, downloads and design tests
  - the gallery test
  - the `app_card` tests
  - **Results:**
    - **First run:** 39 caught.
    - **After two new tests:** 41 caught.
    - **The last, #30,** is equivalent for a screen reader. Removing the
      `ExcludeSemantics` around the switch adds only a "focus" action to
      the row's single node. Its label and on/off state stay the same.
  - **The breakages cover:**
    - every layout and behaviour choice on both screens
    - `SwitchRow` and `ListRow.toggled`
    - both themes
    - reduced motion in `TactilePressable` and `AnswerTile`
    - the rules test's own unused-widget logic
    - a deliberate overflow in the settings profile, which the sweep
      caught
  - **Restored after each run:** every file was checked, with one
    exception, below under Notes.

### Test Files

- [x] **`test/design/screen_sweep_test.dart`** (173, new)
  - **Coverage:** 43 scenes, each at 360×640 and 430×932, at 1.0× and
    1.3× text.
    - **Onboarding and sign-in:** splash, the three carousel pages,
      language, daily goal, and sign-in with and without its error.
    - **The dashboard:** loaded, offline with a saved copy, and failed;
      the course picker; the home placeholder.
    - **The lesson:** the seven question types before and after
      answering; a wrong answer; the mistake review; offline.
    - **Lesson complete and its pop-ups:** online and offline; the exit,
      review-skill and out-of-beans sheets and the level-up dialog.
    - **Settings:** loaded and failed; the goal sheet; the log-out dialog.
    - **Downloads:** the list, empty, and the delete dialog.
  - **Pass condition:** no framework error, and the scene's state marker
    is on screen. One extra test checks every scene has a marker.
  - **Result:** no overflow anywhere.
- [x] **`test/design/reduced_motion_test.dart`** (8, new): each check
  runs with reduced motion and with motion on.
  - A held onboarding Continue.
  - A held lesson Check.
  - A held answer tile.
  - A wrong answer's shake.
- [x] **`test/features/settings/screens/settings_and_downloads_on_kit_test.dart`**
  (27, new)
  - **Settings:**
    - the page, title and back arrow (none on a first page)
    - loading, and the error with Retry, which does not scroll
    - the profile card
    - section order and the rows in each group
    - row values, icons and tones
    - a tap on the switch and on the row
    - one switch node, not a button
    - the Log out button's variant, width and place
    - the plain-primary log-out dialog; a tap outside keeps the session
    - the goal sheet's four cards, the current one chosen, their
      subtitles; a pick saves it and a close changes nothing
    - a failed change on the dark themed card
  - **Downloads:**
    - the page and back arrow (none on a first page)
    - the row anatomy and the delete tooltip
    - loading, which does not scroll
    - the list scrolls
    - the empty state, which does not scroll, says how the list fills,
      and has no button
    - the destructive delete dialog, which a tap outside cancels
  - **The theme:** switch colours on, off and disabled; snack bar
    behaviour and colours.
  - **`SwitchRow`:**
    - disabled, it can't be flipped and reads as a disabled switch
    - each tap passes the flipped value
    - it is at least 56 px tall
- [x] **`test/design/design_rules_test.dart`** (7)
  - **Strict:** no allow-list.
  - **Every shared widget is used.**
  - **A self-test on sample files:** a class used by a screen counts as
    used, and so does one used in its own file outside its body. A class
    used only by the gallery, or only inside its own body, does not.
  - **The class-body matcher.**
- [x] **Existing tests:**
  - **`settings_screen_test.dart`, `settings_licences_test.dart` and
    `download_management_screen_test.dart`:** pass, changed only for
    replaced types, plus one `ensureVisible` for the longer list.
  - **Everything else:** passes unchanged, apart from the removed
    `TactileButton` group.

### Acceptance Criteria Validation

**Story 004: settings and downloads**

- ✅ **Settings** uses `AppPage` with a top bar, `SectionHeader`s and
  `ListRow`s in `AppCard`s (`ListRowGroup`). The switches and values keep
  their behaviour: the settings screen tests pass, plus the new switch
  tests.
- ✅ **The daily-goal sheet** uses `showAppSheet`. The log-out and delete
  confirmations use `showAppDialog` (through `showAppConfirmDialog`), with
  a destructive primary for deleting only.
- ✅ **Downloads:** each pack is a `ListRow` on an `AppCard`, the empty
  list is an `EmptyState`, and removal asks through `showAppDialog`.
- ✅ **The settings and downloads tests** pass, changed only for replaced
  types.

**Story 005: the consistency sweep**

- ✅ **The rules test** has no allow-list and passes (NFR-1).
- ✅ **Overflow:** every screen renders at 360×640 and 430×932, at 1.0×
  and 1.3× text, with no overflow (NFR-2, NFR-4).
- ✅ **Reduced motion:** no press movement and no shake, on real screens
  (NFR-2).
- ⏳ **On a real Android phone and an iPhone (or the iOS simulator):**
  the fonts and each screen against its reference are not checked yet.
  - This machine has no phone connected, no Android emulator, and cannot
    run the iOS simulator.
  - The checklist below is ready; the findings will be recorded here.
- ✅ **`flutter analyze`** reports 0 issues, and the full suite passes
  (NFR-5). The one e2e flake is noted above.
- ✅ **`TactileButton`** is deleted, and the new rules check confirms that
  no shared widget is left unused.

### On-Device Checklist (manual)

Run a build on an Android phone, then on an iPhone or the iOS simulator
(which needs a Mac). Compare each screen with its reference: the Stitch
mockups in `stich-screens/extracted/`, or the reference named in the
bolt's plan. Note anything that differs.

1. **Fonts, on every screen below:**
   - all Latin text is in the bundled Plus Jakarta Sans, not Roboto or San
     Francisco (compare the "g" and "y" with the component gallery)
   - Amharic is in the bundled Noto Sans Ethiopic, with no vowel marks
     clipped (compare "ቡና" with the gallery)
2. **Onboarding:** the splash brewing bar, the carousel's three pages and
   their dots, language selection and daily goal. Reference: mockups 0 to
   4.
3. **Sign-in:** the Google and Apple buttons are the same size. In
   airplane mode, tap one to see the inline error banner with Retry.
   Reference: mockup 5.
4. **Dashboard:**
   - the lattice background and the stat pills
   - the milestone banners in turning colours
   - the done, active and locked nodes
   - the course picker
   - scroll a long course: the header stays pinned and each banner pins
     over its own nodes (also bolt 047's scroll-smoothness check, in
     profile mode)
5. **A lesson with each question type:**
   - multiple choice, listening, sentence, match pairs, gap fill, picture
     choice and audio picture choice
   - answer one wrong to see the shake and the terracotta panel, then the
     mistake review
6. **Lesson complete:** the glow, the three stat cards, the progress cards
   and Continue, plus the level-up dialog when a skill levels up.
7. **Settings:**
   - the profile card and the three groups
   - the switches, flipped from the row and from the switch
   - the goal sheet and the log-out dialog
8. **Downloads:** download a lesson from the path, see its row, delete it
   through the red dialog, and see the empty state.
9. **Reduced motion:** turn on "Remove animations" (Android) or "Reduce
   Motion" (iOS). Buttons no longer sink and a wrong answer no longer
   shakes, but colours still change.
10. **Largest system text:** repeat items 2, 3, 5 and 7 briefly. Nothing
    is cut off or overlapping.

### Issues Found

- **Downloads, whether the page scrolls:** nothing checked it (mutation
  #21). A test now checks the list scrolls and the empty and loading
  states do not.
- **Downloads, the back arrow on a first page:** nothing checked that
  there is none (mutation #24). A test now checks it.
- **No bugs found in the app code.** The sweep and the reduced-motion
  tests passed on their first run. Mutations showed each one detects real
  overflow and real movement.

### Notes

- **An interrupted mutation run emptied a source file.** It was stopped
  mid-run so a commit could be made, and the stop landed mid-write,
  leaving `settings_screen.dart` empty.
  - **How it was rebuilt:** from the last commit plus the recorded edit
    script and `dart format`.
  - **How it was checked:**
    - the same line positions as before
    - all 42 mutation anchors match
    - analyze is clean
    - the full suite passes
  - This happened before commit `61e9a0e`, so that commit holds the
    rebuilt file. Next time, let a mutation run finish rather than stop
    it.
- **Still open:** the on-device check (story 005) and bolt 047's
  scroll-smoothness check in profile mode. Both are manual.
