---
stage: implement
bolt: 043-design-surfaces
created: '2026-09-24T14:36:58Z'
---

## Implementation Walkthrough: design-foundation-ui

### Summary

The design library is complete. It now has:
- the page shell, with its three backgrounds, top bar, dock and Tibeb stripes
- cards and everything built on them
- the shared sheet, dialog and yes/no confirmation, laid out by `SheetHero`
- the status pieces: pills, badges, progress bar, icon badges, spinner, and empty, error and loading states

All of them are in the gallery. The only existing widget that changed is `SelectableOptionCard`, now built on `AppCard`. No screen has moved onto the library yet.

### Structure Overview

**Tones.** A new tone table in the theme gives every toned piece its colours: the neutral, primary, secondary and tertiary border, shelf, icon surface, icon, ink, fill and selected face. Cards, stat cards, banners, badges, icon badges, progress fills and sheet titles all read from it.

**The widgets.** Four new library files, grouped by story:
- the page shell
- cards
- sheets and dialogs
- status pieces

Each is built only from tokens, `TactilePressable` and `AppButton`.

**The gallery.**
- It now sits on `AppPage` itself.
- It is split into the original file plus one file per new group.
- Page shells are shown inside framed phones.

### Completed Work

- [x] `lib/shared/theme/app_tone.dart` (new): the four tones and the eight colours each one supplies.
- [x] `lib/shared/theme/app_colors.dart`: eight tone colours, each commented with its lesson-complete source; the tinted shelves are derived and say so. Also the dialog shelf from the level-up mockup.
- [x] `lib/shared/theme/app_shadows.dart`:
  - `raised`: a card on any tone's shelf, which flattens as the card is pressed
  - `badge`: the 2 px shelf under "3/5 Completed"
  - `dialog`: the level-up card's deep shelf and shadow
  - `halo`: the pastel glow behind a sheet's illustration
- [x] `lib/shared/widgets/app_page.dart` (new):
  - **`AppPage`**: background, safe area, margins, scrolling, an optional top bar, a dock of actions with a fade above it, and an optional footer stripe. It is the only `Scaffold` in the library.
  - **`AppTopBar`**: in a titled version and the "Buna" wordmark version.
  - **`AppBackground`**: plain, patterned lattice, or celebration glow. The painters never ask to repaint.
  - **`TibebStripe`**: woven and gradient.
- [x] `lib/shared/widgets/app_card.dart` (new): `AppCard` (tone, top stripe, tap with the shared press, selected state, three paddings), `StatCard` with its ribbon, `InfoBanner`, `ListRow`, `ListRowGroup` and `SectionHeader`.
- [x] `lib/shared/widgets/app_sheet.dart` (new):
  - `showAppSheet`, `showAppDialog` and `showAppConfirmDialog`
  - the two frames they draw, `AppSheetFrame` and `AppDialogFrame`
  - `SheetHero`
- [x] `lib/shared/widgets/app_status.dart` (new):
  - `StatPill` for four kinds, with its height helper for pinned headers
  - digit grouping ("12,340")
  - `CountBadge` and `RibbonBadge`
  - `AppProgressBar`, which eases to a new value and settles
  - `IconBadge` and `AppSpinner`
  - `EmptyState`, `ErrorState`, `LoadingState` and `LoadingState.still`
- [x] `lib/shared/widgets/selectable_option_card.dart`: rebuilt on `AppCard`.
  - Same constructor, badge, indicator and three states.
  - A chosen option takes the primary tone.
  - An unchosen option is neutral.
  - A disabled one is dimmed, with the lock showing.
- [x] `lib/shared/widgets/app_button.dart`: its loading spinner is now `AppSpinner`.
- [x] `lib/shared/gallery/component_gallery.dart`: the gallery page is built on `AppPage`, the new colours and shadows appear in their sections, and the four new sections are listed.
- [x] `lib/shared/gallery/gallery_surfaces.dart` (new): three framed page shells, the stripes, cards in every tone and state, stat cards, the accuracy card, the daily-goal banner, a section header, a row group and the option cards.
- [x] `lib/shared/gallery/gallery_sheets.dart` (new):
  - `SheetHero` inline, rebuilt as the out-of-beans sheet
  - five buttons that open the beans sheet, a leave sheet, a sheet taller than the screen, the level-up dialog and a destructive confirmation
  - a line showing what the last one returned
- [x] `lib/shared/gallery/gallery_status.dart` (new):
  - all four pills, both badges, and a progress bar you can tap to move
  - edge-case bars
  - icon badges in every tone, and spinners
  - every sync message as an `InfoBanner`
  - the empty, error and both loading states

### Key Decisions

- **Tones are one table.** Every toned piece takes a tone, never a colour, so a green card and a green badge can't drift apart.
- **A card doesn't press unless it is tappable.** A read-only card is a plain surface, with no gesture handler or animation. A tappable one uses the same press as buttons, flattening its shelf.
- **Choices report their state to screen readers.** A card given `selected` is one button node that says whether it is chosen, and says it is disabled when it can't be tapped. That keeps `SelectableOptionCard` reading as it did.
- **Sheets and dialogs wrap Flutter's own routes.** They use `showModalBottomSheet` and `showDialog` underneath and draw their own surface. So dismissal, back, drag and return values are Flutter's, unchanged.
- **The sheet handle is a 32×4 bar with no tap area of its own.** A sheet can be dragged from anywhere, so the 48 px Material handle area would only add empty space above the illustration.
- **`StatCard` always leaves room for half a ribbon above itself.** A row of stat cards stays aligned whichever card has the ribbon.
- **The illustration halo uses the tone's pastel border colour, not the icon colour.** Tested first as a 35 % icon-colour glow, it was invisible against cream. The pastel halo matches the out-of-beans mockup's vignette.

### Deviations from Plan

- **`AppShadows.halo` was added**, which the plan didn't list. It was needed for the reason above.
- **The top bar takes a list of trailing actions**, and **`bottomDock` is a list of actions**, not a single widget. That is how the dock guarantees the same 8 px spacing on every screen.
- **The tall-sheet demo fits on a desktop-height window.** It is taller than a 360×640 phone, which is where the Stage 3 test opens it.
- **The component tests are written in Stage 3**, as in bolt 042. The existing gallery test already builds every new piece at both sizes and both text scales, and passes.

### Dependencies Added

- [x] None.

### Developer Notes

**Checked by eye.** The whole gallery and each opened sheet and dialog were rendered with the real fonts in a throwaway test and inspected. The test was then removed. Five problems were found and fixed:
- stat cards hugged their content instead of filling their column
- an empty progress bar collapsed to its padding
- unselected option cards had a green border
- the illustration glow was invisible
- the gallery's tall-sheet list hugged its content

**`AppCard` sizes to the width its parent gives it.** In a centred `Column` it hugs its content, so give it a stretched parent (as `SheetHero` does) or a `SizedBox`.

**`LoadingState` spins forever.** Use `LoadingState.still()` wherever a test pumps until settled, such as under a sheet.

**No change to the rules test.** Everything new lives in `lib/shared/`. The allow-list is still 64 entries, and the test passes.

**Suite.** 610 pass. The same 7 end-to-end tests fail because nothing is answering on `localhost:8000`. `flutter analyze` shows the same 13 existing infos.
