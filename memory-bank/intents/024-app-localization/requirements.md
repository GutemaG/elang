---
intent: 024-app-localization
phase: inception
status: complete
created: '2026-10-02T19:06:01Z'
updated: '2026-10-02T19:12:33Z'
---

# Requirements: App Localization

## Intent Overview

Show the app's own words (buttons, headings, messages, Settings,
notifications) in the learner's chosen language, starting with English,
Amharic and Afaan Oromo, and built so another language is one more
translation file. Lesson content is not part of this: it already comes from
the course.

Type: enhancement; mobile (localization set-up, a Settings picker, every
screen's text, the daily reminder) and backend (one account setting; no
migration, as revised in bolt 077).

## Goal

A learner who reads Amharic or Afaan Oromo better than English can use the
whole app in that language, and keeps that choice on a new phone.

## Scope

In scope:

- English, Amharic and Afaan Oromo for every string the app itself shows,
  including the daily reminder notification.
- English as the default. Choosing a language at sign-up ("For Amharic
  speakers") switches the app to that language, if the app has it.
- An "App language" choice in Settings, applied at once.
- The choice kept on the phone (so it works before sign-in and survives
  sign-out) and on the account (so it follows the learner to a new phone).
- Adding a language later needs only a translation file, plus its name in
  the Settings picker.
- Claude drafts the Amharic and Afaan Oromo text; a native speaker reviews
  it. The drafts ship without a "beta" label.

Out of scope:

- Lesson and course content, course titles, and anything else typed in the
  admin site (already per course).
- The admin site itself (stays English).
- Flutter's own widget texts in Afaan Oromo (date pickers, the copy/paste
  menu): Flutter has no Oromo for these, so they fall back to English.
- The Ethiopian calendar and Ge'ez numerals.
- Right-to-left languages.

## Decisions taken with the user (2026-10-02)

| Question | Answer |
|---|---|
| Default language | English, then the sign-up "I speak" choice |
| Does switching course change it later? | No; after sign-up only Settings changes it |
| Where the choice is kept | On the phone and on the account |
| Daily reminder | Translated |
| Dates and numbers | Gregorian calendar and Western digits, with the language's month and weekday names |
| Release before native review | Yes, with no "beta" label |
| Who writes the translations | Claude drafts, a native speaker reviews |
| How the work is run | This intent, split into bolts |

### Verified against the source (2026-10-02)

- **No localization exists yet.** `pubspec.yaml` has neither
  `flutter_localizations` nor `intl`; every string is a literal in the
  widget that shows it, and dates are formatted by hand.
- **Phone-only preferences have a pattern.** `AppearanceRepository` and
  `SoundPreferenceRepository` keep a choice in secure storage, applied
  before sign-in and kept through sign-out.
- **The account's preferences have a pattern.** `PATCH /api/v1/users/me`
  (`UserPreferencesApi`) updates `selected_language` (the language being
  *learned*), `daily_xp_target` and `notification_enabled`; session
  validation returns the same fields. The app language is a different
  thing from `selected_language` and gets its own field.
- **Sign-up already records the spoken language.** The pending onboarding
  selection holds `fromLanguageCode`, which is what decides the default.
- **League tier names are in the app** (`league_models.dart`), so they are
  translated like any other string.
- **Flutter's Material and Cupertino texts** exist for `am` but not for
  `om`.


## System Context

To keep the file count small, the system context is held here, and the
unit briefs hold their stories (as in intents 021 to 023).

- **Actors:** the learner; a native-speaker reviewer, who edits the ARB
  files.
- **Mobile app:** the ARB files and generated localizations; the app
  language kept on the phone and applied at start-up; the "App language"
  picker in Settings; the sign-up default; sending the choice to the
  account and taking it from the account; every screen's words; the daily
  reminder; dates.
- **Backend:** one account setting, `app_language`, in the existing
  `users.settings` map (no migration), written by
  `PATCH /api/v1/users/me/settings` and returned by session validation.
