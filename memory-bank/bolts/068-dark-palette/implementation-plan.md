---
stage: plan
bolt: 068-dark-palette
created: '2026-09-30T19:10:12Z'
---

## Implementation Plan: dark-palette

### Objective

Stories 003 (FR-4) and 004 (FR-7): a warm Highland Pulse dark palette and
`AppTheme.dark`, lesson pictures on a light card, system bars and the
Android launch screen that follow the theme, and a test that keeps text
readable in both palettes. Light mode stays exactly as it is (D5).

### What the code says (checked before planning)

- **F1: The app has one theme.** `main.dart` sets `theme: AppTheme.light`
  and nothing else; `AppTheme.fromPalette(p, brightness:)` already builds
  a whole theme from any palette, so dark is a second palette plus
  `AppTheme.dark`.
- **F2: Nothing else is fixed to light.** No `Colors.white`/`Colors.black`
  outside the theme, and the typography styles carry no colour.
- **F3: Roles that are both a fill and a text colour.** In light some roles
  do two jobs that need different colours in dark:
  - `tertiaryContainer` is the red button's face *and* the terracotta
    tone's ink and icon;
  - `primaryContainer` / `secondaryContainer` are button faces *and* the
    green / gold tones' icons;
  - the snack bar's action (`primaryFixedDim`) sits on `inverseSurface`,
    which is light in dark.
  A dark red text on a dark card, or a dark green icon on a dark green
  circle, would be unreadable.
- **F4: Pictures.** Picture answers draw the picture straight on the tile
  face (`answer_tile.dart`, the `picture` shape). Lesson pictures are
  drawn on white.
- **F5: System bars.** Most screens have no `AppBar`, so nothing sets the
  status/navigation bar icons; they stay dark (right for light only).
- **F6: Launch screen.** `values/styles.xml` and `values-night/styles.xml`
  use `@android:color/white` / `?android:colorBackground` (plain black in
  night mode), not the app's page colours.
- **F7: The sweep** (`test/design/screen_sweep_test.dart`) runs 66 scenes
  at 2 sizes x 2 text scales, in light only.

### Decisions

- **D1: The dark palette.** `AppPalette.dark` next to `light`, starting
  from the FR-4 table (page `#1B1510`, card `#251D16`, border / shelf
  `#3A2F26` / `#120D09`, text `#F2DFD1` / `#A8988A`, green text
  `#92D5A9`, green button `#1B5E3B` on `#0B2E1A`, gold / terracotta text
  `#FFB875` / `#FFB4A8`, correct / wrong faces `#173826` / `#3D1D18`;
  streak, gem, XP unchanged). The other roles follow the same rules:
  surfaces step up from the page in warm browns, tone surfaces are deep
  tints of their hue, texts are light tints. Every role gets a dark value
  with a one-line comment where it isn't obvious.
- **D2: Shelves.** Every shelf is darker than the face above it. Neutral
  shelves (cards, tiles, dialogs, badges) are also darker than the page,
  as FR-4 asks; a coloured button's shelf is a deep shade of its own hue,
  which reads as depth without going black. A test checks both.
- **D3: Split the double-duty roles (F3)** instead of changing the tone
  table's meaning: new roles with today's light values, so light is
  unchanged:
  - `primaryToneIcon`, `secondaryToneIcon`, `tertiaryToneIcon`,
    `tertiaryToneInk` (the tone table reads these);
  - `inverseAction` for the snack bar's action.
  The contrast test (D6) is what decides whether any other role needs the
  same split; any I add are listed in the implementation notes.
- **D4: `AppTheme.dark` and the app.** `AppTheme.dark` =
  `fromPalette(AppPalette.dark, brightness: Brightness.dark)`. `main.dart`
  gets `darkTheme: AppTheme.dark` and `themeMode: ThemeMode.system`, the
  intent's default (D2 of the intent), so the app follows the phone from
  this bolt and can be checked on a device; bolt 070 adds the choice.
- **D5: Pictures (F4).** A picture tile puts its picture on a rounded mat
  in a new role, `pictureMat`: transparent in light (the face shows
  through, as today) and a soft warm white (`#F3EBE2`) in dark. The
  tile's state still shows in its border, shelf and the face around the
  mat.
- **D6: System bars (F5).** The theme's `AppBarTheme` gets a
  `systemOverlayStyle`, and `MaterialApp.builder` wraps every screen in an
  `AnnotatedRegion<SystemUiOverlayStyle>` chosen from the theme's
  brightness: dark icons on light, light icons on dark, bars coloured as
  the page.
- **D7: Launch screen (F6).** `values/colors.xml` gets `launch_background`
  `#FFF8F5`; a new `values-night/colors.xml` sets it to `#1B1510`; both
  `launch_background.xml` files and `NormalTheme` use `@color/launch_background`.
  (The light launch screen becomes the page cream instead of plain white;
  it shows for a moment before the splash screen, which is already cream.)
- **D8: The contrast test** (`test/shared/theme/palette_contrast_test.dart`):
  a table of named pairs, each with its level:
  - body text 4.5:1: text and muted text on the page, cards and the
    surface containers; each tone's ink on its surface and on a card;
    text on each button fill (green, gold, red, neutral); text on the
    answer faces (selected, correct, wrong, chosen); snack bar text and
    action; error text;
  - large text and icons 3:1: each tone's icon on its surface; locked node
    icon on its face; the path's green on the page.
  It runs for both palettes, using the WCAG relative-luminance formula,
  and a failure reads `dark: textMuted on surfaceContainer is 3.9:1, needs
  4.5:1`. If a *light* pair fails, I report it to you instead of changing
  a light colour (D5 of the intent).

### Out of scope

