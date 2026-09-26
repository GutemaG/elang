---
stage: implement
bolt: 049-settings-downloads-and-sweep
created: '2026-09-26T05:58:06Z'
---

## Implementation Walkthrough: screen-migration-ui (settings, downloads and the sweep)

### Summary

- **Settings** now stands on `AppPage`:
  - a titled top bar with a back arrow
  - the profile on a card
  - three section headings (Learning, Preferences, About) over grouped
    rows
  - green switches
  - a full-width secondary "Log out" at the end

  The daily goal opens in the library sheet, and log-out asks in the
  library dialog.
- **Downloads** now stands on `AppPage`:
  - one row per pack on a single card, each with a delete button
  - an `EmptyState` when nothing is downloaded
  - deleting asks in the library dialog, with a red Delete
- **The sweep:**
  - The rules test has no allow-list, and it now also fails on an unused
    shared widget.
  - `TactileButton` is deleted.
  - A new test renders 43 scenes at 360×640 and 430×932, at 1.0× and 1.3×
    text.
  - New tests check reduced motion on real screens.
  - `flutter analyze` reports no issues.

### Structure Overview

- **One addition to the library.** Settings needed one thing the library
  lacked: a row with a switch that reads as a switch.
  - `SwitchRow` wraps `ListRow`.
  - `ListRow` gained a `toggled` field, so the row's single node says
    "on" or "off" instead of "button".
- **Both screens** use the same pattern as the other migrated pages:
  - While loading, on an error, or when empty, the page does not scroll
    and the state sits in the middle.
  - The list scrolls.
  - The back arrow only shows when there is a page to go back to, as the
    old `AppBar` did.

### Completed Work

- [x] **`lib/features/settings/screens/settings_screen.dart`:**
  - **The page:** an `AppPage` with an `AppTopBar` titled "Settings".
    - **Loading:** `LoadingState`.
    - **A failure:** an `ErrorState` with an `AppButton` Retry, under the
      same title as before.
  - **The profile:** the old header, on an `AppCard`. It is unchanged,
    fallbacks included.
  - **Learning:** Daily goal and Course.
    - Each value is the row's subtitle.
    - Icons: the flag in secondary tone, and translate in primary tone.
  - **Preferences:** Notifications and Sound are `SwitchRow`s (bell and
    speaker icons).
  - **About:** Licences (the info icon), still opening the licence page.
  - **Log out:** a full-width `AppButton.secondary` "Log out".
    - It asks through `showAppConfirmDialog`, with a plain primary
      "Log out" and the same message as before.
    - Confirming still clears the whole stack to sign-in.
  - **The daily-goal sheet:** it opens with `showAppSheet`.
    - It has a title row with a close button, like the course picker.
    - It holds the onboarding screen's four `SelectableOptionCard`s:
      square `IconBadge`s, and "Casual · 5 min/day" with "Gentle warm up ·
      +10 XP/day" below.
    - What it returns is unchanged.
    - To match the onboarding cards, the goal list gained each option's
      description and XP.
  - **Removed:** the private `_OptionSheet`.
- [x] **`lib/features/lesson/screens/download_management_screen.dart`:**
  - **The page:** an `AppPage` with an `AppTopBar` titled "Manage
    Downloads".
    - **Loading:** `LoadingState`.
    - **Empty:** an `EmptyState` titled "No downloaded lessons yet.",
      saying that lessons downloaded from the path show up here for
      offline use.
  - **The packs:** a `ListRowGroup`, with one `ListRow` per pack.
    - The download-done icon in primary tone, then the title, then
      "course · size".
    - A trailing `AppIconButton` delete, with the tooltip
      `Delete "<title>"`.
  - **Deleting:** it asks through `showAppConfirmDialog(destructive:
    true)`, keeping both of today's messages.
  - **Removed:** the hand-drawn card, shadow, border and `TextButton`.
- [x] **`lib/shared/widgets/app_card.dart`:**
  - **`ListRow.toggled`:** set, the row's node reads as a switch that is
    on or off, not a button. A disabled row keeps the switch state,
    marked disabled.
  - **`SwitchRow` (new):**
    - its fields: title, subtitle, icon, tone, value and `onChanged`
    - a tap on the row or on the switch flips it
    - the switch's own node is excluded, so a screen reader hears it once
    - `onChanged: null` disables it
- [x] **`lib/shared/theme/app_theme.dart`:**
  - **`switchTheme`:**
    - on: a green track and a white thumb
    - off: a grey outlined track with a grey thumb
    - disabled: faded to 40%
  - **`snackBarTheme`:** floating, on the dark `inverseSurface` card with
    the base radius. It covers the three existing snack bars (settings,
    language selection, course picker), whose wording is unchanged.
- [x] **Gallery (`gallery_surfaces.dart`):**
  - The settings-rows case now uses `SwitchRow`, plus a disabled one.
  - A new case shows a snack bar from the theme.
- [x] **`TactileButton` deleted:**
  - the file, its gallery section and its three tests
  - `TactilePressable` stays: `AppButton`, `AppCard`, `AppIconButton` and
    the answer tiles press through it.
- [x] **Lint fixes (`flutter analyze`: 13 infos to 0):** behaviour is
  unchanged in all of them.
  - **`answer_feedback_player.dart`, `http_course_api.dart`,
    `http_lesson_api.dart`, `http_user_preferences_api.dart` and
    `sync_engine.dart`:** private initializing formals, which the
    codebase already uses elsewhere (for example `AuthFlowController`).
  - **`http_user_preferences_api.dart`:** null-aware map entries.
  - **`test/helpers/controllable_lesson_api.dart`:** braces.
  - **`test/shared/services/course_wiring_test.dart`:** a null-aware map
    entry.