- **Out of the picture:** the admin site, R2, course content.

```text
            +--------------------------- phone ----------------------------+
 learner -> | Settings picker / sign-up default -> app language (storage)  |
            |        |                                   |                 |
            |        v                                   v                 |
            |  MaterialApp(locale) -> AppLocalizations (en / am / om ARB)  |
            |        |                                                     |
            |        +-> daily reminder text                               |
            +--------|-----------------------------------------------------+
                     | PATCH /users/me {app_language}; session validate
                     v
            backend: users.settings.app_language ("" or 2-3 letters)
```

---

## Functional Requirements

### FR-1: Localization set-up

- **Description**: The app uses Flutter's standard localization: one ARB
  file per language (`app_en.arb`, `app_am.arb`, `app_om.arb`) and
  generated, typed accessors. English is the template; every key has an
  English value.
- **Acceptance Criteria**:
  - Screens read their words from the generated localizations, not from
    string literals.
  - A key missing from `am` or `om` shows the English text, never the key
    or an empty string.
  - Adding a language is: a new ARB file, plus its entry in the list of
    app languages (FR-4). No screen changes.
  - Plurals and values inside sentences ("3 of 10 skills", "1 day" /
    "2 days") use ARB placeholders and plural forms, not string
    concatenation.
- **Priority**: Must

### FR-2: Every app string translated

- **Description**: Every word the app itself shows is in the ARB files and
  translated into Amharic and Afaan Oromo: onboarding and sign-in, the
  dashboard and path, lessons and exercises (instructions, buttons,
  feedback), practice, the league, stat sheets, Settings, feedback,
  downloads, errors and empty states, dialogs and snack bars, and
  accessibility labels and tooltips.
- **Acceptance Criteria**:
  - A test scans `lib/` (outside generated code and the design gallery)
    and fails on a user-visible string literal that is not in the ARB
    files, in the way `design_rules_test.dart` guards the design library.
  - Every key in `app_en.arb` has a value in `app_am.arb` and `app_om.arb`
    (a test checks this).
  - Lesson content, course titles and language names as sent by the server
    are shown unchanged.
- **Priority**: Must

### FR-3: English by default, then the sign-up choice

- **Description**: A new install shows English. When the learner chooses
  what to learn at sign-up, the app switches to their spoken language
  (`fromLanguageCode`) if the app has that language, and stays English if
  it does not. Switching course later never changes the app language.
- **Acceptance Criteria**:
  - Fresh install: the splash, carousel and language screen are English.
  - Choosing a course under "For Amharic speakers" and pressing Continue
    makes the next screen (daily goal) Amharic; under "For Afaan Oromo
    speakers", Afaan Oromo; under a language the app has no file for,
    English.
  - Switching course from the dashboard or Settings leaves the app
    language as it was.
  - If the learner already set an app language (Settings, or a previous
    sign-in on this phone), sign-up does not override it.
- **Priority**: Must

### FR-4: "App language" in Settings

- **Description**: Settings has an "App language" row showing the current
  language by its own name (English, አማርኛ, Afaan Oromoo). Tapping it opens
  the list of app languages; choosing one applies at once, everywhere,
  without a restart.
