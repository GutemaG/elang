---
stage: plan
bolt: 043-design-surfaces
created: '2026-09-24T14:18:50Z'
---

## Implementation Plan: design-foundation-ui

### Objective

Finish the design library. This bolt adds:
- `AppPage`, with its three backgrounds, top bar, bottom dock and Tibeb
  footer stripe
- `AppCard` and the family built on it
- the shared sheet and dialog, and `SheetHero`
- the status pieces: pills, badges, progress bar, and empty, error and
  loading states

Every new piece appears in the gallery.

**Only one existing widget changes:** `SelectableOptionCard` is rebuilt on
`AppCard`. That changes the language, daily-goal and settings option cards
slightly: they get the card shelf and the shared press.

Every other screen still draws its own decoration. Screens move over in
bolts 045 to 049, so the rules test's allow-list stays at 64 entries.

### Reference designs (FR-11)

**Stitch mockups**, in `stich-screens/extracted/stitch_ethiopian_language_learning_app/`. These are the primary reference, and their values are copied exactly.

- **`4._home_skill_tree_dashboard/code.html`**
  - **Patterned background:** cream `#FFF8F5`. A lattice of 1 px lines at 45° and 135°, one every 28 px, in `#231A11` at 3.5 % opacity.
  - **HUD pills:**
    - white face
    - border in `outline-variant`; the streak pill's border is gold
    - an 18 px filled icon and a `label-md` number
  - **"Current Milestone" card:**
    - white face, 2 px border, radius 24
    - a 6 px shelf plus a soft shadow
    - an 8 px band along the top, a gradient running green → gold → terracotta
  - **"3/5 Completed" badge:** `surface-container-high` pill with a 1 px border, a `label-sm` bold green label and a 2 px shelf.
  - **Milestone progress bar:**
    - 12 px sunken track in `surface-container`, 1 px border, 2 px inset
    - fill gradient running `primary` → `primary-container` → `inverse-primary`
    - a white highlight at 25 % over the top half of the fill
- **`lesson_complete_summary_1/code.html`**
  - **Celebration background:** a 320 px `surface-container-high` glow behind the hero, with a gold radial halo behind the mascot at 25 %.
  - **Top bar:** back icon on the left, "Buna" in `headline-md` green in the centre, and a "Skip" text link on the right.
  - **Docked actions:** Continue, then Review Mistakes, with 8 px between them.
  - **Stat cards:**
    - white face, 2 px tinted border, 4 px shelf
    - a 36 px icon circle on a tinted surface
    - the value in `headline-sm` in the tone colour, and a `label-sm` label
    - the "+1 Today" ribbon hangs over the top edge: filled `tertiary-container`, white, extra-bold
  - **Accuracy card:** title row, value pill, a 14 px bar, then a split row of sub-metrics.
  - **Daily-goal banner:** `surface-container` pill, 1 px `secondary` border at 20 %, a gold 20 px icon, `body-sm` semibold text, centred.
- **`out_of_beans_refill_modal/code.html`**
  - **The sheet hero:**
    - a 160 px illustration circle on `surface-container-low`, with a 2 px border at 40 %
    - a blurred, tinted glow behind the circle
    - a floating "0 / 5" badge at the bottom right: white face, 2 px terracotta border
  - **Text:**
    - title in `headline-lg`, coloured by tone
    - an Amharic line in `headline-sm` gold, then a `label-md` phonetic in brackets
    - body in `body-sm` muted, at most 320 px wide
  - **Content card:** the refill-timer card sits between the body and the actions. Its icon is a 40 px rounded-square badge.
  - **Action stack:** primary, secondary, then the "Not now" text link.
  - **Footer:**
    - the 10 px woven Tibeb stripe: diagonal bands of `#7D0301`, `#FFA03B` and `#004527`, 8 px each, then a 4 px cream gap
    - a `surface-container-low` caption bar under it
  - **Refill progress bar:** a gradient from `secondary-container` to `secondary`, with a label row underneath.
- **`level_up_streak_freeze_modal/code.html`** (the dialog)
  - A centred card: white face, 2 px `surface-container-highest` border, radius 32.
  - Shadow: an 8 px `#E5D8C3` shelf plus `0 24px 48px -12px` at 28 %.
  - A 36 px round close button at the top right.
  - The body scrolls inside the card.
