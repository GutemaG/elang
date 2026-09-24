---
stage: test
bolt: 042-design-foundation
created: '2026-09-24T14:03:00Z'
---

## Test Report: design-foundation-ui

### Summary

- **Tests**: 610 pass, which is the 531 from before plus 79 new ones.
  - The same 7 end-to-end tests fail as before this bolt, all in
    `http_auth_api_e2e_test.dart`. They need a backend on
    `localhost:8000`, and nothing was running there.
- **Analysis**: `flutter analyze` shows the same 13 infos as before, none
  in new or changed files.
- **Falsification**: 20 deliberate breakages. Every one was caught, and
  each source file was restored byte for byte.
- **Coverage**: no percentage target, per the coding standards. Every new
  token, component and rule has tests.

### Test Files

- [x] `test/shared/theme/design_tokens_test.dart` (16): tokens and typography.
  - Every colour added by 018 matches DESIGN.md and the mockups, and the
    backdrop is the warm tone at 45%.
  - The tile radius is 20 and the card radius is 24.
  - **Shadows**:
    - A shelf is a solid, unblurred offset.
    - A card is a 4 px bevel shelf plus a soft shadow.
    - A tile is a 3 px tile shelf.
    - A button's shelf flattens as it is pressed, and fully pressed
      leaves no shadow.
    - While springing back, the shelf overshoots but the glow stays
      capped.
    - Overlay and glow blurs match DESIGN.md.
  - **Motion**: press-in is faster than press-out, and reduced motion is
    read from the system.
  - **Type**:
    - All 12 styles use Plus Jakarta Sans with the Noto Sans Ethiopic
      fallback.
    - `phonetic` is muted `body-sm` at weight 500.
    - Ethiopic is detected in all four Ethiopic blocks and in nothing
      else.
    - `forText` adds 18% line height only when the text has Fidel.
    - The app theme uses the bundled family.
- [x] `test/shared/theme/bundled_fonts_test.dart` (7): for each family,
  `pubspec.yaml` declares weights 400, 500, 700 and 800, and each one is a
  real TrueType file with its OFL licence. Together they come to at most
  2 MB.
- [x] `test/shared/widgets/app_button_test.dart` (46)
  - **Every variant**, including compact and the text link:
    - A tap calls the button.
    - Disabled ignores taps and dims to 60%.
    - The tap target is at least 48×48.
    - Screen readers get one enabled button with its label.
  - **Looks**:
    - Each tactile variant has its own face colour; the text link has no
      face.
    - Primary, secondary and accent are the same height (56 + 4).
    - The badge sits at the right edge.
    - Hug and expand widths work.
  - **Loading**: shows a spinner, keeps the button's size, ignores taps,
    and isn't dimmed.
  - **Pressing**:
    - It sinks 4 px while held and springs slightly past rest on release.
    - Its size never changes.
    - Sliding the finger away cancels the tap.
    - With reduced motion it only darkens.
    - A disabled button never sinks.
  - **`AppIconButton`**: a 48×48 target around a 40 px face; read as a
    button named by its tooltip; taps; disabled; the plain version has
    no surface.
  - **`TactileButton`**: still a 56 px face on a 4 px shelf, presses like
    `AppButton`, and still takes the colours a screen passes.
- [x] `test/design/design_rules_test.dart` (6)
  - No file breaks a rule that its allow-list entry doesn't cover.
  - Every allow-list entry is still needed.
  - No colour literal is allowed anywhere outside the theme.
  - Each rule catches the thing it names.
  - Comments don't count, and line numbers are kept.
  - The library is exempt; the theme is exempt from everything.
- [x] `test/design/component_gallery_test.dart` (4): the whole gallery
  builds with no overflow at 360×640 and 430×932, at 1.0× and 1.3× text.

### Falsification

Each breakage was applied, its tests were run, and the source was restored:

