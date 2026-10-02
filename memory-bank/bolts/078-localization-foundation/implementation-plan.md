---
stage: plan
bolt: 078-localization-foundation
created: '2026-10-02T19:32:18Z'
---

## Implementation Plan: localization-foundation

### Objective

Stories 002-007 (FR-1, FR-3, FR-4, FR-5, FR-6 app side, FR-2 guards):
Flutter localization set up with English, Amharic and Afaan Oromo, the
app language chosen in Settings and applied at once, kept on the phone and
the account, set from the "I speak" choice at sign-up, and tests that stop
untranslated text from coming back. Translating the screens is bolts
079-081; this bolt translates only the words it adds.

### What the code says (checked before planning)

- **F1 No localization yet.** No `flutter_localizations`/`intl`; every
  string is a literal. Flutter 3.47: `gen-l10n` writes into the source
  tree (no synthetic package).
- **F2 Appearance is the model to copy.** `AppearanceRepository` (secure
  storage) + `AppearanceController` (a `ValueNotifier`, loaded in `main`
  before `runApp`) + `AppearanceScope`; `BunaApp` rebuilds `MaterialApp`
  from it; Settings has an Appearance row and a `_AppearanceSheet` of
  `SelectableOptionCard`s.
- **F3 Account settings on the phone.** `RemoteSettingsController` keeps
  the account's settings (saved copy, `applySession` on each session
  check, `updateAccount` to PATCH, `forgetAccount` on sign-out or a new
  sign-in); keys are declared in `AccountSettings` (`known_settings.dart`).
  `HttpAccountSettingsApi` does the PATCH.
- **F4 Session checks run only at launch** (`SessionRenewer.renew`, from the
  splash), and call `onSessionChecked` in `main`. **The sign-in response
  carries no settings** (`AuthUserResponse`), and the account copy is
  cleared at sign-in, so today a fresh sign-in sees the account's settings
  only at the next launch.
- **F5 Sign-up.** `LanguageSelectionScreen._onContinuePressed` records
  `fromLanguageCode`; the screen has no dependency it could use for the app
  language except through the tree.
- **F6 Material/Cupertino** have `am` translations but not `om`.

### Decisions

- **D1 Set-up.** `flutter_localizations` (sdk) and `intl` in `pubspec.yaml`,
  `generate: true`, `l10n.yaml` (`arb-dir: lib/l10n`, template
  `app_en.arb`, output class `AppLocalizations`, nullable getter off). The
  generated Dart lives in `lib/l10n/` and is committed (so a checkout
  builds without running `gen-l10n` first). A key missing from `am`/`om`
  falls back to English (gen-l10n uses the template text). Read with
  `context.l10n.someKey` (a small extension).
- **D2 One list of app languages.** `lib/shared/l10n/app_language.dart`:
  `AppLanguage(code, nativeName, englishName)` for `en`, `am`, `om`;
  `AppLanguage.of(code)` returns English for null, `""` or an unknown code.
  Adding a language: an ARB file and one line here.
- **D3 Oromo for Flutter's own texts.** A delegate gives `om` the English
  `MaterialLocalizations` and `CupertinoLocalizations`
  (`DefaultMaterialLocalizations`), so `om` never throws and shows English
  for "OK", "Paste" and the like. `am` uses Flutter's own.
- **D4 The controller.** `AppLanguageController` (a `ValueNotifier` of the
  chosen code, `null` = never chosen), `AppLanguageRepository` (secure
  storage key `app_language`, plus `app_language_unsent` while a change has
  not reached the account) and `AppLanguageScope`, loaded in `main` before
  `runApp` like Appearance, so there is no flash of English. `BunaApp`
  gives `MaterialApp` its `locale`, the delegates and the supported
  locales.
  - `choose(code)` (Settings): applies at once, saves, marks it unsent,
    and sends it (D6).
  - `adoptSignUpLanguage(code)` (sign-up): only if nothing is chosen yet
    and the app has that language; not marked unsent, so an account that
    already has a language wins at the next session check.
