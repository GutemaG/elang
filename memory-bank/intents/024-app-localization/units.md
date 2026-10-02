---
intent: 024-app-localization
phase: inception
status: units-decomposed
updated: '2026-10-02T19:12:33Z'
---

# App Localization - Unit Decomposition

## Units Overview

Three units: the backend stores the choice, the app's foundation makes any
string translatable and the language choosable, and the translation unit
moves every screen onto the ARB files, group by group. Stories are written
inside each unit brief, numbered across the intent.

### Unit 1: 001-app-language-service

**Description:** The learner's app language on the account: one account
setting, written by `PATCH /api/v1/users/me/settings` and returned by
session validation. (revised in bolt 077: an account setting, not a column)

**Requirements:** FR-6 (backend)

**Deliverables:**
- `Setting` gains an optional `pattern`; `app_language` is added to
  `ACCOUNT_SETTINGS` (`""` or 2-3 lowercase letters, else 422)
- No migration
- Tests; API notes

**Dependencies:** none. Depended on by unit 2.

**Estimated complexity:** S

### Unit 2: 002-localization-foundation

**Description:** Flutter localization set-up, the app language on the
phone and the account, the Settings picker, the sign-up default, and the
tests that keep every string translated.

**Requirements:** FR-1, FR-3, FR-4, FR-5, FR-6 (app), FR-2 (guards)

**Deliverables:**
- `flutter_localizations`, `intl`, `l10n.yaml`, `app_en/am/om.arb` and the
  generated `AppLocalizations`; an English fallback for missing keys and
  for Flutter's own texts in `om`
- The list of app languages, in one place
- The app language kept on the phone and applied before the first frame
- "App language" in Settings, applied at once
- The sign-up default from the "I speak" choice
- Sending the choice to the account, and taking the account's on sign-in
- Key-parity test; untranslated-literal scan with a shrinking allow-list

**Dependencies:** `001-app-language-service` (for the account part).
Depended on by unit 3.

**Estimated complexity:** M

### Unit 3: 003-screen-translations

**Description:** Every screen's words, the daily reminder and dates moved
onto the ARB files and translated into Amharic and Afaan Oromo, every
layout checked in every language, and a guide for the reviewer.

**Requirements:** FR-2, FR-7, FR-8, FR-9, FR-10

**Deliverables:**
- Onboarding, sign-in, Settings, feedback and the reminder translated
- Dashboard, path, courses, league, stat sheets and dates translated
- Lessons, exercises and practice translated; shared widgets' words
- The screen sweep in `am` and `om`; the allow-list emptied
- The reviewer's guide

**Dependencies:** `002-localization-foundation`.

**Estimated complexity:** L

## Requirement-to-Unit Mapping

- **FR-1** Localization set-up → `002-localization-foundation`
- **FR-2** Every app string translated → `003-screen-translations` (guards in `002-localization-foundation`)
- **FR-3** English by default, then the sign-up choice → `002-localization-foundation`
- **FR-4** "App language" in Settings → `002-localization-foundation`
- **FR-5** Kept on the phone → `002-localization-foundation`
- **FR-6** Kept on the account → `001-app-language-service` (setting); `002-localization-foundation` (sending and taking)
- **FR-7** The daily reminder → `003-screen-translations`
- **FR-8** Dates and numbers → `003-screen-translations`
- **FR-9** Every layout holds → `003-screen-translations`
- **FR-10** Reviewable translations → `003-screen-translations`

## Unit Dependency Graph

```text
[001-app-language-service] ──> [002-localization-foundation] ──> [003-screen-translations]
```

## Execution Order

1. `001-app-language-service`: the account setting (bolt 077)
2. `002-localization-foundation`: set-up, phone and account, Settings,
   sign-up default, guards (bolt 078)
3. `003-screen-translations`: onboarding, Settings, feedback and the
   reminder (bolt 079); dashboard, path, courses, league and dates
   (bolt 080); lessons, exercises and practice, the sweep in every
   language and the reviewer's guide (bolt 081)
