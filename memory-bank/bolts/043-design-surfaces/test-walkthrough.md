---
stage: test
bolt: 043-design-surfaces
created: '2026-09-24T16:19:02Z'
---

## Test Report: design-foundation-ui

### Summary

- **Tests**: 716/723 passed. This bolt adds 106 tests, and all of them pass. The 7 failures are the same end-to-end tests in `test/shared/services/http_auth_api_e2e_test.dart` that also failed before this bolt. They need a backend on `localhost:8000`, and nothing was running there.
- **Coverage**: not measured.
- **Mutation check**: each new test file was checked by making 37 deliberate breakages to the library, one at a time. After the tests were strengthened, all 37 are caught. See Issues Found.
- **`flutter analyze`**: the same 13 existing infos as before the bolt, none in new files.

### Test Files

- [x] `test/shared/widgets/app_page_test.dart` (18): `AppPage`, `AppBackground`, `AppTopBar` and `TibebStripe`.
  - **Page:** margins, background and scrolling come for free; screens can opt out of scrolling and margins.
  - **Dock:** its position and 8 px gaps; the last line of content scrolls clear of it; it rides above the keyboard.
  - **Short phone:** a 360×640 page at 1.3× text.
  - **Stripes:** the footer stripe's size and position; the gradient's colours; the woven painter's four bands.
  - **Backgrounds:** the lattice sits in a layer of its own and doesn't repaint when the page scrolls or a button on it animates; the glow is painted; painted backgrounds are hidden from screen readers.
  - **Top bar:** its icon button lines up with the 20 px margin; the title is centred and read as a heading; the wordmark; crowded stat pills shrink at 320 px and 1.3× text.
- [x] `test/shared/widgets/app_card_test.dart` (29, 31 with the tone loop):
  - **Tones:** the mockup values; every tone's shelf is darker than its border.
  - **`AppCard`:**
    - the face, border, radius and shadow
    - space kept for the shelf
    - each tone tints only the border and shelf
    - the stripe sits inside the border
    - content padding of 16, 12 or 0 px inside the border, tappable or not
    - a read-only card has no press and no button role
    - a tappable card sinks, flattens its shelf and is one button
    - a selected card's border, face and selected state
    - an unavailable choice is a disabled button
    - the face stays white on a tinted parent
  - **`StatCard`:** its content; it fills its slot; the ribbon is centred on the top edge but stays inside the stat card's own box; cards line up with or without a ribbon; it reads as one phrase.
  - **`InfoBanner`:** its shape and screen-reader label; emphasis.
  - **`ListRow`:** minimum heights; the chevron and button role when tappable; darkening while pressed; a custom trailing widget.
  - **`ListRowGroup`:** dividers, indented to where the text starts.
  - **`SectionHeader`:** read as a heading.
  - **`SelectableOptionCard`:** neutral, selected and disabled states and their semantics; the shared press.
- [x] `test/shared/widgets/app_sheet_test.dart` (20):
  - **`showAppSheet`:**
    - the surface, radius, shadow, handle and warm backdrop
    - the popped value comes back, and a backdrop tap or back returns `null`
    - a non-dismissible sheet stays open, and has no handle when it can't be dragged
    - a sheet taller than a 360×640 screen at 1.3× text scrolls under a finger drag to its last action
    - with the keyboard open, the scrolling area and the actions stay above it
  - **`showAppDialog`:** the card's colours, shelf and backdrop; the value; `null` from the close button, a backdrop tap or back; a tall dialog scrolls under a finger drag.
  - **`showAppConfirmDialog`:** `true`, `false` or `null`, no close button, and a destructive button only when asked.
  - **`SheetHero`:** the order and 8 px action spacing; the title's tone colour and the bracketed phonetic; the title is a heading, the badge is read aloud, the circle is not; the tone halo.
- [x] `test/shared/widgets/app_status_test.dart` (26, 32 with loops):
  - **Digit grouping:** including negative numbers.
  - **`StatPill`:** for all four kinds, today's screen-reader wording and the icon colour; the translucent face and tinted border; grouped numbers fit at 1.3× text; `heightOf` matches the rendered height at 1.0×, 1.3× and 2.0×.
  - **Badges:** both `CountBadge` looks; `RibbonBadge`'s fill and height at 1.0× and 1.3×.
  - **`AppProgressBar`:**
    - the fill takes its share of the sunken track
    - the large size
    - an empty track still spans the full width, even in a centring parent
    - a sliver is still round, and values past full are clamped
    - it eases over `AppMotion.progress` and settles, and jumps under reduced motion
    - the tone gradient
    - its label, percentage and caption row
  - **`IconBadge`:** the circle and square shapes, tone colours, size, and hidden from screen readers.
  - **`AppSpinner`:** its colour and size; `AppButton` uses it while loading.
  - **`EmptyState`:** its content.
  - **`ErrorState`:** "Try again" when it can retry, no button when it can't.
  - **`LoadingState`:** it spins and announces itself; `still` settles; reduced motion holds it still.
  - **Short slot:** the states fit a short slot at 1.3× text.
- [x] `test/design/component_gallery_test.dart` (+5): opens each sheet and dialog from the gallery at 360×640 with 1.3× text, with no layout errors. It reaches the last action with a drag, taps it, and checks the gallery shows the returned value. The existing four whole-gallery tests now also cover every new section.
- [x] `test/design/design_rules_test.dart`: unchanged, and passing. The allow-list is still 64 entries across 23 files, and nothing new was allowed.

