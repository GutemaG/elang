---
unit: 001-app-language-service
intent: 024-app-localization
unit_type: backend
default_bolt_type: simple-construction-bolt
phase: inception
status: complete
created: '2026-10-02T19:12:33Z'
updated: '2026-10-02T19:12:33Z'
---

# Unit Brief: App Language Service

## Purpose

Keep the learner's app language on their account, so it follows them to a
new phone.

## Scope

### In Scope
(revised in bolt 077: an account setting, not a column)

- An optional `pattern` on `str` settings (`app/domain/settings.py`)
- `app_language` in `ACCOUNT_SETTINGS`: default `""` (not chosen); `""` or
  2-3 lowercase letters, else `422 invalid_setting`
- Written by the existing `PATCH /api/v1/users/me/settings`; returned in
  `settings` by it and by session validation
- Tests; the API notes

### Out of Scope
- A list of allowed languages on the server (the app decides which it
  has)
- The admin site
- A migration (none is needed)

---

## Assigned Requirements

| FR | Requirement | Priority |
|----|-------------|----------|
| FR-6 | Kept on the account (backend) | Must |

---

## Stories

| Story ID | Title | Priority | Status |
|----------|-------|----------|--------|
| 001-app-language-on-the-account | Store and return the app language | Must | Complete (bolt 077) |

### 001-app-language-on-the-account (FR-6)

**As a** learner, **I want** my app language saved with my account, **so
that** a new phone shows the app in my language after I sign in.

- [x] `PATCH /api/v1/users/me/settings` with `{"app_language": "am"}`
  stores it and returns it; other settings are unchanged.
- [x] `"AM"`, `"amharic"`, `"a"` and non-strings are 422, nothing saved;
  `""` (clear) and `"sid"` are accepted.
- [x] Session validation returns `settings.app_language`: `""` for an
  account that never set it.
- [x] No migration; the Alembic head is unchanged.
- [x] The other settings and preferences behave exactly as before.

---

## Dependencies

### Depends On
None.

### Depended On By
- `002-localization-foundation`
