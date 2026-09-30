---
stage: plan
bolt: 067-screens-read-theme
created: '2026-09-30T18:10:17Z'
---

## Implementation Plan: screens-read-theme

### Objective

Story 002 (FR-3): every screen and shared widget takes its colours from
the current theme (`context.colors`, `context.tone(...)`,
`context.shadows`), the bolt 066 bridge is deleted, and a design rule keeps
it that way. Light mode still looks exactly as before; dark mode (bolt 068)
then only needs a second palette.

### What the code says (checked before planning)

- **F1: `AppColors` uses**: 36 `lib/` files (the gallery 78, `app_status`
  34, `path_node` 22, `app_button` 19, `app_page` 17, `answer_tile` 16,
  then 30 files with 1 to 14) and 15 test files (168 uses).
- **F2: Bridge uses beyond `AppColors`**: 69 reads of a tone's colour
  through the enum (`tone.ink`, `AppTone.tertiary.border`) and
  palette-dependent static shadows (`AppShadows.card`, `.soft`, `.tile`,
  `.dialog`, ...) in 5 `lib/` files and 4 test files.
- **F3: Places with no `BuildContext`**, which need the palette handed in:
  - getters and helpers in widget classes (`PathNode._face`, `_foreground`,
    `_shelf`; the answer tile's state colours);
  - style tables (`AppButton`'s primary/secondary/gold/red styles);
  - painters (`PathNode`'s `_RingPainter` reads two colours in `paint`);
  - the gallery's `static final` colour list.
- **F4: Lints**: `flutter_lints` asks for `const` wherever it is possible,
  so `dart fix` can put back any of bolt 066's 43 removed `const` keywords
  that become constant again.

### Decisions

- **D1: Names.** Each old name becomes its role, using the bridge as the
  map (`cardBorderDefault` → `cardBorder`, `primaryBevel` →
  `primaryShelf`, `optionChosen` → `chosenFace`, `background` →
  `surface`, ...; the rest keep their name).
- **D2: In `build` and anything with a context**: `context.colors.<role>`;
  a method that reads several takes `final colors = context.colors;` once.
  Tones: `context.tone(tone).ink`. Shadows: `context.shadows.card`.
- **D3: No context (F3)**: the helper takes the palette.
  - Getters become methods: `_face(AppPalette colors)`.
  - Style tables become functions of a palette:
    `_AppButtonStyle.of(variant, colors)`.
  - Painters get their colours through the constructor and repaint when
    they change (`shouldRepaint` compares them), so a theme switch redraws.
- **D4: Tests** use `AppPalette.light.<role>`,
  `AppTone.x.colorsIn(AppPalette.light)` and
  `AppShadows.of(AppPalette.light)`: they pump the light theme or no theme,
  and both are the light palette. Test outcomes do not change; only names.
- **D5: The bridge goes.** `app_colors.dart` is deleted; the enum's colour
  getters and `AppShadows`' palette-dependent static members are removed.
  The gallery's colour list is built from the palette with the role names
  (bolt 069 turns it into the side-by-side page).
- **D6: The design rule.** `design_rules_test.dart` gains a rule: outside
  `lib/shared/theme/`, no `AppColors`, no `AppPalette.light` and no
  `AppShadows.of(` — screens and widgets read the theme. The gallery is
  not exempt.
- **D7: The work.** A script does the mechanical part (the D1 renames, and
  `AppColors.x` → `context.colors.<role>` where a `context` is in scope,
  which the analyzer confirms); the F3 places are changed by hand. Then
  `dart fix --apply` for `const`, and `dart format` on touched files.

### Out of scope

- Any colour value (light stays as it is); the dark palette (068); the
  gallery page (069).

### Tests

- The design rule (D6), with a check that it catches a planted
  `AppColors`/`AppPalette.light` use.
- `PathNode`'s ring and a button drawn with a test palette pick up its
  colours (proves the F3 hand-offs, not only the light fallback).
- The whole existing suite, renamed only (D4).

### Acceptance criteria

- [ ] No `AppColors` left; `app_colors.dart` deleted; no enum colour
  getters or palette-dependent static shadows left.
- [ ] Screens and widgets read `context.colors` / `context.tone` /
  `context.shadows`; helpers and painters get the palette handed in.
- [ ] The design rule fails any `AppColors`, `AppPalette.light` or
  `AppShadows.of(` outside `lib/shared/theme/`.
- [ ] A widget drawn under a different palette uses it (ring, button).
- [ ] Light unchanged: `flutter analyze` clean; `flutter test` passes with
  only renamed references in existing tests.

---

## Implementation Notes (Stage 2)

Plan approved 2026-09-30.

### Changed

- **Screens and widgets (36 `lib/` files)**: every `AppColors.x` is now
  `context.colors.<role>` (renamed by the D1 map), every palette-dependent
  shadow `context.shadows.<x>`, and every tone colour
  `context.tone(tone).<x>` (69 reads in 7 files).
- **No-context places (F3)**, by hand:
  - `PathNode`: `_face`, `_foreground`, `_shelf` take the palette; the
    ring painter gets `track` and `fill` colours and repaints when they
    change.
  - `AppButton`: `_TactileStyle.of(variant, colors)`; `_buildTactile`
    takes the context.
  - `AnswerTile`: `_TileLook.of(state, colors)` (the idle look too).
  - `AppProgressBar._gradientColors(colors)`;
    `AnswerSlotLine._lineColour(colors)` and `_sentenceStyle(context)`.
  - `AppPage`: `LatticePainter`, `CelebrationGlowPainter` and
    `WovenTibebPainter` take `colors` and repaint when it changes (the
    woven bands became an instance getter).
  - `course_picker`, the dashboard's download badge, the option card:
    helper methods take the context.
  - The gallery's colour list is `_groups(colors)`, labelled with the role
    names.
- **The bridge is gone**: `app_colors.dart` deleted; the tone enum's colour
  getters and `AppShadows`' light statics removed.
- **`app_theme_context.dart`** also exports `AppPalette`, so a widget that
  hands the palette on needs one import.
- **Design rule** `fixedPalette`: `AppColors`, `AppPalette.light` or
  `AppShadows.of(` outside `lib/shared/theme/` fails (gallery included).
- **Tests (15 files)**: `AppPalette.light.<role>`,
  `tone.colorsIn(AppPalette.light)`, `AppShadows.of(AppPalette.light)`.

### Not in the plan

- **The painter tests** (`app_page_test`) construct the painters with
  `colors: AppPalette.light`, and read the woven bands from an instance:
  a constructor change, not only a rename.
- **No `const` came back**: `dart fix` found nothing, because every widget
  bolt 066 un-`const`ed now reads the theme.
- `distinctPalette()` moved to `test/helpers/distinct_palette.dart`, shared
  by the palette test and the new one.
- The script-driven renames (a Python pass for `AppColors`/shadows, one
  for tone reads driven by the analyzer's error positions) were checked by
  `flutter analyze` after each pass; `dart format` on the touched files.

### Tests (+5)

- `test/shared/theme/theme_follow_test.dart` (new, 4): under a palette of
  66 distinct colours, the path node's ring arcs and circle, a primary
  button's face, a correct answer tile's face, and the patterned page
  background (painter and base colour) all use that palette.
- `design_rules_test.dart` (+1): the new rule catches `AppColors`,
  `AppPalette.light` and `AppShadows.of(`, and not `context.colors`,
  `context.tone`, `context.shadows` or a palette parameter.

## Checks (Stage 2)

- `flutter analyze`: no issues.
- `flutter test --exclude-tags e2e`: 1564 passed (was 1559).
- No `AppColors` left in `lib/` or `test/` (the rule's own samples
  aside).

---

## Test Report (Stage 3)

Implement approved 2026-09-30.

### Runs

| Suite | Result |
|---|---|
| `flutter analyze` | no issues |
| `flutter test --exclude-tags e2e` | 1564 passed |
| `test/shared`, `test/design` and the dashboard and settings kit tests, repeated | 948 passed, 3 of 3 runs |
| Design rules (`test/design`) | 212 passed |
| `flutter build apk --debug` | built |

A first targeted run without `--exclude-tags e2e` picked up
`http_auth_api_e2e_test.dart`, which needs a running backend; excluded as
in every run of this project.

### Acceptance criteria

- [x] No `AppColors` left; `app_colors.dart` deleted; no enum colour
  getters or palette-dependent static shadows left.
- [x] Screens and widgets read `context.colors` / `context.tone` /
  `context.shadows`; helpers and painters get the palette handed in.
- [x] The design rule fails any `AppColors`, `AppPalette.light` or
  `AppShadows.of(` outside `lib/shared/theme/` (and its own test proves
  what it catches).
- [x] A widget drawn under a different palette uses it
  (`theme_follow_test`: ring, node circle, button, answer tile, page
  background).
- [x] Light unchanged: `flutter analyze` clean; `flutter test` passes; the
  existing tests changed only in names, and the painter tests in how the
  painter is built (notes).

### Not covered here

- A look on a phone: every colour is the same light value as before.
- Widgets not in `theme_follow_test` are covered by the design rule (they
  cannot name a fixed palette) rather than one by one; bolt 068's dark
  screen sweep draws every screen in a second palette.

