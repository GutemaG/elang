---
stage: plan
bolt: 046-onboarding-screens-on-kit
created: '2026-09-25T20:50:30Z'
---

## Implementation Plan: screen-migration-ui (onboarding and sign-in on the library)

### Objective

Rebuild splash, the onboarding carousel, language selection, daily goal and
sign-in on the design library, as their Stitch mockups lay them out. Keep
their flow, copy and behaviour exactly, and take all five off the rules
test's allow-list.

### Reference designs (FR-11)

`stich-screens/extracted/stitch_ethiopian_language_learning_app/`:

- **`1._buna_splash_screen`:**
  - a warm glow page
  - the mascot tile
  - the "Buna" wordmark and tagline
  - a "Brewing your lessons" card with a progress bar
  - a docked "Get Started"
- **`2._onboarding_carousel`:**
  - a brand top bar with Skip as a text link
  - one raised slide card with a gradient top stripe, the illustration
    area, a title and body
  - the dots
  - a docked Continue
  - "Already have an account? Log In"
- **`3._language_selection`:**
  - course cards, the chosen one with a green border and a check, and a
    coming-soon one faded with "Join Waitlist"
  - a docked Continue
- **`4._daily_goal_selection`:**
  - a large headline
  - four option cards, the chosen one green-bordered with "RECOMMENDED"
  - a tip banner
  - a docked Continue with a caption
- **`5._create_account_sign_in`:**
  - a large headline
  - two equal white provider buttons
  - a warm inline error banner with a Retry pill
  - the terms line

**Not taken from the mockups.** All of these are new copy, art or flow, and
the story keeps flow and copy as they are:
- the mascot and goat illustrations, and the speech bubbles
- "HIGHLAND PULSE", "100% Arabica" and "Coffee & Culture" pills
- the carousel's feature chips
- the language card's alphabet row and learner count
- the sign-in feature chips
- the mockups' step counters ("1/3", "STEP 2 OF 3", "STEP 5 OF 5"), which
  also disagree with each other
- back buttons where the flow has no back step

The existing icons stand in for the art.

### Decisions

- **D1: Every screen is an `AppPage`.**
  - **Shape:** the actions sit in its bottom dock, and the content scrolls
    above them.
  - **Backgrounds:**
    - splash takes the celebration background (the mockup's warm glow)
    - the other four take the plain one
  - **Removed:** the screens' own `Scaffold`, `SafeArea` and padding.
- **D2: Buttons.**
  - **Primary actions:** "Get Started" and "Continue" become
    `AppButton.primary` with the arrow.
  - **Links:** Skip, "Log In" and "Join Waitlist" become `AppButton.text`
    (Checkpoint 1: 2a).
  - **Error retry:** "Retry" on a load error goes to `ErrorState`'s own
    button.
- **D3: Splash.**
  - **Mascot:** the tile becomes an `AppCard` holding the cup icon.
  - **Brewing card:** an `AppCard` with the label, the percentage as a
    `CountBadge`, and an `AppProgressBar` driven by the same animation.
  - **Behaviour:** navigation timing is unchanged.
- **D4: Carousel.**
  - **Top bar:** `AppTopBar.brand`, with Skip as its trailing text link.
  - **Slides:** each is an `AppCard` with the gradient top stripe
    (`topStripe`). Its illustration area and the "ሀ ha" chip use library
    pieces; `CountBadge` is the chip.
  - **Dots:** drawn from tokens, in a small library widget,
    `PageDots`, with a gallery case.
  - **Dock:** Continue, then the "Already have an account? Log In" row.
- **D5: Language selection.**
  - **Loading and errors:** loading is `LoadingState`; a failed or empty
    catalog is `ErrorState` with Retry.
  - **"I speak":** it stays a row of choice chips, now styled once, from
    tokens, in `AppTheme`'s chip theme rather than by the screen.
  - **Course cards:** `SelectableOptionCard`, as now. The flag badge
    becomes an `IconBadge` in its rounded-square form.
  - **Waitlist:** "Join Waitlist" is a text link.
- **D6: Daily goal.**
  - **Headline:** the screen's hand-sized 28 px headline uses the
    display type token.
  - **Option icons:** each is an `IconBadge`, primary-toned when chosen.
  - **Tip:** an `InfoBanner`.
  - **Dock:** Continue, then its caption.
- **D7: Sign-in.**
  - **Google and Apple:** equal `AppButton.secondary` buttons (white, with
    the shelf, as in the mockup), each with its provider glyph as the
    leading icon.
    - Their label, order and size stay as they are.
    - On the web, Google's own rendered button is kept untouched, as its
      rules require.
  - **Inline error:** an `InfoBanner` with the secondary tone.
    - `InfoBanner` gains an optional trailing `action`, a small library
      change with a gallery case, so Retry sits inside the banner as the
      mockup draws it.
    - Retry is a compact `AppButton.secondary` with the refresh icon.
    - The cancelled and failed messages are unchanged.
- **D8: The rules test.** All five screens come off `_notYetMigrated`. No
  other entry changes.

### Deliverables

- **`lib/features/auth/screens/`:** splash, carousel, language, daily goal
  and sign-in, rebuilt.
- **`lib/shared/widgets/`:**
  - `PageDots` (new, in `app_status.dart`)
  - `InfoBanner.action` (in `app_card.dart`)
- **`lib/shared/theme/app_theme.dart`:** the chip theme.
- **`lib/shared/gallery/`:** cases for the dots, the banner with an action,
  and the chips.
- **`test/design/design_rules_test.dart`:** five entries removed.
- **Tests:** existing auth tests updated only where they look for a
  replaced widget type. New tests cover the new library pieces and each
  screen's layout.

### Dependencies

- Bolts 042–044: the library, all present.
- No new packages.

### Out of Scope

- Changes to flow, copy or navigation.
- New art, the mascot, or step counters.
- `TactileButton`'s removal (bolt 049's sweep).

### Acceptance Criteria

- [ ] **Built on the library:** each of the five screens uses `AppPage`,
      `AppButton`, `AppCard`/`SelectableOptionCard` and the status pieces,
      laid out as its mockup.
- [ ] **Links:** Skip, "Log In" and "Join Waitlist" are `AppButton.text`.
- [ ] **Provider buttons:** Google and Apple are the same size and
      prominence, with their provider marks. The web Google button is
      unchanged.
- [ ] **Sign-in errors:** they show inline in the shared banner, and Retry
      works as today.
- [ ] **Behaviour:** navigation, timing, the catalog logic and choices are
      unchanged.
- [ ] **Small screens:** no overflow at 320 and 360 px, at 1.0× and 1.3×
      text.
- [ ] **The rules test** passes with the five screens off the allow-list.
- [ ] **Existing tests:** all auth and onboarding tests pass, changed only
      where they found a replaced widget type.