- **Acceptance Criteria**:
  - The list shows every app language by its own name, the current one
    marked.
  - After choosing, Settings itself and every screen behind it are in the
    new language with no restart.
  - The choice works signed out (from the sign-in screen's path) as well
    as signed in.
- **Priority**: Must

### FR-5: Kept on the phone

- **Description**: The chosen language is saved on the phone, like
  Appearance, and applied at start-up before the first frame.
- **Acceptance Criteria**:
  - Restarting the app keeps the language, with no flash of English first.
  - Signing out keeps the language.
  - A stored value the app no longer has a file for falls back to English.
- **Priority**: Must

### FR-6: Kept on the account

- **Description**: The backend stores the learner's app language as the
  account setting `app_language` (`PATCH /api/v1/users/me/settings`,
  returned in `settings` by session validation), so it follows them to a
  new phone. (revised in bolt 077: an account setting, not a column)
- **Acceptance Criteria**:
  - Changing it in Settings saves it on the phone at once and then on the
    account. A failed save (offline, server error) does not undo the
    change on the phone; the app sends it again on the next successful
    session check.
  - Signing in on a new phone switches the app to the account's language.
  - An account with no app language yet (`""`: every existing learner,
    and a new one) takes the phone's language on its first sign-in or session check.
  - The backend accepts any 2-3 letter lowercase code and rejects anything
    else with 422, so a new app language needs no backend change. The app
    shows English for a code it has no file for.
  - No migration: `""` (not chosen) is the setting's default, so every
    existing account reads it at once.
- **Priority**: Must

### FR-7: The daily reminder in the app language

- **Description**: The daily reminder's title and text are in the app
  language. Changing the language reschedules pending reminders so the
  next one uses the new words.
- **Acceptance Criteria**:
  - With the app in Amharic, the scheduled reminder's title and body are
    the Amharic strings.
  - After changing the language, the next reminder uses the new language.
- **Priority**: Must

### FR-8: Dates and numbers

- **Description**: Dates keep the Gregorian calendar and Western digits,
  with month and weekday names in the app language (the streak calendar,
  the league countdown, "last active" lines).
- **Acceptance Criteria**:
  - The streak calendar's weekday letters and month name follow the app
    language.
  - Durations ("2 days left", "5 h") use the ARB plural forms.
  - Numbers keep Western digits and the existing thousands separator.
- **Priority**: Should

### FR-9: Every layout holds in every language

- **Description**: Amharic (Ge'ez script) and Afaan Oromo (often longer
  words than English) must fit every screen as English does.
- **Acceptance Criteria**:
  - The screen sweep (`screen_sweep_test.dart`: 360x640 and 430x932, 1.0x
    and 1.3x text, light and dark) also runs in `am` and `om`, with no
    overflow.
  - Ge'ez text uses the font and line height the app already uses for
    Amharic content (`AppTypography.forText`).
- **Priority**: Must

### FR-10: Translations reviewable by a native speaker

- **Description**: A reviewer who does not read Dart can check and fix the
  translations.
- **Acceptance Criteria**:
  - Every ARB key has a `@key` description saying where the text appears.
  - A short guide (in the intent folder) says how to edit the ARB files and
    lists the words to keep consistent (XP, streak, Amole, league names).
- **Priority**: Should

---

## Non-Functional Requirements

### NFR-1: Performance

| Requirement | Metric | Target |
|---|---|---|
| Language switch | Time from tap to the whole app redrawn | One frame; no restart, no network wait |
| Start-up | Extra start-up time from loading the language | < 20 ms (one secure-storage read, already done for Appearance) |

### NFR-2: Reliability

| Requirement | Metric | Target |
|---|---|---|
| Missing translation | What the learner sees | The English text, never a key or a blank |
| Account save failure | Effect on the phone | None; retried on the next session check |
| Offline | Language switch | Works fully offline |

### NFR-3: Maintainability

| Requirement | Metric | Target |
|---|---|---|
| New language | Files touched | One ARB file and the language list |
| Untranslated literal | Detection | Fails a test in CI |
| Key parity | Detection | A test fails if am/om lacks a key |

### NFR-4: Accessibility

| Requirement | Standard | Notes |
|---|---|---|
| Screen readers | The locale is set on the app | TalkBack/VoiceOver read Amharic with an Amharic voice where the phone has one |
| Labels | Semantics labels and tooltips are translated | Same keys as the visible text where they match |

### NFR-5: Security and privacy

| Requirement | Standard | Notes |
|---|---|---|
| Account field | Validated input | 2-3 lowercase letters, else 422 |
| Logging | No change | The language code is not personal data, but no new logging is added |