### Acceptance Criteria Validation

**Story 005: page shell**
- ✅ **Background, safe area, margins and scrolling come for free**: `app_page_test`.
- ✅ **The lattice paints once and never repaints when the page scrolls or a button animates**: `app_page_test`, which checks the render layer directly.
- ✅ **The celebration glow sits behind the hero area**: `app_page_test`, and checked on screen.
- ✅ **The top bar lines up with the page margins**: `app_page_test`.
- ✅ **The dock**:
  - it is pinned above the safe area and the keyboard
  - there are 8 px between its buttons
  - the last content line scrolls clear of it

  All three are in `app_page_test`.
- ✅ **The woven footer stripe**: `app_page_test`.
- ✅ **At 360×640 with 1.3× text, content scrolls and the dock stays visible**: `app_page_test`.

**Story 006: cards**
- ✅ **White face, 2 px border, 24 px radius, card shadow**: `app_card_test`.
- ✅ **A tone tints only the border and shelf**: `app_card_test`.
- ✅ **The top stripe**: `app_card_test`.
- ✅ **A tappable card presses and is a button**: `app_card_test`.
- ✅ **`StatCard`, `InfoBanner`, `ListRow`, `ListRowGroup`, `SectionHeader`**: `app_card_test`, the gallery, and checked on screen.
- ✅ **`SelectableOptionCard` on `AppCard`**: `app_card_test`. The language, daily-goal and settings screen tests pass unchanged.

**Story 007: sheets and dialogs**
- ✅ **The sheet's surface, radius, handle, backdrop and shadow**: `app_sheet_test`.
- ✅ **The dialog's card, backdrop and radius, using `SheetHero`**: `app_sheet_test`.
- ✅ **A destructive primary when asked**: `app_sheet_test`.
- ✅ **`SheetHero`'s layout and spacing**: `app_sheet_test`, and checked on screen.
- ✅ **A tall sheet at 1.3× text scrolls, and its actions can be reached**: `app_sheet_test` and `component_gallery_test`.
- ✅ **Return values match `showModalBottomSheet` and `showDialog`, including `null`**: `app_sheet_test`.

**Story 008: status pieces**
- ✅ **`StatPill` for all four kinds, with today's screen-reader labels**: `app_status_test`.
- ✅ **"12,340" fits at 1.3× text**: `app_status_test`.
- ✅ **`CountBadge` and `RibbonBadge`**: `app_status_test`.
- ✅ **`AppProgressBar`'s track, fill, gradient, label and easing, and it settles**: `app_status_test`.
- ✅ **Empty, error and loading states, with badge, title, text and action**: `app_status_test`.
- ✅ **`LoadingState.still` lets `pumpAndSettle` finish**: `app_status_test`.
- ✅ **`InfoBanner` shows every sync state**: the gallery, and checked on screen.

**Whole bolt**
- ✅ **The gallery shows every new component and state with no overflow**: at 360×640 and 430×932, at 1.0× and 1.3× text, with every sheet and dialog opened.
- ✅ **The rules test passes, with the allow-list at 64 entries**.
- ✅ **`flutter analyze` is unchanged, and the suite passes** apart from the 7 end-to-end tests that need a backend.

### Issues Found

**Three bugs in the library, fixed in this stage:**
1. **A read-only card's content sat on top of its 2 px border.** A `DecoratedBox` doesn't inset its child by the border, as the pressable card's `Container` does. That put the top stripe over the border line, and text 2 px closer to the edge than on a tappable card. The content is now inset by the border.
2. **With the keyboard open, a sheet's last actions were hidden behind it.** The keyboard height was added as padding inside the scroll view, so the scrolling area still ran under the keyboard. The keyboard now shrinks the scrolling area instead.
3. **A barely-started progress bar collapsed to a dot.** Its minimum width couldn't override the exact width the fractional box imposed. The fill width is now worked out directly.

**Five gaps in the tests, found by the mutation check and closed:**
- **Lattice repaint:** scrolling never repaints the lattice anyway, because the scroll view is its own repaint boundary, and the nearest boundary above didn't repaint for a button press either. The test now presses a docked button too, and checks directly that the lattice is painted into a layer of its own.
- **Ribbon room:** the row-alignment test couldn't notice both cards losing the room equally. It now also checks the ribbon stays inside the stat card's own bounds.
- **Tall sheet:** the tests used a programmatic scroll, which works even when a finger can't scroll. They now drag.
- **Empty progress bar:** the test's parent stretched the bar. It now also uses a centring parent, which is where the collapse happened.
- **Page title:** one breakage's search text had the wrong indentation, so that breakage never ran. With the text fixed it runs and is caught.

**Gallery tests:** the gallery shows spinners on purpose, so it never settles. Its sheet tests wait out the route transition instead of waiting for everything to stop.

### Notes

- **Checked by eye.** The whole gallery and each opened sheet and dialog were rendered with the real fonts, and the fixes above were seen on screen. The throwaway test used for this is not in the repo.
- **Still to check on a phone** (bolt 049): the sheet's drag and backdrop on a real Android and iPhone, and the lattice's actual raster cost.
