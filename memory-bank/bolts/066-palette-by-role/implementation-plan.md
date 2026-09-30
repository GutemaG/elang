---
stage: plan
bolt: 066-palette-by-role
created: '2026-09-30T14:29:14Z'
---

## Implementation Plan: palette-by-role

### Objective

Story 001 (FR-1, FR-2): every colour in one palette file, by role, with
today's light values unchanged; the theme, the tone table, the shadows and
the text colours built from a palette. Screens are not touched yet (bolt
067 moves them); light mode looks exactly as before.

### What the code says (checked before planning)

- **F1: 78 colour constants** in `AppColors`, of which 67 are used in
  `lib/` and `test/`. 11 are used nowhere: `surfaceBright`,
  `surfaceVariant`, `onBackground`, `onPrimaryFixed`,
  `onPrimaryFixedVariant`, `secondaryFixedDim`, `onSecondaryFixed`,
  `onSecondaryFixedVariant`, `tertiaryFixedDim`, `onTertiaryFixed`,
  `onTertiaryFixedVariant`.
- **F2: Duplicates.** `surface`, `surfaceBright` and `background` are all
  `#FFF8F5`; `surfaceVariant` equals `surfaceContainerHighest`;
  `onBackground` equals `onSurface`.
- **F3: Readers of `AppColors` inside the theme folder**: `AppTheme` (the
  `ColorScheme`, app bar, chips, switches, snack bars), `AppTone` (an enum
  with nine colours per tone), `AppShadows` (static shadows built from
  colours), `AppTypography.phonetic` (a `const` style with `textMuted`).
- **F4: Outside the theme folder**: about 440 uses in 40 `lib/` files and
  168 in 15 test files, including `const` uses. Bolt 067 moves them.
- **F5: Many widget tests** pump a bare `MaterialApp` with no theme, so a
  theme lookup must fall back to the light palette.
- **F6: `test/shared/theme/design_tokens_test.dart`** already pins the
  light hex values of the 018 tokens, and the gallery has a colour list
  (`_ColoursSection`).

### Decisions

- **D1: `AppPalette`** (`lib/shared/theme/app_palette.dart`) is an
  immutable `ThemeExtension<AppPalette>` with one required `final Color`
  per role and a `const` constructor. `AppPalette.light` holds today's
  values. Its header explains: "to change a colour, edit its value here; to
  add a role, add the field, the constructor parameter and a value in each
  palette". `lerp` switches at the halfway point and `copyWith` returns the
  palette unchanged, so a role never has to be listed a third or fourth
  time.
- **D2: Role names.** Material's own names stay where they are the
  `ColorScheme` role (`primary`, `onSurface`, `surfaceContainerLow`,
  `outlineVariant`, ...). The names that came from a mockup become the role
  they play:

  | Today | Role |
  |---|---|
  | `background`, `surfaceBright`, `surface` | `surface` |
  | `cardBorderDefault` / `cardBevelDefault` | `cardBorder` / `cardShelf` |
  | `answerSelected` / `answerCorrect` / `answerIncorrect` | `answerSelectedFace` / `answerCorrectFace` / `answerIncorrectFace` |
  | `optionChosen` | `chosenFace` |
  | `lockedNode` | `lockedNodeFace` |
  | `primaryBevel` / `secondaryBevel` / `tertiaryBevel` | `primaryShelf` / `secondaryShelf` / `tertiaryShelf` |

  The 11 unused constants (F1) are dropped, so the dark palette has no
  colours to decide that nothing draws. That leaves 64 roles.
- **D3: `context.colors`**: an extension on `BuildContext` returning the
  theme's `AppPalette`, or `AppPalette.light` when the theme has none (F5).
- **D4: Derived pieces take a palette.**
  - `AppTheme.fromPalette(AppPalette, Brightness)` builds the whole
    `ThemeData` and registers the palette as its extension;
    `AppTheme.light` = `fromPalette(AppPalette.light, Brightness.light)`.
  - `AppTone` stays the enum (the name of a tone); `tone.colorsIn(palette)`
    returns a `ToneColors` with the nine colours, built from the palette's
    roles. `context.tone(AppTone.primary)` is the short form.
  - `AppShadows.of(palette)` gives the same shadows as today (`card`,
    `tile`, `dialog`, `button(...)`, ...) built from that palette;
    `context.shadows` is the short form. Depths stay static constants.
  - `AppTypography.phonetic` loses its fixed colour; the one widget that
    uses it (`exercise_layout.dart`) and the gallery sample add
    `textMuted` from the theme.
