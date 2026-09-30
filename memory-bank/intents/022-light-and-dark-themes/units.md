---
intent: 022-light-and-dark-themes
phase: inception
status: units-decomposed
updated: '2026-09-30T13:52:00Z'
---

# Light and Dark Themes - Unit Decomposition

## Units Overview

Three units. The palette comes first, because the dark theme and the
Appearance setting both need screens that read colours from the theme. The
settings store is independent of both and can be built at any point.
Stories are written inside each unit brief (owner's request: keep the file
count small).

### Unit 1: 001-theme-palette

**Description:** One palette file by role, with light and dark; everything
built from it; screens reading colours from the theme; the dark palette;
the contrast test and the gallery preview.

**Requirements:** FR-1, FR-2, FR-3, FR-4, FR-6, FR-7

**Deliverables:**
- `AppPalette` (light and dark), and `AppTheme`, `AppTone` and
  `AppShadows` built from it
- `context.colors` (and tones, shadows) used by every screen and widget;
  a design rule against direct `AppColors` use
- The dark palette, the picture card, system bars, Android launch screen
- The contrast test; the gallery's Colours page and light/dark toggle

**Dependencies:** none. Depended on by unit 2.

**Estimated complexity:** L (a wide but mechanical refactor)

### Unit 2: 002-appearance-setting

**Description:** System, Light or Dark in Settings, kept on the phone and
applied at once.

**Requirements:** FR-5

**Deliverables:**
- An appearance preference on the phone (default System)
- `MaterialApp` with `theme`, `darkTheme` and `themeMode` from it
- The "Appearance" row in Settings

**Dependencies:** `001-theme-palette` (a working dark theme).

**Estimated complexity:** S

### Unit 3: 003-settings-store

**Description:** Account settings in one JSON column and app configuration
in a key/JSON table, both read through registries with defaults, so new
settings need no migration or seed; the app reads both.

**Requirements:** FR-8, FR-9, FR-10

**Deliverables:**
- Migration: `users.settings` (JSON, default `{}`) and `app_config`
- Backend registries, `PATCH /api/v1/users/me/settings`, `settings` on
  the session check, `GET /api/v1/config`; tests; API notes
- App: known keys with defaults, the saved copy on the phone

**Dependencies:** none.

**Estimated complexity:** M

## Requirement-to-Unit Mapping

- **FR-1** One palette file, by role → `001-theme-palette`
- **FR-2** Everything built from the palette → `001-theme-palette`
- **FR-3** Screens read colours from the theme → `001-theme-palette`
- **FR-4** The dark palette → `001-theme-palette`
- **FR-5** The Appearance setting → `002-appearance-setting`
- **FR-6** Preview in the gallery → `001-theme-palette`
- **FR-7** Contrast guard → `001-theme-palette`
- **FR-8** Account settings as JSON → `003-settings-store`
- **FR-9** App configuration as JSON → `003-settings-store`
- **FR-10** The app reads both → `003-settings-store`

## Unit Dependency Graph

```text
[001-theme-palette] ──> [002-appearance-setting]

[003-settings-store]   (independent)
```

## Execution Order

1. `001-theme-palette`: the palette and derived pieces (bolt 066), screens
   onto the theme (bolt 067), the dark palette and contrast test (bolt
   068), the gallery preview (bolt 069)
2. `002-appearance-setting` (bolt 070)
3. `003-settings-store`: the backend (bolt 071), then the app (bolt 072)
