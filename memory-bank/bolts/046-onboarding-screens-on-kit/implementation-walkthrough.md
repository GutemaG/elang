---
stage: implement
bolt: 046-onboarding-screens-on-kit
created: '2026-09-25T21:22:16Z'
---

## Implementation Walkthrough: screen-migration-ui (onboarding and sign-in on the library)

### Summary

- **Five screens rebuilt:** splash, the onboarding carousel, language
  selection, daily goal and sign-in now stand on `AppPage`, with their
  actions docked at the bottom.
- **Flow and copy:** unchanged. Every existing auth test passes; one
  changed only the widget type it looks for.
- **Rules test:** all five screens are off the allow-list.

### Structure Overview

Each screen hands `AppPage` its content and its bottom dock. Screens whose
content must sit in the middle of the room (splash) or fill it (the
carousel) turn off the page's own scrolling and scroll inside themselves,
so a short phone at large text still reaches everything.

Four small library additions carry what the screens needed and the library
lacked. Each has a gallery case.

### Completed Work

- [x] **`lib/features/auth/screens/splash_screen.dart`**
  - Celebration page, with Get Started docked.
  - The mascot tile is an `AppCard` holding the cup.
  - The brewing card is an `AppCard` with the percentage as a
    `CountBadge` and a gradient `AppProgressBar`, driven frame by frame
    by the same animation. Navigation timing is untouched.
- [x] **`lib/features/auth/screens/onboarding_carousel_screen.dart`**
  - `AppTopBar.brand` with Skip as a text link.
  - Each slide is an `AppCard` with the Tibeb stripe. The illustration is
    a large `IconBadge`, and the letter chip a `CountBadge`. A slide
    taller than the room scrolls.
  - `PageDots` under the slides.
  - The dock holds Continue, then "Already have an account? Log In", with
    Log In a text link.
- [x] **`lib/features/auth/screens/language_selection_screen.dart`**
  - `LoadingState` while loading.
  - A failed or empty catalog shows `ErrorState` with its existing
    sentence as the title and Retry.
  - The flag is a square `IconBadge`. "Join Waitlist" is a text link.
  - The "I speak" chips are styled by the theme, not the screen.
- [x] **`lib/features/auth/screens/daily_goal_selection_screen.dart`**
  - The headline uses the display token as it is (no hand-set size).
  - Each option's icon is a square `IconBadge`, primary when chosen.
  - The tip is an `InfoBanner`.
  - The dock holds Continue and its caption.
- [x] **`lib/features/auth/screens/sign_in_screen.dart`**
  - Google and Apple are equal `AppButton.secondary` buttons with their
    marks. The web Google button is Google's own, untouched.
  - The error is an `InfoBanner` with Retry inside it.
- [x] **Library additions**
  - `PageDots` (`app_status.dart`): the carousel's dots, animated unless
    the system asks for less motion. A screen reader hears "Page 2 of 3".
  - `InfoBanner.action` (`app_card.dart`): an optional button at the
    banner's end. With one, the banner takes rounded corners so a
    two-line message fits, and the button stays its own button for a
    screen reader.
  - `ErrorState.message` is now optional, so a screen whose error is one
    sentence keeps that sentence without inventing a second.
  - `AppProgressBar.animate` (default `true`): off for a bar already
    driven by its own animation, so it doesn't trail behind.
  - `AppTheme.chipTheme`: white stadium chips with a 2 px border. A chosen
    one takes the chosen-option face, a green border and a check.
- [x] **`lib/shared/gallery/gallery_status.dart`:** cases for the banner
  with an action, the dots, and the chips.
- [x] **`test/design/design_rules_test.dart`:** the five screens removed.
- [x] **`test/features/auth/sign_in_screen_test.dart`:** looks for
  `AppButton` instead of `TactileButton`. Nothing else changed.

### Key Decisions

- **The page scrolls unless the screen needs to place things.** Splash
  centres its mascot in the space above the brewing card, and the
  carousel's slides fill the space above the dots. Both do that inside a
  scroll view sized to at least the room, so nothing is cut off on a
  short phone.
- **Illustrations are icons in large badges.** The mockups' art isn't in
  the app. A 160 px `IconBadge` keeps the slide's proportions without it.
- **Errors keep their one sentence.** Rather than add a second line of
  copy to fit `ErrorState`, its message became optional.

### Deviations from Plan

- **Two library changes beyond the plan's two:** `ErrorState.message`
  became optional, and `AppProgressBar` gained `animate`. Both are
  additive, and every existing use behaves as before.
- **Otherwise none.**

### Dependencies Added

None.

### Developer Notes

- **Checks:** `flutter analyze` shows the same 13 infos as before, and all
  952 Flutter tests pass. `dart format` was run on each file this bolt
  touched.
- **Small screens:** a scratch run at 320 and 360 px, at 1.0x and 1.3x
  text, found no overflow on the carousel, language and daily-goal
  screens. The Test stage turns this into real tests, and adds splash and
  sign-in.