- **D5 Settings.** An "App language" row (icon `translate`), subtitle the
  current language's own name, in the Preferences group under Appearance;
  a sheet like Appearance's: one `SelectableOptionCard` per language,
  title its own name, subtitle its English name, the current one
  selected. Choosing redraws at once. The row and sheet are the first
  translated words (en/am/om).
- **D6 The account.** `AccountSettings.appLanguage` (`app_language`, `""`).
  On each session check (`onSessionChecked`, after `applySession`):
  - unsent change on the phone → send it (`updateAccount`); on success
    clear "unsent"; on failure keep it for the next check;
  - else the account has a language → take it (no send);
  - else the phone has one → send it (fills an empty account, which is
    every existing learner).
  A Settings change is also sent at once when signed in; failure only
  leaves it unsent. Any code the app lacks is kept but shown as English.
- **D7 Right after sign-in.** Because of F4, after a successful sign-in the
  app runs one session check in the background (the existing
  `SessionRenewer.renew`), so a new phone switches to the account's
  language within a moment of reaching the dashboard instead of at the
  next launch. No backend change. (Known effect: on a new phone the first
  dashboard frame can be in the sign-up language before it switches.)
- **D8 Sign-up.** On Continue, `LanguageSelectionScreen` calls
  `AppLanguageScope.maybeOf(context)?.adoptSignUpLanguage(from)`, so the
  daily-goal screen after it is drawn in that language (once 079 has
  translated it).
- **D9 Guards (story 007).**
  - `test/l10n/arb_parity_test.dart`: every key in `app_en.arb` has a
    value in `app_am.arb` and `app_om.arb`, no extra keys, and every key
    has an `@key` description; placeholders match across files.
  - `test/l10n/untranslated_text_test.dart`: scans `lib/` (skipping
    `lib/l10n/`, `lib/shared/gallery/`, `lib/gallery_main.dart`) for a
    string literal with letters passed as visible text (`Text('…')`,
    `label:`, `title:`, `subtitle:`, `tooltip:`, `message:`, `hint:`,
    `semanticLabel:`, `retryLabel:`, `badgeLabel:`, `description:`,
    `content: Text(…)` and the like). Files that still have some are
    listed in an allow-list; the test fails on a file not listed **and**
    on a listed file that no longer has any (so the list only shrinks).
    Bolts 079-081 empty it.
- **D10 Tests keep finding English.** Test apps that build `MaterialApp`
  themselves get the delegates through a helper only where a screen now
  reads `context.l10n`; with no locale set, Flutter picks English, so
  existing `find.text('…')` tests keep passing.

### Deliverables

- `pubspec.yaml`, `l10n.yaml`, `lib/l10n/app_en.arb`, `app_am.arb`,
  `app_om.arb` and the generated `app_localizations*.dart`
- `lib/shared/l10n/`: `app_language.dart` (list, controller, scope,
  `context.l10n`), the `om` fallback delegate
- `lib/shared/services/app_language_repository.dart`
- `known_settings.dart`: `AccountSettings.appLanguage`
- `main.dart`: load before `runApp`; `MaterialApp` locale and delegates;
  the account step in `onSessionChecked`
- Sign-in: one background session check after success (D7)
- Settings: the row and sheet; `LanguageSelectionScreen`: the sign-up step
- Tests: controller and repository; account sync; Settings row and sheet
  (switches at once, works offline); sign-up default (and not overriding);
  `om` Material fallback; ARB parity; the untranslated-text scan; the
  screen sweep for the sheet

### Acceptance criteria

- [ ] Fresh install: English. Restart keeps the chosen language with no
  English first frame; sign-out keeps it; an unknown stored code is
  English.
- [ ] Settings → App language → አማርኛ: the sheet closes and Settings'
  new words are Amharic at once; offline too.
- [ ] Sign-up under "For Amharic speakers": app language `am`, unless one
  was already chosen; switching course never changes it.
- [ ] A Settings change is PATCHed; a failed one is sent at the next
  session check; a signed-in new phone takes the account's language; an
  empty account takes the phone's.
- [ ] `om` shows English Material texts without errors.
- [ ] ARB parity and the untranslated-text scan pass; the allow-list
  holds every screen not yet translated.
- [ ] `flutter analyze` clean; `flutter test --exclude-tags e2e` passes;
  `dart format` on touched files.