- **`highland_pulse/DESIGN.md`**
  - **Tactile Level 1:** the card values.
  - **Floating Overlays:** the backdrop `rgba(43,33,24,.45)`, plus a 4 px backdrop blur.
  - **Component 3:** the streak flame in `#FF5A1F` with an orange rim, the hearts in `#D84A38`, and the gems in emerald `#10B981`.

**Fetched external references**, for the pieces no mockup shows (FR-11). Only layout and interaction patterns are borrowed from them; every colour, radius and font comes from Highland Pulse.

- **Material 3 bottom sheets** (material-components-android `docs/components/BottomSheet.md`)
  - **Borrowed:** the drag handle sits in a 48 dp touch area at the top.
  - **Borrowed:** a sheet closes on a scrim tap, a drag down, or back.
  - **Borrowed:** a sheet taller than the screen scrolls and keeps its handle.
  - **Borrowed:** at most 640 dp wide.
- **Material 3 dialogs** (`docs/components/Dialog.md`)
  - **Borrowed:** the order is icon, headline, supporting text, then actions.
  - **Borrowed:** the dialog blocks the page until it is answered or dismissed.
  - **Not borrowed:** Material's side-by-side, end-aligned buttons. Buna stacks its buttons, as in both modal mockups, so a dialog reads like a sheet.
- **Material 3 lists** (material-web `docs/components/list.md`)
  - **Borrowed:** the row anatomy: leading, headline, supporting text, then trailing.
  - **Borrowed:** a 40 px leading avatar and a 24 px trailing icon.
  - **Borrowed:** dividers between the rows of a group.
- **Duolingo design system** (open-design `design-systems/duolingo/DESIGN.md`)
  - **Borrowed:** every surface a finger can press has the same shelf.
  - **Borrowed:** fully rounded progress bars that ease out when they grow.
  - **Borrowed:** section headings in heavy type above the group they title.
  - **Borrowed:** status pills are fully rounded, with one colour per currency.
- **NN/g, "Designing Empty States in Complex Applications"** (nngroup.com/articles/empty-state-interface-design)
  - **Borrowed:** an empty state says what the learner is seeing.
  - **Borrowed:** it says how the space gets filled.
  - **Borrowed:** it offers the next action.
  - **Borrowed:** it never looks like loading, and loading never looks like "nothing here".
  - These become the required fields of `EmptyState` and `ErrorState`.

### Deliverables

**Theme**
- **`lib/shared/theme/app_tone.dart`** (new): `AppTone`, with the values neutral, primary, secondary and tertiary.
  - Each tone gives five colours:
    - **border**, e.g. primary `#D1E8D9`, gold `#F3DFC7`, terracotta `#FBD6CF`, from the lesson-complete stat cards
    - **shelf**: the border one step darker. The mockups give no tinted shelf value, so this is derived.
    - **icon surface**, e.g. `#E5F5EC` and `#FEE9E6`, from the lesson-complete icon circles
    - **accent**, for icons and values
    - **on-accent**, for text on a filled accent
  - Cards, stat cards, banners, badges, icon badges and sheet titles all read their colours from this one table, so a "primary" piece is the same green everywhere.
- **`lib/shared/theme/app_colors.dart`**: the new tone colours, each with a comment naming its source.
- **`lib/shared/theme/app_shadows.dart`**:
  - `dialog`: an 8 px shelf plus the deep soft shadow from the level-up mockup.
  - `badge`: the 2 px shelf under the "3/5 Completed" badge.
  - `card` takes a tone.

**Page shell** (story 005)
- **`lib/shared/widgets/app_page.dart`** (new): `AppPage`. It gives every screen:
  - the background
  - the safe area and the 20 px side margins
  - scrolling content
  - an optional `topBar` and `bottomDock`
  - an optional `footerStripe`

  Screens that already own their scrolling, such as the dashboard's pinned header and the lesson screen, pass `scrollable: false` and keep their own scroll view. This file is the one place in `lib/` that builds a `Scaffold`.
- **`AppTopBar`**:
  - a leading slot, a centred title (text or the "Buna" wordmark) and trailing slots
  - A 40 px icon button inside a 48 px target leaves 4 px of padding either side. The bar's side padding is 16 px, so the visible edge still lines up with the 20 px page margin.
- **`AppBackground`**:
  - **plain:** cream.
  - **patterned:** the lattice, drawn by one `CustomPainter` inside a `RepaintBoundary`. It never asks to repaint, so it repaints only on resize (NFR-3).
  - **celebration:** cream with a radial glow, from `surface-container-high` to transparent, behind the top of the page.
  - It is public, so sheets or screens can put it behind custom layouts.
