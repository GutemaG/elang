---
unit: 001-theme-palette
intent: 022-light-and-dark-themes
unit_type: frontend
default_bolt_type: simple-construction-bolt
phase: inception
status: ready
created: '2026-09-30T13:52:00Z'
updated: '2026-09-30T18:54:45Z'
---

# Unit Brief: Theme Palette

## Purpose

Put every colour in one palette file, by role, with a light and a dark
value, and make the whole app draw from the current theme's palette, so a
colour change is one edit and dark mode works everywhere.

## Scope

### In Scope
- `AppPalette` with its light and dark instances
- `AppTheme` (both `ThemeData`s), `AppTone`, `AppShadows` and the text
  colours built from the palette
- Moving screens and shared widgets to `context.colors`
- The dark values, the picture card, system bars, Android launch screen
- The contrast test; the gallery's Colours page and theme toggle

### Out of Scope
- The Settings row and saving the choice (unit 2)
- Colours from the server (D6)

---

## Assigned Requirements

| FR | Requirement | Priority |
|----|-------------|----------|
| FR-1 | One palette file, by role | Must |
| FR-2 | Everything built from the palette | Must |
| FR-3 | Screens read colours from the theme | Must |
| FR-4 | The dark palette | Must |
| FR-6 | Preview in the gallery | Should |
| FR-7 | Contrast guard | Must |

---

## Domain Concepts

| Concept | Description |
|---------|-------------|
| Role | What a colour is for (`cardFace`, `textMuted`), not what it looks like; the unit of change. |
| Palette | One value for every role. Light and dark are two palettes of the same class. |
| Derived pieces | The tone table, shadows, text styles and `ThemeData`, computed from a palette. |

---

## Stories

| Story ID | Title | Priority | Status |
|----------|-------|----------|--------|
| 001-palette-by-role | One palette file, and everything built from it | Must | Complete (bolt 066) |
| 002-screens-read-theme | Screens take colours from the theme | Must | Complete (bolt 067) |
| 003-dark-palette | The dark palette | Must | Complete (bolt 068) |
| 004-contrast-guard | Text stays readable in both palettes | Must | Complete (bolt 068) |
| 005-gallery-preview | See the palette and flip themes in the gallery | Should | Planned (bolt 069) |

### 001-palette-by-role (FR-1, FR-2)

**As a** developer, **I want** every colour in one file, by role, **so
that** changing one is a single edit.

- [x] `AppPalette` lists every role; `light` holds today's values exactly.
- [x] Every role is required, so a palette missing one doesn't compile.
- [x] Duplicate tokens with the same value and purpose are merged; the
  file header says how to change a colour.
- [x] `AppTheme`, `AppTone`, `AppShadows` and the text colours are built
  from a palette; no hex exists outside the palette file.
- [x] Light mode looks exactly as before.

### 002-screens-read-theme (FR-3)

**As a** learner, **I want** every screen to follow the theme, **so that**
dark mode has no light patches.

- [x] Screens and shared widgets read `context.colors` (and tones and
  shadows) instead of `AppColors`.
- [x] A design rule fails any `AppColors` or palette-instance use outside
  `lib/shared/theme/`.
- [x] All existing tests pass unchanged.

### 003-dark-palette (FR-4)

**As a** learner, **I want** a warm, readable dark theme, **so that** the
app is comfortable at night.

- [x] The dark palette starts from the FR-4 values; every shelf is darker
  than its face and the page.
- [x] `AppTheme.dark` exists; the screen sweep renders every screen in
  dark without errors.
- [x] Lesson pictures sit on a light card in dark.
- [x] Status and navigation bar icons follow the theme; the Android launch
  screen uses the dark page colour at night.

### 004-contrast-guard (FR-7)

**As a** developer, **I want** a test that checks contrast, **so that** a
colour edit can't make text unreadable.

- [x] Listed text/background pairs are checked in both palettes: 4.5:1 for
  body text, 3:1 for large text and icons.
- [x] A failure names both roles, the palette and the ratio.

### 005-gallery-preview (FR-6)

**As a** developer, **I want** to see every colour and flip themes in the
gallery, **so that** I can check a change in seconds.

- [ ] A Colours page lists each role with its light and dark swatch and
  hex.
- [ ] A toggle redraws every gallery page in the other theme.

---

## Dependencies

### Depends On
None.

### Depended On By
`002-appearance-setting`.