- **D5: A bridge until bolt 067.** `AppColors`, the enum's colour getters
  (`AppTone.primary.border`) and the static `AppShadows` members stay, but
  hold no hex: they forward to `AppPalette.light` (under the old names, so
  the file doubles as the old-to-new name map for bolt 067). Screens and
  tests keep their names; the only edits are removing `const` where an
  `AppColors` value sat in a `const` expression (6 in `lib/`, and a few
  tests such as `design_tokens_test.dart`'s `const expected` map), since
  a forwarded value is no longer a compile-time constant. Bolt 067 deletes
  the bridge.
- **D6: The light palette is pinned.** A new test lists every role of
  `AppPalette.light` with its hex, so a value changed by mistake fails; the
  existing token and gallery tests keep passing.

### Out of scope

- Moving screens and tests to `context.colors` (bolt 067); the dark
  palette and `AppTheme.dark` (068); the gallery's side-by-side view (069).

### Tests

- `app_palette_test.dart` (new): every light role's hex (D6); the lookup
  falls back to light with no extension; `lerp` switches halfway.
- `AppTheme.fromPalette`: the `ColorScheme`, chips, switches and snack bar
  read the given palette (checked with a test palette of distinct colours).
- `ToneColors` and `AppShadows.of`: each tone's colours and each shadow
  come from the given palette's roles; the light results equal today's.
- The whole suite, the design tests and `flutter analyze` unchanged.

### Acceptance criteria

- [ ] `AppPalette` lists every role; `light` holds today's values; every
  role is required.
- [ ] Duplicates merged, unused colours dropped, mockup names renamed to
  roles; the header says how to change a colour.
- [ ] `AppTheme`, tones, shadows and text colours are built from a
  palette; no hex outside `app_palette.dart`.
- [ ] `context.colors`, `context.tone(...)` and `context.shadows` exist,
  with the light fallback.
- [ ] Light mode unchanged: `flutter analyze` clean, `flutter test`
  passes; existing tests change only where `const` must go (D5).

---

## Implementation Notes (Stage 2)

Plan approved 2026-09-30.

### Changed

- **`app_palette.dart`** (new): `AppPalette`, a `ThemeExtension` with 66
  required roles and `AppPalette.light` (today's values). The header says
  how to change a colour and how to add a role. `copyWith` returns the
  palette; `lerp` switches halfway.
- **`app_theme_context.dart`** (new): `context.colors` (light fallback),
  `context.tone(...)`, `context.shadows`.
- **`AppTheme`**: `fromPalette(palette, brightness:)` builds the whole
  theme and carries the palette as its extension; `light` calls it;
  `chipThemeFor`, `switchThemeFor`, `snackBarThemeFor` take a palette
  (`chipTheme` stays, in light, for its test).
- **`AppTone`**: a plain enum; `colorsIn(palette)` returns `ToneColors`.
  The old getters (`AppTone.primary.border`) forward to light until 067.
- **`AppShadows`**: `of(palette)` returns `PaletteShadows` (`soft`,
  `card`, `raised`, `badge`, `dialog`, `tile`, `tileRaised`, `overlay`);
  `shelf`, `button`, `glow`, `halo`, `none` and the depths stay static;
  the old static members forward to light until 067.
- **`AppColors`**: now the bridge: every used old name is a getter on
  `AppPalette.light`, with no values; it doubles as the old-to-new name
  map.
- **`AppTypography.phonetic`** has no colour; `ExerciseLayout` and the
  gallery sample add `context.colors.textMuted`.
- **`AppSpinner`**: `color` is now optional (`null` = the theme's
  `primaryContainer`), since a default value must be a constant.

### Not in the plan

- **66 roles, not 64.** The plan's count was off by two: 78 constants,
  less the 11 unused, less `background` merged into `surface`.
- **43 `const` keywords removed, not 6**, across 20 files (`const Icon(`,
  `const SizedBox(`, the gallery's colour list, a few test literals). The
  plan counted only `const` next to `AppColors` on one line; the analyzer
  also flags the `const` of any widget containing one. They were removed
  by a script that drops the `const` enclosing each analyzer error, then
  `dart format` on the touched files. All come back in 067 wherever a
  value is constant again, or stay off where it reads the theme.
- Two existing tests changed for the phonetic colour
  (`design_tokens_test`: the style has no colour; `exercise_layout_test`:
  the text is the style plus `textMuted`).

### Tests (+10)

- `test/shared/theme/app_palette_test.dart` (new): every light role's hex
  (66); switching halfway; `context.colors` from the theme and the light
  fallback; `fromPalette` draws the `ColorScheme`, chips, switches, snack
  bar and app bar in a palette of 66 distinct colours; each tone from that
  palette, and all 36 light tone colours as before; the shadows from that
  palette, and the light card and dialog shadows as before.

## Checks (Stage 2)

- `flutter analyze`: no issues.
- `flutter test --exclude-tags e2e`: 1559 passed (was 1549).
- No `Color(0x...)` in `lib/` outside `app_palette.dart`.

---

## Test Report (Stage 3)

Implement approved 2026-09-30.

### Runs

| Suite | Result |
|---|---|
| `flutter analyze` | no issues |
| `flutter test --exclude-tags e2e` | 1559 passed |
| Theme, shared widget and design tests, repeated | 601 passed, 3 of 3 runs |
| Design rules (`test/design`) | 211 passed |
| `flutter build apk --debug` | built |

### Acceptance criteria

- [x] `AppPalette` lists every role; `light` holds today's values; every
  role is required (the 66-hex test; the constructor has no defaults).
- [x] Duplicates merged, unused colours dropped, mockup names renamed to
  roles; the header says how to change a colour.
- [x] `AppTheme`, tones, shadows and text colours are built from a
  palette; no hex outside `app_palette.dart`.
- [x] `context.colors`, `context.tone(...)` and `context.shadows` exist,
  with the light fallback.
- [x] Light mode unchanged: the existing widget, gallery, screen sweep and
  token tests pass; only the two phonetic assertions changed (notes).

### Not covered here

- A look on a phone: nothing should differ, since every colour value is
  the same and the tests compare colours, not pixels.
- Screens still read the light palette through the bridge; bolt 067 moves
  them to the theme.

