---
unit: 002-localization-foundation
intent: 024-app-localization
unit_type: frontend
default_bolt_type: simple-construction-bolt
phase: inception
status: complete
created: '2026-10-02T19:12:33Z'
updated: '2026-10-02T19:12:33Z'
---

# Unit Brief: Localization Foundation

## Purpose

Make every string in the app translatable, let the learner choose the app
language, keep that choice on the phone and the account, and stop
untranslated text from creeping back in.

## Scope

### In Scope
- `flutter_localizations` and `intl`; `l10n.yaml`; `lib/l10n/app_en.arb`
  (template), `app_am.arb`, `app_om.arb`; generated `AppLocalizations`
- English for any key missing in `am`/`om`; English Material and Cupertino
  texts for `om` (Flutter has none)
- One list of app languages (code and own name), used by the picker, the
  sign-up default and the fallback
- The app language on the phone (an `AppLanguageRepository`, like
  `AppearanceRepository`), loaded before the first frame
- "App language" in Settings: a row with the current language's own name,
  a sheet with the list, applied at once
- The sign-up default from `fromLanguageCode`, unless a language is
  already chosen
- The account setting `app_language` (bolt 077, through the existing
  `AccountSettings` client; `""` = not chosen): the
  app sends a change, re-sends a failed one on the next session check,
  takes the account's on sign-in and fills an empty account from the phone
- Tests: key parity across the ARB files; a scan of `lib/` for
  user-visible literals, with an allow-list of files not translated yet
  (unit 3 empties it)

### Out of Scope
- Translating the screens (unit 3), apart from the words this unit adds
- The daily reminder and dates (unit 3)

---

## Assigned Requirements

| FR | Requirement | Priority |
|----|-------------|----------|
| FR-1 | Localization set-up | Must |
| FR-2 | Every app string translated (guards) | Must |
| FR-3 | English by default, then the sign-up choice | Must |
| FR-4 | "App language" in Settings | Must |
| FR-5 | Kept on the phone | Must |
| FR-6 | Kept on the account (app) | Must |

---

## Stories

| Story ID | Title | Priority | Status |
|----------|-------|----------|--------|
| 002-arb-files-and-fallback | ARB files, generated strings, English fallback | Must | Complete (bolt 078) |
| 003-app-language-on-the-phone | The choice kept on the phone | Must | Complete (bolt 078) |
| 004-app-language-in-settings | Choose the app language in Settings | Must | Complete (bolt 078) |
| 005-sign-up-sets-the-language | The "I speak" choice sets it at sign-up | Must | Complete (bolt 078) |
| 006-app-language-follows-the-account | The choice follows the account | Must | Complete (bolt 078) |
| 007-translation-guards | Tests that keep every string translated | Must | Complete (bolt 078) |

### 002-arb-files-and-fallback (FR-1)

**As a** developer, **I want** one ARB file per language and typed
accessors, **so that** adding a string or a language is routine.

- [x] `flutter gen-l10n` builds `AppLocalizations` from `lib/l10n/*.arb`
  with English as the template; `MaterialApp` gets the delegates and the
  supported locales.
- [x] A key missing from `app_am.arb` or `app_om.arb` shows the English
  text.
- [x] With the app in `om`, Flutter's own texts (e.g. the text field's
  copy/paste menu) are English and nothing throws.
- [x] Placeholders and plurals work (a sample key with a count is tested
  in all three languages).

### 003-app-language-on-the-phone (FR-5)

**As a** learner, **I want** the app to remember my language, **so that**
it opens in it every time.

- [x] The choice is saved on the phone and applied before the first frame:
  no flash of English.
- [x] Sign-out keeps it.
- [x] Nothing stored, or a code the app has no file for: English.

### 004-app-language-in-settings (FR-4)

**As a** learner, **I want** to change the app language in Settings, **so
that** I can use the app in the language I read best.

- [x] Settings shows "App language" with the current language's own name.
- [x] Tapping it opens the list (English, አማርኛ, Afaan Oromoo), the current
  one marked; choosing one closes the sheet and Settings redraws in the
  new language at once, with no restart.
- [x] Works offline; in both themes; in the screen sweep.

### 005-sign-up-sets-the-language (FR-3)

**As a** new learner who chose "For Amharic speakers", **I want** the app
to switch to Amharic, **so that** I don't have to find the setting.

- [x] Continue on the language screen sets the app language to the
  spoken language when the app has it; otherwise it stays as it is.
- [x] A language already chosen on this phone is not overridden.
- [x] Switching course later (dashboard, Settings) never changes it.

### 006-app-language-follows-the-account (FR-6)

**As a** learner with a new phone, **I want** the app in my language after
I sign in, **so that** I don't set it up twice.

- [x] A change in Settings is sent with `PATCH /api/v1/users/me/settings`;
  a failure
  leaves the phone's choice as it is and is sent again on the next
  successful session check.
- [x] Signing in to an account that has an app language switches the app
  to it.
- [x] An account with none takes the phone's on sign-in or session check.
- [x] A code from the account that the app has no file for is kept but
  shown as English.

### 007-translation-guards (FR-2, NFR-3)

**As a** developer, **I want** tests to catch untranslated text, **so
that** every new screen is translated from day one.

- [x] A test fails if a key in `app_en.arb` is missing from `app_am.arb` or
  `app_om.arb`, or has no `@key` description.
- [x] A test scans `lib/` (skipping generated code and the gallery) and
  fails on a user-visible string literal in a file outside its
  allow-list; the allow-list names the files unit 3 has yet to translate,
  and a file that has been translated but is still listed also fails.

---

## Dependencies

### Depends On
- `001-app-language-service` (the account field)

### Depended On By
- `003-screen-translations`
