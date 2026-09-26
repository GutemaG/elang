---
stage: test
bolt: 046-onboarding-screens-on-kit
created: '2026-09-26T05:27:21Z'
---

## Test Report: screen-migration-ui (onboarding and sign-in on the library)

### Summary

- **Tests:** 1,117 of 1,118 Flutter tests pass.
  - 952 were passing before these three bolts, and 166 are new across
    them.
  - **The one failure** is the end-to-end sign-in test "a garbage Google ID
    token gets a real 401". It needs the backend on port 8000, and it
    failed in each of today's three full runs, with a sign-in failure of
    a different kind than it expects. It passed every time it ran alone
    (three times). It calls the backend directly and touches none of the
    screens these bolts changed, so it looks like a timeout under the
    full suite's load. It is worth a look separately.
- **Checks:** `flutter analyze` shows the same 13 infos as before, and
  `dart format` finds nothing to change in any file these bolts wrote.
- **Coverage:** not measured.
- **Mutation check** (shared by 046 to 048): 72 deliberate breakages of the
  new code, each run against the new tests and the related existing ones.
  - **First run:** 68 caught.
  - **After new tests:** 71 caught. The last, #36, is equivalent: it drops
    the count badge's padding from the banner-height sum, but the title
    and subtitle are always taller than the badge, so the sum never uses
    it.
  - Every file was checked to be restored exactly after its run.

### Test Files

- [x] **`test/features/auth/auth_screens_on_kit_test.dart`** (38, new)
  - **Splash:**
    - It is a celebration page, with Get Started docked as the primary
      action.
    - The brewing bar doesn't ease, and it and the percentage badge
      follow the animation (50 % at 700 ms).
    - The mascot and the brewing card are library cards.
  - **Carousel:**
    - The brand top bar holds Skip as a text link.
    - Continue is docked, with Log In as a text link under it.
    - Each slide is a card with the Tibeb stripe and the letter badge.
    - The dots follow Continue.
  - **Language:**
    - Loading is the library loading state.
    - A failure is an `ErrorState` with its one sentence and Retry, which
      loads the courses.
    - Loading and errors fill the page, centred above the dock, and the
      choices scroll.
    - Flags are square badges, green for an open course.
    - Continue is docked, and the chips take no style of their own.
  - **Daily goal:**
    - The headline is the display token.
    - The chosen goal's badge is green and the others gold, following the
      choice.
    - The tip is a banner, and Continue and its caption are docked.
  - **Sign-in:**
    - Google and Apple are equal secondary buttons with their marks.
    - A failure shows the warm banner with Retry inside it, and Retry
      tries the same provider again.
    - It is an `AppPage`, and the terms line remains.
  - **Small screens:** all five screens fit 320 and 360 px at 1.0x and
    1.3x, and so does the sign-in error banner.
- [x] **`test/shared/widgets/screen_migration_library_test.dart`** (34,
  new; shared with 047 and 048). For this bolt's pieces:
  - **`PageDots`:**
    - Its sizes and colours.
    - "Page 2 of 3" for a screen reader.
    - It eases, or jumps with reduced motion.
  - **`InfoBanner.action`:**
    - Its place, and that it works.
    - Its rounded corners.
    - A screen reader hears the message and the button separately.
    - A long message fits at 1.3x on 320 px.
  - **`ErrorState` with no message:** no empty line is drawn.
  - **`AppProgressBar(animate: false)`:** shows a new value at once.
  - **The chip theme:** its face, border, label and check, both in the
    theme and on a real `ChoiceChip`.
- [x] **Changed in Implement, and passing:** `sign_in_screen_test.dart`
  finds `AppButton` instead of `TactileButton`.

### Acceptance Criteria Validation

**Story 001: onboarding and sign-in on the library**
- ✅ **Built on the library, as the mockups lay them out:** covered by the
  page, card, badge and dock tests for each screen.
- ✅ **Skip, "Log In" and "Join Waitlist" are text links:** covered for
  Skip and Log In. "Join Waitlist" is an `AppButton.text`, and the
  existing language tests tap it.
- ✅ **Google and Apple have equal size and prominence, with their marks:**
  covered. On the web, the Google button is Google's own and untouched.
- ✅ **Sign-in errors show inline, and Retry works as today:** covered, as
  are the existing error and cancel tests.
- ✅ **Navigation, timing, the catalog logic and choices are unchanged:**
  every existing auth test passes.
- ✅ **No overflow at 320 and 360 px, at 1.0x and 1.3x:** covered for all
  five screens.
- ✅ **The rules test passes with the five screens off the list:** it
  passes.
- ✅ **Existing tests changed only for replaced widget types:** one type
  swap.

### Issues Found

- **A screen reader heard a banner's message and its button as one
  phrase.** The new semantics test caught it. The message is now its own
  node, so Retry is read and tapped as a button of its own.
- **The mutation check found one gap:** nothing checked that the language
  screen's loading and error pages are centred. A test now does.

### Notes

- **The small-screen tests use Flutter's test font,** which is wider than
  Plus Jakarta Sans. Fitting at 320 px with it leaves room to spare on a
  real device.
