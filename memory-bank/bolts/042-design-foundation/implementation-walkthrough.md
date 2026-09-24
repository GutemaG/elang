---
stage: implement
bolt: 042-design-foundation
created: '2026-09-24T13:30:00Z'
---

## Implementation Walkthrough: design-foundation-ui

### Summary

The design library now has:
- every colour, shadow, radius and motion token
- both bundled fonts, with Fidel falling back to Noto Sans Ethiopic
- one press behaviour shared by everything tactile
- `AppButton` in five variants, and `AppIconButton`
- a debug-only gallery
- a rules test that stops any file outside the library from drawing its own
  decoration

Screens are unchanged, apart from rendering in the bundled fonts and pressing
with the new spring.

### Structure Overview

**Tokens** live in `lib/shared/theme/`. **Components** live in
`lib/shared/widgets/` and are built only from tokens. **`TactilePressable`**
sits under every tactile component: it holds the pressed state, the sink
and the spring back, and the shelf. The variants differ only in their
colours.

**The gallery** lives in `lib/shared/gallery/` and has its own entry point.
The app's `main.dart` never imports it.

**The rules test** in `test/design/` scans `lib/`:
- The library folders are exempt.
- Files that haven't been converted yet sit on a per-file, per-rule
  allow-list.
- The allow-list can only shrink.

### Completed Work

- [x] `lib/shared/theme/app_colors.dart`: 20 new colour tokens, each
  commented with its DESIGN.md or mockup source:
  - answer states and the chosen option
  - tile border and shelf
  - node colours
  - streak, gem and XP accents
  - muted text, track, backdrop, shadow ink
- [x] `lib/shared/theme/app_shadows.dart` (new):
  - shelf, soft, card, tile and button shadows. The button shadow follows
    how far the button is pressed.
  - overlay and glow, plus `none` for the pressed state
- [x] `lib/shared/theme/app_motion.dart` (new): press-in, press-out (spring),
  state, shake and progress timings, and the system's reduced-motion
  setting.
- [x] `lib/shared/theme/app_spacing.dart`: `AppRadii.tile` (20) and
  `AppRadii.card` (24).
- [x] `lib/shared/theme/app_typography.dart`:
  - The bundled family, with Noto Sans Ethiopic as every style's
    fallback.
  - A new `phonetic` style.
  - Ethiopic detection, and `forText`, which adds 18% line height to
    Fidel text.
- [x] `lib/shared/theme/app_theme.dart`: the theme uses the bundled family
  and its fallback.
- [x] `assets/fonts/PlusJakartaSans/` and `assets/fonts/NotoSansEthiopic/`
  (new): four static weights each (400, 500, 700 and 800), with each
  family's `OFL.txt`.
- [x] `pubspec.yaml`: a `fonts:` section declaring both families and their
  weights.
- [x] `lib/shared/widgets/tactile_pressable.dart` (new): the shared press
  behaviour.
  - Pressing sinks the face and flattens the shelf in 60 ms. Releasing
    springs back slightly past rest.
  - The shelf's space is reserved, so pressing never moves anything
    around it.
  - A drag cancels the press.
  - With reduced motion, the face only darkens.
- [x] `lib/shared/widgets/app_button.dart` (new): `AppButton`.
  - **Variants**: primary, secondary, accent, destructive and a text link.
  - **Options**: leading and trailing icons, an `AppButtonBadge` price
    pill, expand or hug, regular or compact size.
  - **States**: loading shows a spinner at the same size and ignores taps;
    a missing `onPressed` dims the button and ignores taps.
  - **Tap target**: at least 48 px.
  - **Screen readers**: one button node with the label.
- [x] `lib/shared/widgets/app_icon_button.dart` (new):
  - a round 40 px icon action inside a 48 px target
  - an optional plain version with no surface
  - a required tooltip, which is also its screen-reader label
- [x] `lib/shared/widgets/tactile_button.dart`: rebuilt on
  `TactilePressable` with the same parameters, so its 23 uses are
  untouched. It is marked for replacement by `AppButton`.
