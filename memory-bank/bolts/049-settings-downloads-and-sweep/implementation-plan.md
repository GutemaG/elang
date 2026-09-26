---
stage: plan
bolt: 049-settings-downloads-and-sweep
created: '2026-09-26T05:34:17Z'
---

## Implementation Plan: screen-migration-ui (settings, downloads and the sweep)

### Objective

Move the last two screens, settings and download management, onto the
design library. Then check every screen together against the same rules:

- the rules test's allow-list goes, and the test runs strict
- every screen is rendered at two phone sizes and two text scales with no
  overflow
- reduced motion is checked on real screens
- `TactileButton` is deleted, with no unused shared widget left behind
- `flutter analyze` reports 0 issues

The on-device font and reference check is a manual step, recorded in the
test walkthrough.

### Reference designs (FR-11)

Neither screen has a Stitch mockup.

- **Material 3 lists** (material-web `docs/components/list.md`, fetched
  for bolt 043, which built `ListRow`):
  - **Borrowed:** leading icon, headline, supporting text, then a
    trailing control; dividers between the rows of a group.
- **Material 3 switch** ([material-components-android
  `docs/components/Switch.md`](https://github.com/material-components/material-components-android/blob/master/docs/components/Switch.md),
  fetched now):
  - **Borrowed:** a switch is for one on/off setting that takes effect at
    once, with no save step. That is true of both Notifications and Sound.
  - **Borrowed:** the row's label is what a screen reader announces with
    the switch's state, so the switch needs no label of its own.
  - **Borrowed:** at least a 48 px touch target.
- **Material 3 dialogs** (`docs/components/Dialog.md`, fetched for bolt
  043): icon, headline, supporting text, then actions. Buna stacks the
  actions, as bolt 043 decided.
- **Duolingo settings** (listed on
  [Mobbin](https://mobbin.com/explore/screens/2df9c29e-9ae7-4b10-8e1a-dd70f308c993)
  and [Uiland](https://uiland.design/screens/duolingo/screens/3497acfe-84e0-400a-bbac-cf38c19e6b9a);
  both need a sign-in to view the pictures, so this is from the app
  itself):
  - **Borrowed:** short bold section headings above white rounded groups
    of rows.
  - **Borrowed:** green switches.
  - **Borrowed:** a full-width "Sign out" button at the very end of the
    list, not in the top bar or a menu.
  - **Not borrowed:** Duolingo's profile tab and its many settings. The
    story adds no settings.
- **NN/g empty states** (bolt 043): the empty downloads list says what it
  is, how it fills, and what to do.

### Decisions

**Settings (story 004)**

- **D1: The page.**
  - **Shell:** an `AppPage` with an `AppTopBar` titled "Settings" and an
    `AppIconButton` back arrow that pops.
  - **Loading:** `LoadingState`.
  - **A load failure:** `ErrorState` with an `AppButton` Retry, with
    today's title, "Couldn't load your settings".
- **D2: The profile header.** Today's avatar, name, email and provider
  line, on an `AppCard`. What it shows, and its fallbacks, are unchanged.
- **D3: Grouped rows.**
  - **Sections:** each is a `SectionHeader` over a `ListRowGroup`.
    - **"Learning":** Daily goal, with the goal as the subtitle; Course,
      with the course as the subtitle.
    - **"Preferences":** Notifications and Sound, each with a switch.
    - **"About":** Licences.
  - **Leading icons:**
    - Daily goal: the flag, in secondary tone
    - Course: translate, in primary tone
    - Notifications: the bell
    - Sound: the speaker
    - Licences: the info icon
  - **A switch row:** tapping anywhere on it toggles the switch, as
    `SwitchListTile` does today. A screen reader hears one node: the
    label, then on or off.
  - **Not changing:** row text and behaviour.
- **D4: Log out.** An `AppButton.secondary` "Log out", full width, at the
  end of the list, as in Duolingo.
  - **Its confirmation:** `showAppConfirmDialog`, with "Log out" as a
    plain primary. Signing out deletes nothing, so it is not destructive.
  - **After confirming:** the whole stack is cleared to sign-in, as now.
- **D5: The daily-goal sheet.** It opens with `showAppSheet`, titled
  "Daily goal".
  - **Options:** today's four `SelectableOptionCard`s, laid out as on the
    onboarding daily-goal screen.
  - **What it returns:** unchanged. A pick saves the goal; a dismiss
    changes nothing.
- **D6: The switch look joins the theme.** `AppTheme` gets a
  `switchTheme` built from tokens:
  - **On:** a green track and a white thumb.
  - **Off:** a grey outline track.
  - **Gallery:** switches, on and off, inside a `ListRow` case.
- **D7: Error messages.** `AppTheme` gets a `snackBarTheme` built from
  tokens: a floating dark card with the base radius. This covers the
  three snack bars (settings, language selection, course picker). What
  they say does not change.
- **D8: The gallery's entry point stays where it is,** in
  `lib/gallery_main.dart`. The story allows a debug-only row here, but
  that would be a new setting, which the story rules out.

**Downloads (story 004)**

- **D9: The page.**
  - **Shell:** an `AppPage` with an `AppTopBar` titled "Manage Downloads"
    and a back arrow.
  - **Loading:** `LoadingState`.
- **D10: The packs.**
  - **The list:** a `ListRowGroup`, one `ListRow` per pack.
  - **Each row:**
    - the download-done icon, in primary tone
    - the lesson title
    - the course and size as the subtitle ("Amharic · 1.2 MB")
    - a trailing `AppIconButton` delete, with the tooltip
      `Delete "<title>"`
  - **Not changing:** the size formatting.
- **D11: Empty.** An `EmptyState`:
  - **Title:** "No downloaded lessons yet."
  - **Message:** that lessons downloaded from the path show here for
    offline use.
  - **No action:** the download buttons are on the path.
- **D12: Deleting.** It asks through `showAppConfirmDialog` with
  `destructive: true` and a "Delete" confirm.
  - **The message:** today's two versions, one of them the pending-sync
    warning.
  - **After deleting:** the list reloads, as now.

**The sweep (story 005)**

- **D13: The rules test runs strict.**
  - `_notYetMigrated` and its stale-entry check are removed, so every
    file in `lib/` must pass every rule.
  - A late violation is fixed in the library, never allowed back.
- **D14: A new overflow test,** `test/design/screen_sweep_test.dart`.
  - **Sizes:** each screen at 360×640 and 430×932, at 1.0× and 1.3× text.
    That is four runs per screen.
  - **Screens and states, with fakes:**
    - splash and each carousel page
    - language selection, daily goal, and sign-in (plain and with its
      error)
    - the dashboard: loaded, offline and error
    - a lesson for each of the seven question types, before and after
      checking
    - the mistake-review card and lesson complete
    - the lesson sheets and dialogs: exit, review-skill, out-of-beans and
      level-up
    - the course picker
    - settings (loaded and error) and the daily-goal sheet
    - downloads (list and empty) and the delete dialog
    - the home placeholder
  - **Fails on:** any overflow or other framework error.
  - Anything it finds is fixed in this bolt.
- **D15: Reduced motion on real screens.** New tests with
  `disableAnimations` on:
  - **Pressing a button:** "Continue" on onboarding and "Check" in a
    lesson are held down, and neither face moves.
  - **A wrong answer:** in a lesson, the tile does not shake. Its offset
    stays zero through the shake's duration.
  - The library already skips movement through `AppMotion.reduced`; these
    tests prove the screens pass it on.
- **D16: `TactileButton` is deleted.**
  - **What goes with it:** the file, its gallery case and its tests.
    Settings was its last user.
  - **What stays:** `TactilePressable`, which `AppButton` and `AppCard`
    press through.
  - **A new rules-test check: no unused shared widget.** Every public
    class in `lib/shared/widgets/` must be used somewhere in `lib/`
    outside its own file and the gallery. Anything this finds unused is
    deleted.
- **D17: `flutter analyze` goes to 0 issues.**
  - **The 13 infos** are old lint notes in `lib/shared/services/` and two
    test helpers, none from this intent.
  - **The fixes:** initializing formals, null-aware list elements, one
    pair of braces.
  - **Behaviour:** unchanged.
- **D18: The on-device check is manual.**
  - **When:** in Test, I prepare a walk-through list for you to follow
    on an Android phone and the iOS simulator.
  - **Flows:** onboarding, sign-in, the dashboard, a lesson with each
    question type, lesson complete, settings and downloads.
  - **What to check:** the bundled fonts, and each screen against its
    reference.
  - **Recording:** your findings go in the test walkthrough. Like bolt
    047's profile-mode check, the criterion stays open until it is done.

### Deliverables

- **`lib/features/settings/screens/settings_screen.dart`:** rebuilt.
- **`lib/features/lesson/screens/download_management_screen.dart`:**
  rebuilt.
- **`lib/shared/theme/app_theme.dart`:** `switchTheme` and
  `snackBarTheme`.
- **`lib/shared/gallery/`:** cases for the switch row and the snack bar;
  the `TactileButton` case removed.
- **`lib/shared/widgets/tactile_button.dart`:** deleted.
- **Lint fixes:** `lib/shared/services/` (5 files),
  `test/helpers/controllable_lesson_api.dart` and
  `test/shared/services/course_wiring_test.dart`.
- **`test/design/design_rules_test.dart`:** strict, with the
  unused-widget check.
- **`test/design/screen_sweep_test.dart`:** new.
- **Tests:**
  - **Settings, licences and downloads tests:** changed only for replaced
    types.
  - **`app_button_test.dart`:** the `TactileButton` group removed.
  - **New tests:** the rebuilt settings and downloads screens, the theme
    additions, and reduced motion on real screens.

### Dependencies

- Bolts 042–048: the library and the other migrated screens.
- No new packages.

### Out of Scope

- New settings, a profile page, dark mode, tablet and landscape.

### Acceptance Criteria

**Story 004**

- [ ] **Settings** uses `AppPage` with a top bar, `SectionHeader`s and
      `ListRow`s in `AppCard`s. Its switches and values behave as before.
- [ ] **The daily-goal sheet** uses `showAppSheet`, and the log-out
      confirmation uses `showAppDialog` (through `showAppConfirmDialog`).
- [ ] **Downloads:** each pack is a `ListRow` in an `AppCard`, the empty
      list is an `EmptyState`, and removal asks through `showAppDialog`
      with a destructive primary.
- [ ] **Existing tests:** the settings and downloads tests pass, changed
      only for replaced types.

**Story 005**

- [ ] **Rules test:** no allow-list, and it passes.
- [ ] **Overflow:** every screen renders at 360×640 and 430×932, at 1.0×
      and 1.3× text, with no overflow.
- [ ] **Reduced motion:** no press movement and no shake.
- [ ] **On a device:** the main flows are walked on a phone and the iOS
      simulator, and the findings are recorded (manual).
- [ ] **`flutter analyze`** reports 0 issues, and the full suite passes.
- [ ] **`TactileButton`** is deleted, and no unused shared widget is
      left.
