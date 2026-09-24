---
stage: plan
bolt: 042-design-foundation
created: '2026-09-24T13:08:00Z'
---

## Implementation Plan: design-foundation-ui

### Objective

Lay the base of the design system. This bolt adds:
- every token (colour, shadow, radius and motion)
- the two bundled fonts
- one press behaviour shared by everything tactile
- `AppButton` and `AppIconButton`
- a debug component gallery
- a rules test that stops screens drawing their own decoration

**No screen looks different after this bolt**, except that text renders in
the bundled fonts. The screens still use `TactileButton` and their own
decoration; they move over in bolts 045-049.

### Reference designs (FR-11)

**Stitch mockups**, in `stich-screens/extracted/stitch_ethiopian_language_learning_app/`. These are the primary reference.
- **`out_of_beans_refill_modal/code.html`**
  - **Gold "accent" button:**
    - face `#FFA03B`
    - 2 px border `#8D4F00`
    - 4 px shelf `#8D4F00`
    - trailing price badge
  - **White secondary button:**
    - green text
    - 2 px border in green at 30%
    - 3 px neutral shelf
  - **"Not now"**: a `label-md` text link in `on-surface-variant`.
  - **Round close button**: 32 px, on `surface-container`.
  - **Press**: `translateY(shelf)`, the shelf collapses, over 80 ms.
- **`lesson_complete_summary_1/code.html`**
  - **Primary**: 56 px high (`h-14`), pill-shaped, with a solid 4-5 px dark-green shelf.
  - **Cards**: a `0 4px 0 #E2D7C5` shelf.
  - **Back**: a round 40 px button.
- **`4._home_skill_tree_dashboard/code.html`**. Raised elements use a solid
  shelf plus a faint soft shadow, e.g.:
  - `0 4px 16px rgba(35,26,17,.08), 0 4px 0 #EDE5D8`
  - `0 6px 0 #124027, 0 12px 24px rgba(0,69,39,.38)` on the START button
- **`highland_pulse/DESIGN.md`**
  - Components 1 to 4
  - Elevation and Depth
  - Typography: Plus Jakarta Sans, and the extra line height Ge'ez needs

**External references** (fetched 2026-09-24):
- **Duolingo's design system** ([open-design DESIGN.md](https://github.com/nexu-io/open-design/blob/main/design-systems/duolingo/DESIGN.md)).
  - What it does:
    - Every interactive element has a hard, solid 4 px lip, darker than its own face.
    - A press moves it down by the lip and collapses the lip.
    - Secondary buttons are white, with a 2 px grey border and a lip the same grey.
    - A button press takes 180 ms.
  - **Taken**: one lip depth for every button, and secondary as white face, border and matching lip.
  - **Not taken**: its 16 px radius, since DESIGN.md asks for pills.