- [x] **`test/design/design_rules_test.dart`:**
  - `_notYetMigrated`, its stale-entry check and the colour-literal
    allow-list check are removed. The header says a late violation is
    fixed in the library, never excused.
  - **New check: every shared widget is used.** Each public class in
    `lib/shared/widgets/` must be used somewhere in `lib/`, outside the
    gallery. Use inside its own file counts only outside its own body,
    so a painter used by its page counts.
  - **New self-test:** the helper that finds a class body stops at the
    body's own closing brace.
  - A one-off audit found `TactileButton` as the only unused class.
- [x] **`test/design/screen_sweep_test.dart` (new):** 43 scenes in 4
  settings, 172 tests plus one that checks every scene lists what it
  should show.
  - **Onboarding and sign-in:** splash, the three carousel pages,
    language, daily goal, and sign-in with and without its error.
  - **The dashboard:** loaded, offline with a saved copy, and failed; the
    course picker; the home placeholder.
  - **The lesson:** all seven question types, before and after
    answering; a wrong answer; the mistake review; offline.
  - **Lesson complete:** online and offline; the exit, review-skill and
    out-of-beans sheets, and the level-up dialog.
  - **Settings:** loaded and failed; the daily-goal sheet; the log-out
    dialog.
  - **Downloads:** the list, empty, and the delete dialog.
  - **What makes a scene pass:** no framework error, and a marker for its
    state is on screen, so a scene that never reached its state cannot
    pass.
  - **The fixtures are long on purpose:** long names, long prompts and
    answers, a 128-day streak, 123,450 XP and a 12,420 Amole balance.
- [x] **`test/design/reduced_motion_test.dart` (new):** 8 tests, each
  run with reduced motion and again with motion on. With motion on, each
  proves the measurement sees real movement.
  - A held onboarding Continue.
  - A held lesson Check.
  - A held answer tile.
  - A wrong answer's shake, sampled across `AppMotion.shake`.
- [x] **`test/features/settings/screens/settings_and_downloads_on_kit_test.dart`
  (new):** 24 tests.
  - **Pages:** titles, the back arrow (and none on a first page),
    loading, and the error with Retry.
  - **Settings layout:** the profile card, the section order and the
    rows in each group, and the row values and icons.
  - **Switches:** a tap on the switch and on the row, and the one-node
    switch semantics.
  - **Log out:** its button's place and variant, the plain-primary
    dialog, and that a tap outside keeps the session.
  - **The goal sheet:** its cards and choice, a pick saving the goal, and
    a close that changes nothing.
  - **Errors:** a failed change shows on the themed card.
  - **Downloads:** the row anatomy, `EmptyState`, and the destructive
    dialog, which a tap outside cancels.
  - **The theme and `SwitchRow`:** the two themes' colours; a disabled
    `SwitchRow` can't be flipped and reads as a disabled switch; each tap
    passes the flipped value; a row is at least 56 px tall.
- [x] **Existing tests, changed only for replaced types:**
  - **`settings_screen_test.dart`:**
    - `SwitchListTile` becomes `SwitchRow`
    - `TextButton` becomes `AppButton`
    - `ensureVisible` before "Log out", which the longer grouped list
      pushes below the 800×600 test screen
  - **`settings_licences_test.dart`:** `ListTile` becomes `ListRow`.
  - **`download_management_screen_test.dart`:**
    - the text "Delete" becomes the delete button's tooltip
    - `TextButton` becomes `AppButton`
    - `find.text` for the course and size becomes `find.textContaining`,
      as they now share the subtitle line
    - after deleting one pack, the test checks which pack remains
  - **`app_button_test.dart`:** the `TactileButton` group is removed.

### Key Decisions

- **The confirm buttons:**
  - Log out uses a plain primary, because signing out deletes nothing.
  - Delete uses the destructive primary.
- **A download row is one screen-reader node.** `ListRow` merges its
  contents, so the node reads the title, the course and size, then the
  delete label, and a double tap starts deleting. The confirm dialog
  still stands between that and any loss.
- **Where the size goes:** it shares the subtitle with the course
  ("English to Amharic · 2.0 KB"), rather than going in a third line or
  next to the delete button. This keeps rows two lines tall and the
  delete button's space fixed.
- **The gallery's entry point** stays in `lib/gallery_main.dart`. A
  settings row would have been a new setting.
- **The unused-widget check covers classes only.** Top-level functions
  such as `showAppSheet` are all in use today, and a private class is
  already flagged by the analyzer.

### Deviations from Plan

- **The daily-goal sheet's cards gained descriptions** ("Gentle warm up ·
  +10 XP/day"), because the plan said to lay them out as the onboarding
  screen does. The old sheet passed an empty subtitle, which drew a blank
  line.
- **Two existing test files were fully formatted** by `dart format`,
  because they were edited and had not been formatted before:
  `settings_screen_test.dart` and `download_management_screen_test.dart`.

### Dependencies Added

- None.

### Developer Notes

- **Checks so far:**
  - `flutter analyze`: no issues.
  - Full suite: 1320 tests, all passing, including the e2e test that
    flaked before.
- **The sweep found no overflow at 360 and 430 px.** The earlier bolts
  had already fixed everything at 320 px.
- **Still to do in Test:**
  - the mutation check
  - the manual walk-through on a phone and the iOS simulator
