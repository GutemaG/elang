---
unit: 003-screen-translations
intent: 024-app-localization
unit_type: frontend
default_bolt_type: simple-construction-bolt
phase: inception
status: complete
created: '2026-10-02T19:12:33Z'
updated: '2026-10-02T19:12:33Z'
---

# Unit Brief: Screen Translations

## Purpose

Put every word the app shows into the ARB files, in English, Amharic and
Afaan Oromo, and make sure every screen still fits in every language.

## Scope

### In Scope
- Each screen's and shared widget's strings moved to ARB keys with
  `@key` descriptions, and drafted in `am` and `om`
- The daily reminder's title and body; rescheduling on a language change
- Dates: month and weekday names from the app language (`intl`),
  Gregorian, Western digits; durations as ARB plurals
- League tier names and other app-side labels
- The screen sweep in `am` and `om`
- Emptying the allow-list from story 007
- A reviewer's guide in this intent folder

### Out of Scope
- Course content, course titles, server-sent language names
- The admin site

---

## Assigned Requirements

| FR | Requirement | Priority |
|----|-------------|----------|
| FR-2 | Every app string translated | Must |
| FR-7 | The daily reminder in the app language | Must |
| FR-8 | Dates and numbers | Should |
| FR-9 | Every layout holds in every language | Must |
| FR-10 | Translations reviewable by a native speaker | Should |

---

## Stories

| Story ID | Title | Priority | Status |
|----------|-------|----------|--------|
| 008-onboarding-and-sign-in | Onboarding and sign-in translated | Must | Complete (bolt 079) |
| 009-settings-and-feedback | Settings, feedback and downloads translated | Must | Complete (bolt 079) |
| 010-daily-reminder | The daily reminder in the app language | Must | Complete (bolt 079) |
| 011-dashboard-path-and-courses | Dashboard, path and courses translated | Must | Complete (bolt 079) |
| 012-league-and-stat-sheets | League and stat sheets translated | Must | Complete (bolt 079) |
| 013-dates-in-the-app-language | Month and weekday names in the app language | Should | Complete (bolt 079) |
| 014-lessons-exercises-and-practice | Lessons, exercises and practice translated | Must | Complete (bolt 079) |
| 015-every-screen-in-every-language | The sweep in every language; allow-list empty | Must | Complete (bolt 079) |
| 016-reviewer-guide | A guide for the native-speaker reviewer | Should | Complete (bolt 079) |

### 008-onboarding-and-sign-in (FR-2)

**As a** learner, **I want** sign-up in my language from the moment I pick
it, **so that** the first minutes feel made for me.

- [x] Splash, carousel, language selection, daily goal and sign-in
  (including errors and the waitlist message) read from the ARB files.
- [x] The language screen's own prompts (`LearnPrompts`) come from the ARB
  files of the language they are for.
- [x] Tests that find text by its English words still pass; new tests
  check one screen in `am` and `om`.

### 009-settings-and-feedback (FR-2)

**As a** learner, **I want** Settings and Send feedback in my language.

- [x] Settings, its sheets and dialogs, Send feedback, downloads, and the
  course picker sheet's words are translated.
- [x] Snack bars and error messages on these screens too.

### 010-daily-reminder (FR-7)

**As a** learner, **I want** the reminder in my language, **so that** it
reads like the app.

- [x] The scheduled reminder's title and body are in the app language.
- [x] Changing the language reschedules pending reminders with the new
  words.

### 011-dashboard-path-and-courses (FR-2)

**As a** learner, **I want** the home screen in my language.

- [x] Dashboard, path nodes and popovers (including START), section
  headers, the course chip and panel, Practice and banners are
  translated.
- [x] Shared widgets' built-in words (e.g. Retry, Close tooltips) are
  translated.

### 012-league-and-stat-sheets (FR-2)

**As a** learner, **I want** the league and my stats in my language.

- [x] The league screen, result sheet, dashboard card and tier names; the
  streak, beans, XP and Amole sheets are translated.

### 013-dates-in-the-app-language (FR-8)

**As a** learner, **I want** dates in my language without a different
calendar.

- [x] The streak calendar's month and weekday names, the league countdown
  and "time left" lines follow the app language; Gregorian, Western
  digits.
- [x] Durations use ARB plurals ("1 day" / "2 days").

### 014-lessons-exercises-and-practice (FR-2)

**As a** learner, **I want** the lesson's instructions and buttons in my
language, **so that** I understand what to do.

- [x] Every exercise type's instruction, Check/Continue/Skip, correct and
  wrong feedback, the lesson-complete screen, practice and their errors
  are translated; the lesson content itself is unchanged.

### 015-every-screen-in-every-language (FR-9, FR-2)

**As a** learner, **I want** nothing cut off in my language.

- [x] The screen sweep runs every scene in `en`, `am` and `om` (360x640 and
  430x932, 1.0x and 1.3x, light and dark) with no overflow.
- [x] The allow-list from story 007 is empty, and the scan passes.

### 016-reviewer-guide (FR-10)

**As a** native-speaker reviewer, **I want** to know how to check and fix
the text, **so that** I can do it without a developer.

- [x] `translation-guide.md` in this intent folder: where the files are,
  how keys, descriptions and `{placeholders}` work, plural forms, and
  the terms to keep consistent (XP, streak, Amole, league tier names).

---

## Dependencies

### Depends On
- `002-localization-foundation`

### Depended On By
None.