- [x] `lib/shared/widgets/selectable_option_card.dart`,
  `lib/features/lesson/widgets/choice_tile.dart`,
  `match_pairs_builder.dart` and `skill_path_node.dart`: their pasted hex
  colours now read the matching tokens. The values are identical.
- [x] `lib/shared/gallery/component_gallery.dart` (new): the gallery app,
  with one section per token group and component, and every variant and
  state labelled:
  - colours, shadows, radii and motion
  - type, with Latin and Fidel samples plus `phonetic`
  - `AppButton`, `AppIconButton`, and the legacy `TactileButton` for
    comparison

  It also provides `GallerySection` and `GalleryCase` for later bolts to
  add to.
- [x] `lib/gallery_main.dart` (new): starts the gallery with
  `flutter run -t lib/gallery_main.dart`. It refuses to start outside a
  debug build.
- [x] `test/design/design_rules_test.dart` (new): **the rules test**.
  - **The seven rules**: colour literal, `BoxShadow`, radius or border,
    Material button, raw sheet or dialog, `Scaffold`/`AppBar`, raw
    progress indicator.
  - **Comments are ignored.**
  - **The allow-list**:
    - It starts with 64 entries across 23 files.
    - The colour rule's list is empty and must stay empty.
    - An entry that is no longer needed fails the test.
- [x] `test/design/component_gallery_test.dart` (new): builds the whole
  gallery at 360×640 and 430×932, at 1.0× and 1.3× text, and checks there
  is no overflow.

### Key Decisions

- **One shared press behaviour for every tactile component.** Buttons now,
  cards and answer tiles later, all press and spring the same way. That is
  the "feel" half of consistency.
- **The release spring is the press curve played backwards**
  (`easeOutBack.flipped`), so the face briefly lifts past rest. Only the
  movement and shelf overshoot; the soft shadow's strength is capped.
- **Variants fix their colours.** Only the legacy `TactileButton` still
  accepts colours. That stops screens drifting apart again.
- **The gallery is a separate entry point, not a hidden route.** It
  can't appear in the app at all, and it runs on a phone, an emulator,
  Windows or web.
- **Every button variant takes the same total height.** The secondary
  button's shallower (3 px) shelf gets 1 px of padding, so buttons side by
  side line up.

### Deviations from Plan

- **The allow-list covers 23 files, not 22.** The plan counted 22 files in
  `lib/features/` and then counted the home placeholder among them. It is
  22 plus the placeholder. The list was generated from the tree, not by
  hand.
- **`TactileButton` now draws the same shelf plus soft glow as
  `AppButton`**, where it used to draw only the shelf. That is a small
  visual change on current screens, in line with the plan's "presses
  exactly like `AppButton`".
- **The component tests the plan listed** (tokens, typography, fonts,
  buttons, `TactilePressable`) are written in Stage 3. The gallery and
  rules tests were needed here to check the work.

### Dependencies Added

- [x] Font assets only: Plus Jakarta Sans (tokotype) and Noto Sans Ethiopic
  (notofonts), both SIL OFL 1.1, 1.68 MB before compression. No new
  packages.

### Developer Notes

**Checked by eye.** The whole gallery was rendered with the real fonts in a
throwaway test and inspected.
- The buttons match the out-of-beans and lesson-complete mockups: the
  shelves, the white secondary with its green-tinted border, the gold
  accent with its price badge, and the muted "Not now".
- Fidel renders in Noto Sans Ethiopic with no clipping.
- The throwaway test was removed.

**Rules test.** When a later bolt converts a screen, delete that file's
entries from `_notYetMigrated`. The test fails until you do.

**Suite.** 541 tests pass: the 531 from before, plus 10 new design tests.
The same 7 end-to-end tests still fail because nothing is answering on
`localhost:8000`. `flutter analyze` shows the same 13 infos as before, and
none are in new files.
