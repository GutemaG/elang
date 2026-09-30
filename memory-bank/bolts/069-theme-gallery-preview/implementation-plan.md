---
stage: plan
bolt: 069-theme-gallery-preview
created: '2026-09-30T19:37:34Z'
---

## Implementation Plan: theme-gallery-preview

### Objective

Story 005 (FR-6): the component gallery gets a Colours page that shows
every role with its light and dark swatch and hex side by side, and a
light/dark switch that redraws every gallery page in the other theme, so
a colour change can be checked in seconds.

### What the code says (checked before planning)

- **F1: The gallery** (`lib/shared/gallery/`, run with
  `flutter run -t lib/gallery_main.dart`) is one scrolling page of
  sections, the first being "Colours". `ComponentGalleryApp` pins
  `theme: AppTheme.light`.
- **F2: Its colour list is hand-written and incomplete**: 54 of the 74
  roles (none of `onPrimary`, `inverseSurface`, bolt 068's eight new
  roles, ...), and it shows only the current theme's colour.
- **F3: The design rule** forbids `AppPalette.light`/`.dark` outside
  `lib/shared/theme/`, and the gallery is not exempt. A side-by-side page
  must read both palettes at once, which no theme gives.
- **F4: `AppTopBar`** takes `trailing` widgets, so the switch fits there.

### Decisions

- **D1: One list of roles, in the theme folder.** `AppPalette.roles`: the
  roles in groups, each a name and a getter
  (`('surface', (p) => p.surface)`), next to the fields. A test checks it
  names every role exactly once, so a new role can't be left out of the
  gallery. The contrast test keeps its own pairs.
- **D2: Both palettes, from the theme folder.** `AppPalette.all`
  (`{'Light': light, 'Dark': dark}`) sits beside the palettes, and the
  Colours page reads that. The design rule's fixed-palette pattern also
  catches `AppPalette.all`, and the Colours page file is the one named
  exemption, with the reason in the rule: it exists to show both palettes
  side by side. Every other gallery page still reads the theme.
- **D3: The Colours page.** It moves to its own file,
  `gallery_colours.dart`. Each group is a heading, then one line per role:
  the role name, then a light swatch with its hex and a dark swatch with
  its hex. Transparent roles show their alpha (`#FFFFFF @00`) over a
  checkerboard, so "clear" is visible. It fits 360 px wide.
- **D4: The switch.** `ComponentGalleryApp` becomes stateful and holds a
  `ThemeMode` (light at start). A sun/moon `AppIconButton` in the top bar
  ("Dark theme" / "Light theme" tooltip) flips it; `MaterialApp` gets
  `theme`, `darkTheme` and the mode, so every section redraws in the other
  palette in one frame.

### Out of scope

- The Appearance setting in the app (070).
- Editing colours from the gallery (colours are changed in
  `app_palette.dart`, the intent's D1).

### Tests

- `AppPalette.roles` covers every role once (the constructor's parameters
  against the list).
- The Colours page shows each role's name and both hexes, including a
  bolt 068 role and the transparent `pictureMat`.
- The switch: a component samples the light palette, a tap redraws it in
  the dark one, and a second tap goes back.
- The design rule: `AppPalette.all` is caught outside the theme folder
  and the Colours page's exemption holds.
- The gallery's existing tests, the full suite and `flutter analyze`.

---

## Implementation Notes

### What changed

- **`app_palette.dart`**: `AppPalette.roles`, the 74 roles in 15 groups
  (named after the field sections) with a getter each, in field order;
  and `AppPalette.all` (`{'Light': light, 'Dark': dark}`). The file's
  header says a new role goes into `roles` too.
- **`gallery_colours.dart`** (new): `ColoursGallerySection`. Per group, a
  line per role: the name, then a light and a dark swatch, each a 32 px
  chip over a checkerboard with the palette's name and hex beside it.
  Transparent colours show their alpha (`#FFFFFF @00`).
- **`component_gallery.dart`**: the old hand-written `_ColoursSection`
  and `_Swatch` are gone. `ComponentGalleryApp` is stateful with a
  `ThemeMode`. `ComponentGallery` takes `dark` and `onToggleTheme` and
  shows a sun/moon `AppIconButton` (`themeSwitchKey`, tooltip "Dark
  theme" / "Light theme") in the top bar when it has a toggle.
- **Design rule**: the fixed-palette pattern also catches `AppPalette.all`;
  `lib/shared/gallery/gallery_colours.dart` is exempt from that rule only,
  with the reason beside it.

### Tests added

- `test/design/gallery_theme_test.dart`:
  - `roles` names every constructor parameter once, in order;
  - each entry reads its own role (74 distinct colours from
    `distinctPalette`);
  - `all` is both palettes;
  - the Colours page shows every role's name, both page hexes, and
    `pictureMat` as `#FFFFFF @00` / `#F3EBE2`;
  - the switch goes light → dark → light;
  - the whole gallery lays out in dark at 360×640 with 1.3x text.
- `design_rules_test.dart`: `AppPalette.all` is caught, `AppPalette.roles`
  isn't, and the Colours page's exemption covers only the fixed-palette
  rule.

---

## Test Report

- **Full suite** (`flutter test --exclude-tags e2e`): 1792 passed, 0
  failed (1762 after bolt 068). Both bolts were built in the same working
  tree, so this run covers them together.
- **Targeted** (the gallery theme, app appearance, Settings appearance,
  appearance repository and design-rule tests): 30 passed, 3 runs out of 3.
- **`flutter analyze`**: no issues. **Debug APK**: built.
- **Story 005**:
  - the Colours page lists all 74 roles with light and dark hexes, and
    `AppPalette.roles` can't miss a role;
  - the switch redraws the gallery in dark and back;
  - the whole gallery lays out in dark at 360×640 with 1.3x text, and the
    existing gallery tests still pass in light.
- **Not tested here**: the gallery on a phone (`flutter run -t
  lib/gallery_main.dart`); that is the quick way to tune dark colours.
