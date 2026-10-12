---
unit: 001-voice-settings-service
intent: 027-generated-voice-audio
unit_type: backend
default_bolt_type: simple-construction-bolt
phase: inception
status: complete
created: '2026-10-12T09:55:00Z'
updated: '2026-10-12T09:55:00Z'
---

# Unit Brief: Voice Settings Service

## Purpose

Keep each language's male voice, female voice and default speed on the
server, so that admins can change them without a deploy.

## Scope

### In Scope
- **Domain:** `SUPPORTED_VOICE_LANGUAGES = ("am", "om")` and the default
  voices.
- **Model and migration:** a `voice_settings` table, with a speed check
  constraint of 0–100.
- **Repository:** `get`, `list` and `save` (upsert). Defaults are
  returned when no row exists.
- **API:** `GET /api/v1/admin/voice/settings` and
  `PUT /api/v1/admin/voice/settings/{language}`, both admin-only.
- **Validation:** the speed range and the voice-ID prefix rule.
- Tests.

### Out of Scope
- The Addis catalog check on save. Bolt 092 adds it.
- Calling Addis at all.

---

## Assigned Requirements

| FR | Requirement | Priority |
|----|-------------|----------|
| FR-3 | Voice settings store | Must |
| FR-4 | Read the voice settings | Must |
| FR-5 | Change the voice settings (prefix rule) | Must |

---

## Stories

| Story ID | Title | Priority | Status |
|----------|-------|----------|--------|
| 001-voice-settings-defaults | Each language has voices and a speed, with defaults | Must | Planned (bolt 089) |
| 002-read-voice-settings | Admins can read the voice settings | Must | Planned (bolt 090) |
| 003-change-voice-settings | Admins can change a language's voices and speed | Must | Planned (bolt 090) |

### 001-voice-settings-defaults (FR-3)

**As an** admin, **I want** every supported language to start with
sensible voices, **so that** generation works before anyone opens the
settings.

- [ ] `SUPPORTED_VOICE_LANGUAGES` is `("am", "om")`, defined in the
  domain.
- [ ] The defaults are:
  - `am`: `am-yohanes-calm` (male), `am-loza` (female), speed 50;
  - `om`: `om-diriba` (male), `om-obse` (female), speed 50.
- [ ] The `voice_settings` table has these columns: `language` PK,
  `male_voice_id`, `female_voice_id`, `speed` (int, check 0–100),
  `updated_by` and `updated_at`.
- [ ] The Alembic migration upgrades and downgrades on SQLite and on
  Postgres.
- [ ] `get(language)` returns the defaults while there is no row, with
  `updated_by` and `updated_at` set to null.
- [ ] `save` inserts the row the first time and updates it after that.
  `get` then returns the stored values.
- [ ] `list()` returns `am` then `om`.

### 002-read-voice-settings (FR-4)

**As an** admin, **I want** to see what each language is set to,
**so that** I know which voice will speak.

- [ ] `GET /api/v1/admin/voice/settings` returns `{configured,
  languages: [...]}`. Each language has `language`, `language_name`,
  `male_voice_id`, `female_voice_id`, `speed`, `updated_by` and
  `updated_at`.
- [ ] `language_name` comes from the languages table. When the language
  is not there, it falls back to the code.
- [ ] `configured` is false for now. It reads the Addis key setting once
  bolt 091 adds it, so until then a stub returns false.
- [ ] The route returns 401 without a session and 403 for a non-admin.

### 003-change-voice-settings (FR-5)

**As an** admin, **I want** to choose the voices and speed for a
language, **so that** generated clips sound the way I want.

- [ ] `PUT /api/v1/admin/voice/settings/{language}` with
  `{male_voice_id, female_voice_id, speed}` saves the values and returns
  the saved language.
- [ ] A language other than `am` or `om` gets 404 with `entity:
  "voice_settings"`.
- [ ] A speed that is not a whole number from 0 to 100 gets 422 on
  `speed`.
- [ ] A voice ID that does not start with `{language}-` gets 422 on its
  field, with the message "That is not a voice for {language name}".
- [ ] The response's `updated_by` is the admin's email and `updated_at`
  is now.
- [ ] Each save writes the log line `admin_write action=update
  entity=voice_settings id={language} admin={email}`.
- [ ] Saving one language leaves the other language's settings
  unchanged.

---

## Dependencies

### Depends On
None.

### Depended By
| Unit | Reason |
|------|--------|
| 002-addis-voice-client | Adds the catalog check to PUT, and `configured` |
| 003-voice-generation-api | Resolves the voice and speed from these settings |
| 004-voices-admin-page | Reads and saves them |

---

## Bolt Suggestions

| Bolt | Type | Stories | Objective |
|------|------|---------|-----------|
| 089-voice-settings-store | simple-construction-bolt | 001 | Table, migration, defaults and repository |
| 090-voice-settings-api | simple-construction-bolt | 002, 003 | Admin GET and PUT routes |