### Dependencies

Bolt 077 (the `app_language` account setting), complete.

---

## Implement (2026-10-02T19:45:01Z)

Approved at the plan checkpoint with D7 (a session check right after
sign-in).

- **Set-up:** `pubspec.yaml` (`flutter_localizations`, `intl`,
  `generate: true`), `l10n.yaml`, `lib/l10n/app_en.arb` (template),
  `app_am.arb`, `app_om.arb` and the generated
  `app_localizations*.dart` (committed). Keys so far: `appLanguageTitle`,
  `close`, and `dayCount` (a plural, used from bolt 080).
- **`lib/shared/l10n/app_language.dart`:** `AppLanguage` (`en`, `am`,
  `om`; `of` falls back to English; `delegates` and `locales` for
  `MaterialApp`), `context.l10n` (English where no localizations are
  above, so screens pumped alone in tests keep working),
  `AppLanguageController` (`choose`, `adoptSignUpLanguage`,
  `syncWithAccount`, an injected `send`), `AppLanguageScope`, and two
  delegates giving Flutter's Material and Cupertino words in English for
  a language Flutter lacks (`om`).
- **`AppLanguageRepository`:** `app_language` and `app_language_unsent`
  in secure storage.
- **`main.dart`:** the controller is loaded before `runApp`; `send`
  PATCHes through `RemoteSettingsController.updateAccount`;
  `onSessionChecked` applies the session's settings, then
  `syncWithAccount`; `BunaApp` takes `appLanguage` and gives
  `MaterialApp` its locale, delegates and locales.
- **`AccountSettings.appLanguage`** in `known_settings.dart`.
- **Sign-in:** `SignInScreen.onSignedIn` →
  `AuthFlowController.checkSessionInBackground` (wired in `AuthRoutes`).
- **Settings:** an "App language" row under Appearance and a sheet of
  `SelectableOptionCard`s (a `CourseGlyph`, the native name, the English
  name); title and Close tooltip from the ARB files.
- **Sign-up:** `LanguageSelectionScreen` calls `adoptSignUpLanguage` on
  Continue.
- **Guards:** `test/l10n/arb_parity_test.dart` and
  `test/l10n/untranslated_text_test.dart`. The scan skips `lib/l10n/`,
  the gallery and `lib/shared/services/` (no UI: exception messages go
  to logs, fakes stand in for server content). 36 files are on the
  not-yet-translated list for bolts 079-081.
- Tests that build `BunaApp` pass `testAppLanguage()`
  (`test/helpers/test_app_language.dart`).
- `flutter analyze` clean; full suite 2012 passed before the test stage.

---

## Test (2026-10-02T19:51:16Z)

- `test/shared/l10n/app_language_test.dart` (19): the language list and
  English fallback; kept on the phone (default, applies at once and
  survives a restart, unknown stored code); sign-up (takes the spoken
  language without sending it, keeps an earlier choice, ignores a language
  the app lacks); the account (a choice is sent at once; a failed send is
  kept and sent at the next session check after a restart, beating an
  older account value; a new phone takes the account's; the account beats
  the sign-up default; an empty account gets the phone's; nothing to send
  when nothing is chosen; an unknown account code is kept and shown as
  English); the localizations (words and plurals in en/am/om; `om` gets
  Flutter's own words in English with no error, `am` its own; English
  with no localizations above).
- `test/features/settings/app_language_setting_test.dart` (3): the row
  names the language in itself; choosing Amharic offline redraws the row
  in Amharic at once and keeps it unsent; choosing the current language
  changes and sends nothing.
- `language_selection_screen_test.dart` (+3): Continue under Amharic
  speakers sets `am`; English speakers `en`; an earlier choice is kept.
- `sign_in_screen_test.dart`: a successful sign-in calls `onSignedIn`
  once (the post-sign-in session check).
- `screen_sweep_test.dart`: the sweep app now has the app-language scope
  and delegates; two scenes added (the sheet in English, and in Afaan
  Oromo) across both sizes, scales and themes.
- `test/l10n/`: parity and the untranslated-text scan (from implement).

Results: `flutter analyze` clean; `flutter test --exclude-tags e2e`
2052 passed.
