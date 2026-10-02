---
stage: plan
bolt: 079-translate-onboarding-and-settings
created: '2026-10-02T19:52:00Z'
---

## Implementation Plan: screen-translations (all screens)

### Objective and replan

After bolt 078 the user saw only the App language words translated and
asked for every app word to be translated now ("most the app words that is
non related course should be translated"). So this bolt took the whole of
unit 003: stories 008-016, planned for bolts 079, 080 and 081. Bolts 080
and 081 are folded into this one (construction log, replanning history).

### Approach

1. Inventory every user-visible literal in `lib/` (a script over string
   literals with words, skipping keys, URLs, exception messages and the
   gallery): about 550 candidates, about 330 real.
2. Move them, file by file, into `app_en.arb` with a description, and draft
   `app_am.arb` and `app_om.arb`; screens read `context.l10n`.
3. Where words were built outside a widget, pass `AppLocalizations`:
   - const option lists (daily goals, appearance, feedback kinds,
     onboarding slides) become functions of `AppLocalizations`;
   - helpers keep an English default so existing callers and tests work
     (`leagueTimeLeft`, `leagueZoneSummary`, `leagueUpdatedAgo`,
     `LeagueResultSheet.title/body`, `ordinal`, `reminderMessage`,
     `planReminders`, `PictureChoice.labelAt`, `AmoleEntry.reason`);
   - shared widgets' default labels (`ErrorState.retryLabel`,
     `showAppConfirmDialog.cancelLabel`, `AnswerSlotLine.sentence.hint`,
     `AudioPlayButton.semanticLabel`) become nullable and fall back to the
     app language.
4. Plurals and sentences with values as ICU messages; month and weekday
   names from the ARB files (intl has no Afaan Oromo dates).
5. The reminder: `ReminderService.words` is the app language, and a
   language change reschedules.
6. The untranslated-text scan's list emptied; the screen sweep in every
   language; a guide for the reviewer.

### Kept as is (on purpose)

- "Buna" (the name), Fidel sample chips ("ሀ ha"), KB/MB units.
- Course and lesson content, course titles, server language names.
- The Android notification channel name ("Daily reminder"): the phone
  keeps the name from the first install.
- Picture credits on the licence page (legal text, from the credits file).
- `HomePlaceholderScreen` (no route leads to it).

---

## Implement (2026-10-02T20:32:16Z)

- **ARB files:** 325 keys in `app_en.arb`, `app_am.arb`, `app_om.arb`,
  each with an `@key` description; built from batches by a script.
- **Screens translated:** splash, onboarding carousel, language choice,
  daily goal, sign-in; Settings (all rows, sheets, the log-out dialog);
  Send feedback; course badge, panel and picker; downloads; dashboard
  (Practice card, league card, lesson popovers, offline and signed-out
  states); lesson (loading, errors, offline, mistake review, prompts);
  lesson complete; stat sheet (streak, beans, XP, Amole tabs), streak
  calendar, Amole history, bean timer, out of beans, level up, exit sheet;
  skill nodes and popovers; section banner; sync banner; league screen,
  result sheet, rows, zones and tier names; shared widgets (stat pills,
  page dots, error and loading states, confirm dialog, sheet close, answer
  bar, answer slot line, audio button, lesson top bar, crown level badge,
  locked popover); picture fallback labels.
- **`LearnPrompts`** now reads the language's own ARB file.
- **`LeagueTier.titleIn`**, **`AmoleEntry.reasonIn`**, **`AppDates`**
  (`monthName`, `monthShort`, `weekdayLetters`) on `AppLocalizations`.
- **Reminder:** `planReminders(words:)`, `reminderMessage(count, words)`;
  `main.dart` sets `reminders.words` and reschedules on a language change.
- **Layout fix found by the sweep:** `InfoBanner` with an action gave the
  action its full width, so Afaan Oromo's "Irra deebi'i yaali" pushed the
  sign-in error banner off a 360 px screen; the action now takes at most
  two fifths and its label wraps.
- English texts unchanged except "Manage Downloads" → "Manage downloads"
  (one key for the panel row and the screen title).

## Test (2026-10-02T20:32:16Z)

- `test/l10n/untranslated_text_test.dart`: the not-yet-translated list is
  empty; "Buna" is listed as a name; the placeholder screen is skipped.
- `test/l10n/translated_text_test.dart` (new): the daily goal screen in
  en/am/om; the reminder in am/om (English by default); places
  (2nd/2ኛ/2ffaa); league time left and zones with plurals; course-choice
  prompts per spoken language with the English fallback; month and
  weekday names.
- `test/design/screen_sweep_test.dart`: every scene now runs in `en`,
  `am` and `om` (both sizes, both text scales, both themes): 1550 passed.
  Scenes find what they tap through the app's words, not English.
- Updated: two tests for "Manage downloads".
- `flutter analyze` clean; `flutter test --exclude-tags e2e` 3068 passed.
- `memory-bank/intents/024-app-localization/translation-guide.md` for the
  reviewer (story 016).
