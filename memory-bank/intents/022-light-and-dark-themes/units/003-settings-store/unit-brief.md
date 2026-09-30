---
unit: 003-settings-store
intent: 022-light-and-dark-themes
unit_type: fullstack
default_bolt_type: simple-construction-bolt
phase: inception
status: ready
created: '2026-09-30T13:52:00Z'
updated: '2026-09-30T13:52:00Z'
---

# Unit Brief: Settings Store

## Purpose

Store account settings and app configuration as JSON, read through
registries with defaults, so adding a setting never needs a migration, a
seed or a backfill again.

## Scope

### In Scope
- One migration: `users.settings` (JSON, not null, default `{}`) and
  `app_config` (`key`, `value` JSON, `updated_at`)
- The account settings registry, `PATCH /api/v1/users/me/settings`, and
  `settings` on the session check
- The app configuration registry and `GET /api/v1/config`
- The app: known keys with defaults, unknown keys ignored, the last copy
  kept on the phone
- Tests; API notes

### Out of Scope
- Moving existing columns or constants into the store
- An admin screen for app configuration (open question)

---

## Assigned Requirements

| FR | Requirement | Priority |
|----|-------------|----------|
| FR-8 | Account settings as JSON | Must |
| FR-9 | App configuration as JSON | Should |
| FR-10 | The app reads both, with defaults | Must |

---

## Domain Concepts

| Concept | Description |
|---------|-------------|
| Registry | The list in code of every known key: its type and default. The only place a new setting is declared. |
| Effective settings | The registry's defaults overlaid with the stored values; what every reader sees. |
| App configuration | App-wide values (not per account), one row per key, written without a deploy. |

---

## Stories

| Story ID | Title | Priority | Status |
|----------|-------|----------|--------|
| 007-account-settings-json | Account settings in one JSON column | Must | Complete (bolt 071) |
| 008-app-config | App configuration rows with defaults | Should | Complete (bolt 071) |
| 009-app-reads-settings | The app reads settings and configuration | Must | Planned (bolt 072) |

### 007-account-settings-json (FR-8)

**As a** developer, **I want** new account settings to be one registry
line, **so that** I never write a migration or seed for a setting again.

- [x] `users.settings` exists, defaults to `{}`, and existing rows need no
  backfill.
- [x] Reading returns every registry key: the stored value, else the
  default; stored keys no longer in the registry are ignored.
- [x] `PATCH /api/v1/users/me/settings` merges a partial map; an unknown
  key or a wrong type is refused (422) and nothing is saved.
- [x] The session check and the PATCH return the full map.
- [x] A test adds a key to the registry and reads it for an existing
  account with no migration.

### 008-app-config (FR-9)

**As the** team, **I want** app-wide values in a table with defaults in
code, **so that** changing one needs no deploy and nothing is seeded.

- [x] `app_config` starts empty; a key with no row returns its default.
- [x] `GET /api/v1/config` returns every registry key, no sign-in needed.
- [x] Writing a row changes the value returned, with no code change.
- [x] Nothing secret is allowed in the registry (documented in the file).

### 009-app-reads-settings (FR-10)

**As a** learner on an older app, **I want** the app to keep working when
the backend adds a setting, **so that** updates never break it.

- [ ] The app lists the keys it knows with defaults; a missing key uses
  the default, an unknown one is ignored.
- [ ] Settings come from the session check, configuration from
  `GET /api/v1/config`; the last copy is kept on the phone for offline.
- [ ] Adding a key in the app is one line plus the code that uses it.

---

## Dependencies

### Depends On
None.

### Depended On By
None (future settings build on it).