- **`TibebStripe`**, in two styles:
  - **`woven`**: the footer's diagonal bands, as painted in the out-of-beans mockup.
  - **`gradient`**: the green → gold → terracotta band along the top of a card. Both card mockups draw this one.
- **The dock:**
  - pinned below the scrolling content, above the safe area and the keyboard
  - padding of 20 px at the sides, 16 px at the top and 24 px at the bottom
  - 8 px between its buttons
  - a 16 px fade from transparent to the background along its top edge, so content visibly slides under it but its last line is never covered

**Cards** (story 006)
- **`lib/shared/widgets/app_card.dart`** (new): `AppCard`.
  - It uses `tone`, `topStripe`, `onTap` and `padding` (regular 16 or compact 12).
  - With `onTap`, it presses through `TactilePressable` and exposes one button node.
  - Without `onTap`, it is a plain decorated surface, with no gesture detector and no animation.
- **`StatCard`**: an icon circle, the value, a label, and an optional `RibbonBadge`.
  - It always reserves the ribbon's half-height above itself, so a row of three stat cards lines up whether or not one has a ribbon.
- **`InfoBanner`**: a tinted stadium with an icon and a message. An `emphasis` flag gives the stronger terracotta look used by today's "unsynced for 30+ days" banner.
- **`ListRow`**:
  - leading `IconBadge` (40 px), then a `label-lg` title and an optional `body-sm` subtitle, then a trailing slot: a chevron, a switch, a value text or any widget
  - at least 56 px tall with one line and 72 px with two; never below the 48 px tap target
  - with `onTap`, the whole row is one button node, and its background darkens slightly while pressed
- **`ListRowGroup`**: a set of rows on one `AppCard`, with 1 px dividers between them. This is the settings pattern.
- **`SectionHeader`**: an optional small gold eyebrow (like "Current Milestone"), a `headline-sm` title, and an optional trailing text link.
- **`lib/shared/widgets/selectable_option_card.dart`**: rebuilt on `AppCard`. Its constructor, its three states (selected, unselected, disabled), its selected indicator, its badge and its semantics are unchanged.

**Sheets and dialogs** (story 007)
- **`lib/shared/widgets/app_sheet.dart`** (new):
  - **`showAppSheet<T>`**
    - It takes a context, a builder, `isDismissible` (default true) and `enableDrag` (default true).
    - It returns exactly what `showModalBottomSheet<T>` returns.
    - **The surface:** cream, a 32 px top radius and `AppShadows.overlay`.
    - **The backdrop:** the warm `AppColors.scrim`.
    - **The handle:** 32 by 4 px, inside a 48 px area.
    - **Scrolling:** the sheet always sizes to its content, capped at the screen height minus the safe area. Beyond that its content scrolls under a fixed handle.
    - It is at most 640 px wide.
  - **`showAppDialog<T>`**
    - A centred card using `AppShadows.dialog`, as in the level-up mockup.
    - An optional round close button at the top right.
    - The same backdrop and radius as the sheet, and scrolling content.
    - It returns exactly what `showDialog<T>` returns.
  - **`showAppConfirmDialog`**
    - It takes a title, a message, a confirm label, a cancel label and a `destructive` flag.
    - It returns `true` for confirm, `false` for cancel, and `null` when dismissed.
    - With `destructive: true`, the primary action is `AppButton.destructive`.
    - The two `AlertDialog` confirmations, delete-download and sign-out, move onto it in bolt 049.
  - **`SheetHero`**
    - **The illustration:** `illustration` (any widget, so mascot art can drop in later) and `illustrationSize` (default 120). It sits in a circle with a glow in the tone's colour, plus an optional `illustrationBadge`.
    - **The text:** `tone`, `title`, then optional `secondLanguage` and `phonetic` lines, then the `body`.
    - **Extra content:** optional `content` between the body and the actions, e.g. the refill-timer card.
    - **The actions:** `primaryAction`, `secondaryAction` and `textAction`.
    - It uses the mockup's spacing, and Fidel lines get the Ethiopic line-height (`AppTypography.forText`).