- **Josh Comeau, "Building a Magical 3D Button"** ([joshwcomeau.com](https://www.joshwcomeau.com/animation/3d-button/)).
  - What it does:
    - It presses almost instantly (34 ms).
    - It releases slowly with a slight spring (600 ms, `cubic-bezier(.3,.7,.4,1)`).
    - A soft blurred shadow sits under the solid edge.
    - It shows focus only for keyboard users.
  - **Taken**: a fast press-in and a slower, springy release. The mockups' soft shadow under the shelf.
- **Widgetbook** ([docs: use-cases and knobs](https://docs.widgetbook.io/use-cases/overview)).
  - What it does: one entry per component, one "use case" per variant and state.
  - **Taken**: the gallery is organised by component, with every variant and state shown side by side.
  - **Not taken**: the Widgetbook package itself. A plain Flutter screen is enough, and adds no dependency.

### Deliverables

**1. Tokens (story 001)**
- **`lib/shared/theme/app_colors.dart`: new colours**, each with a comment naming its source:
  - **Answer states**:
    - `answerSelected` `#FFF7ED`
    - `answerCorrect` `#E8F8F0`
    - `answerIncorrect` `#FDF0EE`
    - `optionChosen` `#F0F7F2`
  - **Tiles**: `tileBorder` `#E5DDD0`, `tileShelf` `#D5CCBD`
  - **Nodes**: `lockedNode` `#E8DFD3`, `lockedNodeIcon` `#BAAFA1`, `activeNodeShelf` `#C47318`
  - **Gamification accents**: `streak` `#FF5A1F`, `streakRim` `#FFA726`, `gem` `#10B981`, `xp` `#0EA5E9`
  - **Neutrals**:
    - `textMuted` `#786A5E`
    - `track` `#E2D9CC`
    - `scrim`: `#2B2118` at 45%
    - `shadowInk` `#231A11`, the base for the soft shadows
- **`lib/shared/theme/app_shadows.dart` (new)**:
  - `shelf(color, depth)`: a solid, unblurred shelf.
  - `soft`: `0 4 16` at 8% ink.
  - `card`: a 4 px `cardBevelDefault` shelf plus `soft`.
  - `tile`: a 3 px `tileShelf` shelf plus a fainter soft shadow.
  - `button(bevel)`: a 4 px shelf plus a soft shadow tinted with the bevel colour.
  - `overlay`: `0 16 32 -8` at 16%.
  - `glow(color)`: `0 0 20` at 35%.
  - `none`: for the pressed state.
- **`lib/shared/theme/app_motion.dart` (new)**:
  - `pressIn`: 60 ms, ease-out
  - `pressOut`: 180 ms, ease-out-back, the springy release
  - `state`: 150 ms
  - `shake`: 400 ms
  - `progress`: 400 ms
  - `reduced(context)`: reads the system's reduced-motion setting
- **`AppRadii`**: add `tile = 20` and `card = 24`.
- **Replacing the pasted colours**: every `Color(0x…)` currently in `choice_tile.dart`, `match_pairs_builder.dart`, `skill_path_node.dart` and `selectable_option_card.dart` switches to the matching token. The values are identical, so nothing looks different.

**2. Fonts (story 002)**
- **`assets/fonts/`**:
  - Plus Jakarta Sans at 400, 500, 700 and 800 (static TTFs from `tokotype/PlusJakartaSans`)
  - Noto Sans Ethiopic at 400, 500, 700 and 800 (static unhinted TTFs from `notofonts`)
  - each family's `OFL.txt`
- **Size**:
  - Plus Jakarta Sans: 4 × about 129 KB
  - Noto Sans Ethiopic: 4 × about 290 KB
  - Total: about **1.68 MB** before compression, within the 2 MB budget
- **`pubspec.yaml`**: a `fonts:` section with both families and the four weights of each.
- **`app_typography.dart`**:
  - Every style gets `fontFamilyFallback: [NotoSansEthiopic]`.
  - A new `phonetic` style: `body-sm`, weight 500, `textMuted`.
  - `AppTypography.forText(style, text)`: when the text contains Ethiopic, it returns the style with **+18% line height** (DESIGN.md asks for 15-20%).
- **`app_theme.dart`**: the theme uses the bundled family and its fallback.

**3. Buttons (story 003)**
- **`lib/shared/widgets/tactile_pressable.dart` (new)**: the one press behaviour.
  - It sinks by the shelf depth and flattens the shelf.
  - Pressing in uses `pressIn`, and releasing uses `pressOut`.
  - A drag cancels the press.
  - With reduced motion, it only darkens the face.

  `AppButton`, `AppIconButton` and `TactileButton` all use it, as will `AppCard`, `AnswerTile` and `AudioPlayButton` later.
- **`lib/shared/widgets/app_button.dart` (new)**: `AppButton`, with a named constructor per variant.

  | Variant | Face | Border | Shelf | Text |
  |---|---|---|---|---|
  | `primary` | `primaryContainer` | none | `primaryBevel` | white |
  | `secondary` | white | 2 px, green at 30% | 3 px `tileShelf` | `primary` (as in the mockups) |
  | `accent` | `secondaryContainer` | 2 px `secondary` | `secondary` | `onSecondaryContainer` |
  | `destructive` | `tertiaryBrand` | none | `tertiaryBevel` | white |
  | `text` | none | none | none | `label-md`, `onSurfaceVariant`, no shelf; tap target still at least 48 px |

  Every variant has these options:
  - `leading`, `trailing` or a `trailingBadge` (the "350 Amole" pill)
  - `expand` (fill the width, the default) or hug the content
  - `size`: regular is 56 px high, compact is 48
  - `loading`: shows a spinner in place of the label, keeps the button's size, and ignores taps
  - a `null` `onPressed`, which dims the button to 60% and ignores taps

  Each button reports itself to screen readers as a button with its label.
- **`lib/shared/widgets/app_icon_button.dart` (new)**:
  - a round 40 px face (`surfaceContainer` by default, or a transparent `plain` version) inside a 48 px tap target
  - a required `tooltip`, which is also its screen-reader label
  - it uses the same press behaviour
- **`lib/shared/widgets/tactile_button.dart`**:
  - It keeps its current parameters, so the 23 places that use it don't change.
  - It is rebuilt on `TactilePressable`, so it presses exactly like `AppButton`.
  - Its doc comment says to use `AppButton` for new code. It is removed in bolt 049.

**4. Gallery and rules test (story 004)**
- **`lib/shared/gallery/component_gallery.dart` (new)**: one scrolling page, organised like Widgetbook, with sections for:
  - colours, as swatches with their names
  - shadows, on sample surfaces
  - radii
  - motion, as a press demo
  - type, every style with a Latin and a Fidel sample, plus `phonetic`
  - `AppButton`, every variant: enabled, pressed, disabled, loading, with icons, with a badge, and hug
  - `AppIconButton`
  - `TactileButton`, so the old and new can be compared

  Later bolts add their components here.
- **`lib/gallery_main.dart` (new)**: its own entry point, run with `flutter run -t lib/gallery_main.dart`.
  - The app's real `main.dart` never imports it, so a release build of the app does not contain the gallery.
  - It also refuses to start outside debug mode.
  - It runs on a phone, an emulator, Windows or web.
- **`test/design/design_rules_test.dart` (new)**: scans `lib/` with comments removed.
  - **Exempt folders**: `lib/shared/theme/` is exempt from every rule; `lib/shared/widgets/` and `lib/shared/gallery/` from every rule except the colour rule.
  - **The rules:**
    - **R1**: a `Color(0x`
    - **R2**: a `BoxShadow(`
    - **R3**: a `BorderRadius.circular(` or `Border.all(`
    - **R4**: a `TextButton`, `ElevatedButton`, `FilledButton`, `OutlinedButton` or `IconButton`
    - **R5**: `showModalBottomSheet` or `showDialog`
    - **R6**: a `Scaffold(` or `AppBar(`
    - **R7**: a `LinearProgressIndicator` or `CircularProgressIndicator`
  - **Allow-list**: it maps each not-yet-migrated file to the exact rules it may still break.
    - A new file, or a rule not listed for its file, fails the test.
    - An entry that no longer matches anything also fails, so the list can only shrink.
  - **Starting state**:
    - R1 is empty, because step 1 removes every pasted colour.
    - The other rules list the 22 files that break them today (all of `lib/features/` plus `lib/shared/screens/home_placeholder_screen.dart`).
- **Tests (new)**:
  - `test/design/component_gallery_test.dart`: builds the whole gallery at 360×640 and 430×932, at 1.0× and 1.3× text, with no overflow.
  - `test/shared/theme/`: token tests.
  - `test/shared/widgets/`: `AppButton`, `AppIconButton` and `TactilePressable` tests.
  - A font test checking that the files exist, are declared, and have their licences.

### Dependencies
- **No new packages.**
- **Font files** are downloaded once from the official repositories (SIL OFL 1.1) and committed with their licences.
- **Bolt 043** builds on `TactilePressable`, `AppShadows` and the gallery.

### Technical Approach
- **One press behaviour**:
  - `TactilePressable` owns the pressed state and draws the shelf as a `BoxShadow`.
  - It moves the face with a transform and keeps the layout's height fixed, so neighbours never shift. (Today's `TactileButton` does this with a margin, and some tests rely on its size.)
  - It lives only in `lib/shared/widgets/`, so R2 and R3 stay satisfied.
- **Choosing the variant**:
  - Each variant is a private style record (face, border, shelf, text colour) chosen by the named constructor.
  - No caller passes colours, so each kind of action can only look one way.
  - `TactileButton` alone still takes colours, until bolt 049.
- **Secondary style: the mockups over DESIGN.md.**
  - Both mockups that show a secondary button use a white face, a green-tinted border and a neutral shelf.
  - DESIGN.md's gold secondary appears in no mockup.
  - The mockups win (Checkpoint 1: follow the mockups). Having one secondary style keeps pages from differing.
- **Ethiopic line height**:
  - Detect Ethiopic by Unicode ranges: `U+1200–139F`, `U+2D80–2DDF` and `U+AB00–AB2F`.
  - Screens call `AppTypography.forText` when they show learner content. The kit calls it automatically from bolt 044.
- **Analysis baseline**: `flutter analyze` reports **13 existing infos** today, none of them in the files this bolt touches. This bolt adds none, so NFR-5's "0 issues" is read as "no new issues".
- **Test baseline**: 531 pass, and 7 fail today, all in `test/shared/services/http_auth_api_e2e_test.dart`. That file needs a backend running on `localhost:8000`, and nothing answers there right now. "The full suite passes" is therefore measured as: all 531 still pass, plus the new tests. The 7 end-to-end tests pass once the backend is up.

### Acceptance Criteria
- [ ] Every FR-1 colour, shadow, radius and motion value exists as a named token, with its source in a comment.
- [ ] No `Color(0x…)` exists outside `lib/shared/theme/`: R1 passes with an empty allow-list.
- [ ] Both fonts are bundled, at four weights each with their licences, and add at most 2 MB.
- [ ] Every text style falls back to Noto Sans Ethiopic.
- [ ] `forText` adds line height for Ethiopic text only.
- [ ] `AppButton`'s five variants match the references.
- [ ] Every tactile button presses and releases through `TactilePressable`, with no movement under reduced motion.
- [ ] Disabled and loading buttons ignore taps, and loading does not change the button's size.
- [ ] Every button and icon button is at least 48×48 and reports itself as a button with a label.
- [ ] `TactileButton` keeps its current parameters, and every existing test that uses it passes unchanged.
- [ ] The gallery shows every token and every button state, starts only in debug mode, and is not reachable from the app.
- [ ] The gallery test shows no overflow at 360 and 430 px wide, at 1.0× and 1.3× text.
- [ ] The rules test passes. Its allow-list holds exactly today's violations outside R1, and fails on any new one.
- [ ] `flutter analyze` reports no new issues, and the full Flutter suite passes.