- The Colours page and the light/dark switch in the gallery (069).
- The Appearance setting (070); until then the app follows the phone.
- The web build's `manifest.json` colours (it still has Flutter's blue);
  noted for 070.

### Tests

- The contrast test (D8) and the shelf test (D2), for both palettes.
- `AppPalette.dark`: every role differs from light where FR-4 says it
  should, and `AppTheme.dark` carries it with `Brightness.dark`.
- The picture mat: transparent in light, the mat colour in dark.
- System bars: the annotated overlay style is light-icons in dark and
  dark-icons in light.
- The screen sweep runs every scene in dark too (doubling it to 528
  tests), with no overflow or framework error.
- The whole existing suite, `flutter analyze`, and a debug APK build.

---

## Implementation Notes

### What changed

- **`app_palette.dart`**: `AppPalette.dark`, in the light palette's order,
  from the FR-4 table; the rest follows D1 (warm brown surfaces, deep
  tints for tone borders/surfaces and answer faces, light tints for text).
  Fills (green, gold, terracotta buttons) keep their light colours;
  streak, gem and XP are unchanged. Shadows and the scrim use black, since
  a warm brown vanishes on the page.
- **Eight new roles** (D3), each with the light value of the role its call
  sites used, so light is unchanged:
  - `primaryAccent` (was `primaryContainer` as text/icon): the splash and
    lesson-complete titles, the course badge icon, the selected course and
    option titles, Amole gains, the correct answer's text, line and
    feedback title, the green tone's icon, the spinner's default;
  - `tertiaryAccent` (was `tertiaryBrand` as text): the wrong answer's
    text, line and feedback title, the action bar's message, the bean
    countdown;
  - `tertiaryToneInk` (was `tertiaryContainer`): the terracotta tone's ink
    and icon;
  - `tertiaryFillShelf` (was `tertiary`): the shelf under a
    terracotta-filled card; found by the shelf test, not in the plan;
  - `secondaryButtonEdge` (was `secondary`): the gold button's border and
    shelf;
  - `answerLine` (was `tileShelf`): an unanswered slot's line, which in
    dark must show on the page while the tile rim is darker than it;
  - `inverseAction` (was `primaryFixedDim`): the snack bar's action;
  - `pictureMat`: transparent in light, `#F3EBE2` in dark.
  The plan's separate icon roles for the green and gold tones weren't
  needed: `primaryAccent` covers green, and gold's icon is already bright.
- **Dark values the tests tuned**: `tertiaryBrand` `#C23E2D` (white on the
  red button reaches 4.5:1), `onSecondary` `#3D2000` (the active node's
  icon), and the tone shelves darkened to below the page.
- **`app_theme.dart`**: `AppTheme.dark`, `AppTheme.systemBarsFor(p,
  brightness:)` and the app bar's `systemOverlayStyle`; the snack bar's
  action reads `inverseAction`.
- **`main.dart`**: `darkTheme: AppTheme.dark`, `themeMode:
  ThemeMode.system`, and a `builder` that puts an
  `AnnotatedRegion<SystemUiOverlayStyle>` over every screen.
- **`picture_tile.dart`**: a loaded picture sits on a `ColoredBox` in
  `pictureMat` (`PictureTile.matKey`); the loading placeholder and the
  failed alt text don't, so the alt text stays readable on the tile face.
- **Android**: `launch_background` colour `#FFF8F5`, and `#1B1510` in the
  new `values-night/colors.xml`; both `launch_background.xml` files and
  both `NormalTheme`s use it.
- **Design rule**: the fixed-palette rule also catches `AppPalette.dark`.

### Light shortfalls (reported, not changed)

The contrast test found six light pairs below WCAG AA, as DESIGN.md draws
them. They are listed in `_lightShortfalls` in the test; dark passes them
all:

- wrong-answer red (`#D84A38`) as text: 4.03:1 on the page, 4.24:1 on a
  card, 3.81:1 on the wrong-answer face (needs 4.5);
- white on the red button: 4.24:1 (needs 4.5);
- the gold tone's icon (`#FFA03B`) on cream: 1.74:1 (needs 3);
- the white icon on the active (gold) path node: 2.03:1 (needs 3).

### Plan corrections

- The sweep has 45 scenes, not 66, so dark adds 180 tests (361 in all),
  not 264.

---

## Test Report

- **Full suite** (`flutter test --exclude-tags e2e`): 1762 passed, 0
  failed (1564 before this bolt).
- **Targeted** (`test/design`, `test/shared/theme`, the picture tile):
  488 passed. The contrast and dark-palette tests: 15 passed, 3 runs out
  of 3.
- **`flutter analyze`**: no issues. **Debug APK**: built.
- **Contrast guard (story 004)**: its first run against the draft dark
  palette failed with messages such as `dark: onTertiary on tertiaryBrand
  is 4.24:1, needs 4.5:1` and `dark: tertiary is not darker than
  tertiaryContainer`, which led to the tuned values and
  `tertiaryFillShelf`. So a colour edit that breaks a pair is caught, and
  the message names the palette, both roles and the ratio.
- **Dark palette (story 003)**: the FR-4 anchor values, unchanged
  gamification accents, split roles equal to their old light colours,
  `AppTheme.dark`, system bars for both themes (theme, app bar and a
  screen with no app bar), the picture mat in both themes.
- **Screen sweep in dark**: 45 scenes x 2 sizes x 2 text scales, 180
  tests, no overflow or framework error.
- **Light unchanged (NFR-1)**: the light-palette hex test (66 roles), the
  light tone table, the light shadows and every existing widget test pass
  as before.
- **Not tested here**: how dark looks on a real phone, and the launch
  screen colour (Android resources, not reachable from widget tests).
  Checking on a device, and the gallery page in bolt 069, cover these.