**Status pieces** (story 008)
- **`lib/shared/widgets/app_status.dart`** (new):
  - **`StatPill`**: `StatKind` is streak, beans, xp or amole.
    - **Face and border:** a translucent white face and a 1 px tinted border. The border height is the same as today's pills, so `DashboardHeader`'s height sum still holds.
    - **Streak:** flame in `AppColors.streak`, `streakRim` border.
    - **Beans:** heart in terracotta.
    - **XP:** bolt in `secondary`, as in the dashboard mockup.
    - **Amole:** diamond in emerald `gem`, following DESIGN.md and the modal mockup. Today it uses `paid`. The diamond is still distinct from XP's bolt.
    - **Numbers:** grouped with commas, e.g. 12,340.
    - **Screen readers:** each pill is one node with today's words, e.g. "5 day streak" or "3 of 5 beans remaining".
    - `StatPill.heightOf(context)` gives its height for pinned headers.
  - **`CountBadge`**: "3/5 Completed". It has an optional icon and is neutral or toned.
  - **`RibbonBadge`**: "+1 TODAY", filled in the tone's accent.
  - **`AppProgressBar`**
    - **Options:** value from 0 to 1, tone, a gradient on or off, and an optional label row (left and right text).
    - **Size:** regular (12 px) or large (14 px).
    - It eases to a new value over `AppMotion.progress`, and jumps straight there with reduced motion.
    - **Screen readers:** it reports its percentage.
  - **`IconBadge`**: a tinted circle, or a rounded square, holding an icon. Its size defaults to 40.
  - **`AppSpinner`**: the one place a `CircularProgressIndicator` is drawn, token-coloured, in regular or small. `AppButton` uses it for its loading state.
  - **`EmptyState`**: an `IconBadge`, a title, a message saying how the space gets filled, and an optional action (NN/g).
  - **`ErrorState`**: a terracotta `IconBadge`, a title, a message, and a "Try again" action when given `onRetry`.
  - **`LoadingState`**
    - An `AppSpinner` with an optional message.
    - `LoadingState.still()` shows a static placeholder with no animation, for places where a test's `pumpAndSettle` must settle. The lesson screen's placeholder under a sheet is one example.
    - It is also static under reduced motion.

**Gallery and tests**
- **`lib/shared/gallery/`**: split into one file per group, because the single file would pass 1,500 lines:
  - `component_gallery.dart` keeps the app, the shell and the 042 sections.
  - New files hold page-shell demos, cards, sheets and dialogs, and status pieces.
  - The page shells show as three framed 320×560 phones: plain with top bar and dock, patterned, and celebration with the stripe.
  - Sheets and dialogs open from buttons, including a sheet deliberately taller than the screen.
- **Stage 3 tests:**
  - `test/shared/widgets/app_page_test.dart`
  - `app_card_test.dart`
  - `app_sheet_test.dart`
  - `app_status_test.dart`
  - an extended `test/design/component_gallery_test.dart`, which opens every sheet and dialog at 360×640 with 1.3× text

### Dependencies

- **Bolt 042** (complete): the tokens, `AppShadows`, `AppMotion`, `TactilePressable`, `AppButton`, `AppIconButton`, the gallery and the rules test.
- **No new packages.** Number grouping is a small helper, because `intl` isn't a dependency.

### Technical Approach

**Tones are data, not variants.** One `AppTone` table feeds every toned piece. That keeps "the green card" and "the green badge" from drifting apart, the same way button variants fixed their colours in 042.

**`AppPage` owns the `Scaffold`.**
- `resizeToAvoidBottomInset` stays on, so the dock rides above the keyboard on sign-in.
- The body is a `Column`: the top bar, the scrolling content under the dock's fade, then the dock.
- The content gets the 20 px margins through one `Padding`, unless `padded: false`. The dashboard's full-bleed path needs that.
- Backgrounds sit under everything, in a `Stack`.

**Sheets reuse Flutter's routes.**
- `showAppSheet` calls `showModalBottomSheet` with `isScrollControlled: true`, `useSafeArea: true`, a transparent background and elevation 0.
- It draws its own surface, so the overlay shadow and the handle come from the tokens.
- Dismissal and return values are Flutter's own, which is why the results match exactly.
- `showAppDialog` works the same way on `showDialog`.

**No backdrop blur.**
- DESIGN.md pairs the scrim with a 4 px blur. A modal route's barrier can't blur without a `BackdropFilter` over the whole page, which is costly on low-end Android (NFR-3), and the mockups read the same without it.
- The warm scrim is kept exactly.

**Painting is cheap and static.** The lattice, the glow and the Tibeb stripe are `CustomPainter`s with `shouldRepaint` false, each inside a `RepaintBoundary`.