| Breakage | Tests failing |
|---|---|
| A token drifts from DESIGN.md | 1 |
| A shelf gets blurred | 3 |
| One style loses the Ethiopic fallback | 2 |
| Fidel gets no extra line height | 1 |
| A font weight is declared wrong in `pubspec.yaml` | 1 |
| Reduced motion is ignored | 1 |
| No spring past rest | 1 |
| The shelf's space is not reserved | 3 |
| A press is not cancelled by sliding away | 1 |
| A loading button still takes taps | 1 |
| A loading button is dimmed like a disabled one | 1 |
| The text link's tap target shrinks | 1 |
| Buttons are not announced as buttons | 6 |
| Bordered buttons grow taller | 1 |
| A button stretches to fill its parent | 1 |
| A variant takes another variant's colour | 1 |
| The icon button's target shrinks | 1 |
| A screen pastes a colour literal | 1 |
| A screen is converted but left on the allow-list | 1 |
| A gallery component overflows | 4 |

**One breakage was replaced.** The first gallery breakage, a wider colour
swatch, didn't count. Inside a `Wrap` a swatch is squeezed to fit, so
nothing actually overflowed. It was replaced by a real overflow, a
too-wide gap in a `Row`, which all four sizes caught.

### Acceptance Criteria Validation

- ✅ **Every FR-1 colour, shadow, radius and motion value is a named token
  with its source**: the token tests.
- ✅ **No `Color(0x…)` outside `lib/shared/theme/`, and R1's allow-list is
  empty**: the rules tests.
- ✅ **Both fonts are bundled at four weights with their licences, within
  2 MB**: the font tests. The fonts total 1.68 MB before compression.
- ✅ **Every style falls back to Noto Sans Ethiopic, and `forText` adds
  line height for Ethiopic only**: the typography tests.
- ✅ **`AppButton`'s five variants match the references**: the face-colour
  tests, plus the by-eye comparison in the implementation walkthrough.
- ✅ **Every tactile button presses and releases through
  `TactilePressable`, with no movement under reduced motion**: the
  pressing tests, including `TactileButton`'s.
- ✅ **Disabled and loading buttons ignore taps, and loading keeps the
  button's size**: the disabled and loading tests.
- ✅ **Tap targets are at least 48×48, and each button reads as a button
  with its label**: the size and semantics tests.
- ✅ **`TactileButton` keeps its parameters, and existing tests pass
  unchanged**: all 531 earlier tests pass, and no existing test was
  edited.
- ✅ **The gallery shows every token and button state, starts only in
  debug, and can't be reached from the app**: `gallery_main.dart`
  refuses non-debug builds, and nothing in `main.dart` imports the
  gallery.
- ✅ **The gallery has no overflow at 360 and 430 px, at 1.0× and 1.3×
  text**: the gallery tests.
- ✅ **The rules test holds today's violations and fails on new ones**: the
  rules tests, and the last two falsification rows.
- ✅ **No new analyzer issues, and the full suite passes**: see the
  Summary.

**Story 002's criteria needing a real device:** Fidel without clipping at
1.3× on Android and iPhone, and the APK size before and after. These are
left for bolt 049's on-device sweep. The gallery rendering with the real
fonts showed no clipping at 1.0×.

### Issues Found

The new tests found two real bugs, both fixed in `app_button.dart`:

- **A button stretched to the full height of its parent** when that parent
  had a fixed height. The label's `Center` had no height factor. Inside a
  `Column` this never shows, but inside a sheet or a sized box it would
  have.
- **Bordered variants were 4 px taller than the rest.** Secondary and
  accent put the border outside the 56 px minimum height. The minimum now
  subtracts the border, so every variant is 56 + 4.

One process slip:

- **A `dart format` run on the whole `lib/shared` and `test/shared`
  folders reformatted 18 files this bolt doesn't touch.** It was caught
  in `git status`, and those files were restored with `git checkout`.
  Every diff was formatting only. From now on, only files this bolt
  creates or edits are formatted.

### Notes

- **Viewing the gallery**: `flutter run -t lib/gallery_main.dart` on a
  phone, emulator, Windows or Chrome.
- **Test timing**: a press starts only after Flutter's 100 ms tap-down
  delay, and the animation's first frame comes one pump later. The tests
  hold a press with a small `_hold` helper that accounts for both.
