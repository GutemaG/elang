---
stage: plan
bolt: 070-appearance-setting
created: '2026-09-30T19:37:34Z'
---

## Implementation Plan: appearance-setting

### Objective

Story 006 (FR-5): Settings gets an "Appearance" row with System, Light
and Dark. System is the default and follows the phone, even while the app
is open. A choice applies at once on every screen, is kept on the phone,
survives restarts and sign-out, and applies before sign-in.

### What the code says (checked before planning)

- **F1: The app follows the phone today.** Since bolt 068, `main.dart`
  sets `darkTheme` and `themeMode: ThemeMode.system`, so System already
  works, including a change while the app is open.
- **F2: The Sound switch is the model.** `SoundPreferenceRepository`
  keeps a phone-only value in `SecureStorageService`, the project's one
  local key/value store. Sign-out (`SessionRepository.clearSession`)
  deletes only the session key, so a value stored there survives it.
- **F3: How Settings is reached.** The dashboard builds `SettingsScreen`
  and passes each service down, and eight tests build `SettingsScreen` or
  the dashboard directly. Threading a new service through all of them
  would be a lot of churn for an app-wide value.
- **F4: The rows.** Settings' Preferences group has Notifications and
  Sound. `ListRow` already reads as one node (title and subtitle merged),
  and the daily goal uses a sheet of `SelectableOptionCard`s, which fits a
  three-way choice.

### Decisions

- **D1: `AppearanceRepository`** (`lib/shared/services/`), like the Sound
  one: `load()` → `ThemeMode` (System when nothing is stored, or on an
  unknown value), `save(ThemeMode)`, under the key `appearance`
  (`system` / `light` / `dark`).
- **D2: `AppearanceController`**, a `ValueNotifier<ThemeMode>` that saves
  on each change, and **`AppearanceScope`**, an `InheritedNotifier` that
  hands it down, as `Theme` does for the theme. The app wraps
  `MaterialApp` in the scope and reads the mode from it, so a choice
  redraws every screen at once with no restart. Settings finds it with
  `AppearanceScope.of(context)`, so nothing is threaded through the
  dashboard (F3).
- **D3: Loaded before the first frame.** `main.dart` reads the stored
  choice before `runApp` (one local read), so someone who picked Light on
  a dark phone never sees a dark flash, and the choice applies to the
  splash and sign-in screens too.
- **D4: The row.** In Preferences, after Sound: a `ListRow` with a
  half-moon icon (`Icons.contrast`), title "Appearance" and the current
  value as its subtitle ("System", "Light", "Dark"), so a screen reader
  hears "Appearance, System, button". Tapping opens a sheet with three
  `SelectableOptionCard`s: System ("Match your phone"), Light, Dark, the
  current one selected. Picking one closes the sheet and applies it.
- **D5: Where the scope is missing** (tests that build `SettingsScreen`
  on its own), the row is left out rather than failing, so those tests
  stay as they are; the app always provides the scope.

### Out of scope

- Storing the choice on the server (the intent's D3: the phone only).
- The web `manifest.json` colours: the launch colour on the web is fixed
  in the manifest, not by the theme; left for a later tidy-up.

### Tests

- The repository: System by default and on an unknown value; each value
  round-trips.
- The controller: a change saves it.
- The app: with Light stored, the first frame is light on a dark phone;
  with System, the platform's brightness decides, and changing the
  platform brightness while open redraws.
- Settings: the row shows the current value as one node; picking Dark in
  the sheet makes the whole app dark at once and saves `dark`; the
  choice is still there after signing out.
- The screen sweep's Settings scene with the scope, the full suite and
  `flutter analyze`.

---

## Implementation Notes

### What changed

- **`lib/shared/services/appearance_repository.dart`** (new):
  `load()` / `save(ThemeMode)` under `appearance` in
  `SecureStorageService`; System when nothing or an unknown value is
  stored.
- **`lib/shared/theme/appearance.dart`** (new):
  - `AppearanceController`, a `ValueNotifier<ThemeMode>` with
    `load(repository)` and `choose(mode)`, which applies at once and saves;
  - `AppearanceScope`, an `InheritedNotifier`, with `maybeOf(context)`.
- **`main.dart`**: `main` is `async` and loads the controller before
  `runApp`. `BunaApp` takes a required `appearance`, wraps `MaterialApp`
  in `AppearanceScope` and a `ValueListenableBuilder`, and uses its value
  as `themeMode`.
- **`settings_screen.dart`**: an Appearance `ListRow`
  (`SettingsScreen.appearanceRowKey`, `Icons.contrast`) after Sound, with
  the current value as its subtitle. It opens `_AppearanceSheet`: System
  ("Match your phone"), Light ("Always light") and Dark ("Always dark") as
  `SelectableOptionCard`s. The row is left out when no scope is found.
- **Tests that build `BunaApp`** (`widget_test.dart`,
  `splash_screen_test.dart`) pass `testAppearance()`, from the new helper
  `test/helpers/test_appearance.dart`.
- **Screen sweep**: scenes run under an `AppearanceScope`, so Settings
  shows the row. A new scene covers the Appearance sheet, giving 46 scenes
  and 369 tests.

### Tests added

- `test/shared/services/appearance_repository_test.dart`: System by default
  and on an unknown value, each mode round-trips, the choice survives
  `clearSession`, and the controller loads and saves.
- `test/app_appearance_test.dart`:
  - Light on a dark phone and Dark on a light phone from the first frame;
  - System following a platform change while open;
  - a new choice redrawing the app.
- `test/features/settings/screens/settings_appearance_test.dart`:
  - the row is one node reading "Appearance, System" as a button;
  - picking Dark darkens the app at once, saves `dark` and updates the
    row;
  - closing the sheet changes nothing;
  - with no scope, the row is left out.

---

## Test Report

- **Full suite** (`flutter test --exclude-tags e2e`): 1792 passed, 0
  failed (1762 after bolt 068). Both bolts were built in the same working
  tree, so this run covers them together.
- **Targeted** (the gallery theme, app appearance, Settings appearance,
  appearance repository and design-rule tests): 30 passed, 3 runs out of 3.
- **`flutter analyze`**: no issues. **Debug APK**: built.
- **Story 006, each criterion**:
  - row with System as the default: yes;
  - applies at once, no restart: the app and Settings tests;
  - System follows the phone while open: the platform-brightness test;
  - kept on the phone, survives restarts (loaded before the first frame)
    and sign-out, applies before sign-in (the splash is themed): yes;
  - one readable node with its value: the semantics test.
- **Screen sweep**: 46 scenes (the new Appearance sheet included) x 2
  themes x 2 sizes x 2 text scales, 369 tests, no overflow.
- **Not tested here**: the choice on a real phone across a full restart,
  where secure storage is the platform's; the in-memory store stands in
  for it in tests, as for the Sound switch.