**Nothing loops forever.**
- The only endless animation is `AppSpinner`, and every place a test settles has the static `LoadingState.still()`.
- The progress bar's tween ends.
- The mockups' decorative loops (a pulsing glow, a floating mascot) are left out of the library for now.

**Semantics follow 042's pattern.** Each piece is one node with its full meaning: pills, badges, the progress bar, tappable cards and rows. Decorative painters are excluded.

**Everything is built from tokens.** The new files live in `lib/shared/`, which the rules test exempts from every rule except the colour rule. So every colour in them must be a token.

### Acceptance Criteria

**Story 005: page shell**
- [ ] A screen on `AppPage` gets the cream background, safe area, 20 px margins and scrolling content without setting any of them.
- [ ] The patterned lattice paints once and doesn't repaint on scroll.
- [ ] The celebration glow sits behind the top of the page.
- [ ] Top-bar slots line up with the page margins.
- [ ] The dock is pinned above the safe area and the keyboard. Content scrolls under its fade, and the last item can scroll fully clear of it.
- [ ] `footerStripe` shows the woven Tibeb stripe at the bottom.
- [ ] At 360×640 with 1.3× text, content scrolls and the dock stays visible.

**Story 006: cards**
- [ ] `AppCard` has a white face, a 2 px border, a 24 px radius and the card shadow.
- [ ] Its tone tints the border and shelf, and the face stays white.
- [ ] `topStripe` draws the gradient band.
- [ ] A card with `onTap` presses like a button and is one button node.
- [ ] `StatCard`, `InfoBanner`, `ListRow`, `ListRowGroup` and `SectionHeader` match their references and are in the gallery.
- [ ] `SelectableOptionCard` is on `AppCard`. Its three states and semantics are unchanged, and its existing tests pass untouched.

**Story 007: sheets and dialogs**
- [ ] `showAppSheet` has a 32 px top radius, the cream surface, the handle, the warm scrim and the overlay shadow.
- [ ] `showAppDialog` has the dialog card, the same scrim and radius, and uses `SheetHero`.
- [ ] `showAppConfirmDialog` uses a destructive primary when asked.
- [ ] `SheetHero` shows the illustration with its glow and badge, the toned title, the second-language line, the body, and the action stack in the mockup's spacing.
- [ ] A sheet taller than the screen at 1.3× text scrolls, and all its actions can be reached and tapped.
- [ ] Return values match `showModalBottomSheet` and `showDialog` exactly, including `null` on a scrim tap or back.

**Story 008: status pieces**
- [ ] `StatPill`, for each of its four kinds, matches the HUD and has the same screen-reader label as today.
- [ ] 12,340 formats as "12,340" and fits at 1.3× text.
- [ ] `CountBadge` and `RibbonBadge` match "3/5 Completed" and "+1 TODAY".
- [ ] `AppProgressBar` has the sunken track, the rounded fill, the optional gradient and the optional label. It eases to a new value and settles.
- [ ] `EmptyState`, `ErrorState` and `LoadingState` each have an `IconBadge`, a title, text and an optional action.
- [ ] `LoadingState.still()` lets `pumpAndSettle` finish.
- [ ] `InfoBanner` shows all of `SyncStatusBanner`'s states in the gallery: syncing, offline with packs, offline with nothing downloaded, failed, and escalated.

**Whole bolt**
- [ ] The gallery shows every new component and state, with no overflow at 360×640 and 430×932, at 1.0× and 1.3× text.
- [ ] The rules test passes, and its allow-list is no longer than 64 entries.
- [ ] `flutter analyze` shows no new issues. The full suite passes, apart from the same 7 end-to-end tests that need a backend on `localhost:8000`.

### Decisions to confirm

1. **Dialog face:**
   - The story says the dialog "uses the same surface" as the sheet.
   - The level-up mockup draws the dialog as a white card with a shelf, while the sheet is cream.
   - **Plan:** follow the mockups (1a): a white dialog card and a cream sheet. They share the radius, backdrop and `SheetHero`.
2. **Progress timing:**
   - Story 008 says `AppMotion.state` (150 ms).
   - Bolt 042 later added `AppMotion.progress` (400 ms) for exactly this, following Duolingo's 320 ms ease-out for progress.
   - **Plan:** use `AppMotion.progress`. A 150 ms jump reads as a flicker on a progress bar.
3. **Backdrop blur:** left out, as explained under Technical Approach. The scrim colour is exact.
4. **Amole icon:** moves from `paid` to the diamond, following DESIGN.md and the mockups. This shows once bolt 047 moves the dashboard onto `StatPill`.
