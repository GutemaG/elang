---
intent: 022-light-and-dark-themes
phase: inception
status: complete
created: '2026-09-30T13:18:57Z'
updated: '2026-09-30T13:52:00Z'
---

# Requirements: Light and Dark Themes

## Intent Overview

Give the app a dark theme next to today's light one, let the learner choose
System, Light or Dark in Settings, and rebuild the colour tokens so every
colour of both themes is defined once, in one file, by its role. Changing a
colour then means editing one value, and the whole app follows.

Also (added 2026-09-30 at the owner's request): a settings store in the
database that holds values as JSON, so a new setting or configuration
value never needs a migration, a seed or a backfill again. Adding one is a
single line in a registry in code, with its default.

Type: enhancement plus refactor; mobile, plus one backend migration (the
last one settings should need).

To keep the file count small, this file also holds the system context, and
the unit briefs will hold their stories (as in intents 013 and 021).

### Verified against the source (2026-09-30)

- **Light only.** `AppTheme.light` (`lib/shared/theme/app_theme.dart`) is
  the only theme; `main.dart` sets `theme: AppTheme.light` and no
  `darkTheme`. DESIGN.md (Highland Pulse) describes no dark mode.
- **Colours are fixed constants.** `AppColors` holds about 90 `static const`
  colours named after DESIGN.md tokens (`surfaceContainerLowest`,
  `tileShelf`, `answerCorrect`, ...). Screens and widgets use them directly,
  about 440 times in 40 files. `AppTone` (the tone table), `AppShadows`,
  `AppTypography.textMuted` and the chip and switch themes also read
  `AppColors` directly. So a `darkTheme` alone would change only stock
  Material widgets.
- **The tokens are already respected.** No screen writes its own hex,
  `Colors.white` or `Colors.black`; `test/design/design_rules_test.dart`
  fails any `Color(0x...)` outside `lib/shared/theme/`. The move is
  mechanical.
- **Mixed naming.** Some tokens name a role (`onSurface`, `primary`), others
  name a mockup value or a single use (`cardBevelDefault`, `optionChosen`,
  `dialogShelf`, `lockedNodeIcon`). Several are the same colour under two
  names (`surface`, `surfaceBright` and `background` are all `#FFF8F5`).
- **Device preferences** already exist: the sound switch is kept on the
  phone by `SoundPreferenceRepository` (secure storage, key
  `sound_enabled`).
- **Android** already has a `values-night` resource folder (Flutter's
  default launch theme). The web manifest's colours are Flutter's default
  blue.
- **Each account setting is a column today.** `users` holds
  `selected_language`, `daily_xp_target` and `notification_enabled`; the
  last one needed its own migration with a backfill
  (`e02dd0a9ae54_add_notification_enabled_to_users`), then the domain
  entity, the use case, the router schema and the session answer each
  changed.
- **Game settings are constants in code.** `BEANS_MAX`,
  `BEAN_REGEN_MINUTES` and `REFILL_COST_AMOLE` are Python constants,
  so changing one needs a deploy.
- **JSON columns already work** on both databases: `exercises.content` and
  `answer_key` are SQLAlchemy `JSON` columns, on SQLite locally and
  Postgres (Neon) in production.

## System Context

- **Actors:** the learner; the phone's light/dark setting; the developer
  adding a setting.
- **Mobile app:** the palette, both themes, the Appearance setting, the
  component gallery preview, the design tests; reading account settings
  and app configuration with their defaults.
- **Backend:** `users.settings` (JSON) and an `app_config` table (key and
  JSON value), each read through a registry of known keys and defaults;
  the endpoints that read and change them. One migration.
- **Out of the picture:** the admin site (no editing screen yet), R2
  content. The Appearance choice itself stays on the phone (D3).

## Business Goals

| Goal | Success Metric | Priority |
|------|----------------|----------|
| Comfortable at night | Every screen is usable in dark, with readable text (WCAG AA) | Must |
| The learner decides | System, Light or Dark in Settings, applied at once | Must |
| Colours easy to change | Changing any colour is one edit in one file, for either theme | Must |
| Light stays as it is | Light mode looks the same as before this intent | Must |
| New settings without migrations | Adding a setting or config value is one registry line, with no migration, seed or backfill | Must |

## Functional Requirements

### FR-1: One Palette File, by Role
- **Description**: Every colour of the app lives in one palette file, named
  by what it is for, with a light and a dark value for each.
- **Acceptance Criteria**:
  - One class (`AppPalette`) lists every colour role; the light and dark
    palettes are two instances of it, side by side in one file.
  - Every role is required in both palettes, so a role added to one and
    forgotten in the other does not compile.
  - Role names say what the colour is for (for example `pageBackground`,
    `cardFace`, `cardBorder`, `cardShelf`, `textPrimary`, `textMuted`,
    `answerCorrectFace`); duplicate tokens with the same value and the same
    purpose are merged. The file's header explains how to change a colour.
  - No hex value exists anywhere else in `lib/`.
- **Priority**: Must

### FR-2: Everything Else Is Built From the Palette
- **Description**: The tones, shadows, text colours and the Material theme
  are derived from the palette, never from fixed colours.
- **Acceptance Criteria**:
  - `AppTheme` builds both `ThemeData`s (light and dark) from their palette,
    including the `ColorScheme`, app bar, chips, switches and snack bars.
  - The tone table (neutral, primary, secondary, tertiary) and the shadows
    (shelves, soft shadow, glows, scrim) read their colours from the
    palette of the current theme.
  - Changing one role's value in the palette changes every place that uses
    it, in that theme only.
- **Priority**: Must

### FR-3: Screens Read Colours From the Theme
- **Description**: Screens and shared widgets take their colours from the
  current theme, so they switch with it.
- **Acceptance Criteria**:
  - One short way to read them: `context.colors.<role>` (and
    `context.tones`, `context.shadows` where needed).
  - Nothing outside `lib/shared/theme/` reads `AppColors` or a palette
    instance directly; `design_rules_test.dart` gains that rule.
  - The move is a refactor: light mode looks exactly as before (the
    existing widget, gallery and screen sweep tests pass unchanged).
- **Priority**: Must

### FR-4: The Dark Palette
- **Description**: A warm Highland Pulse dark, not the grey Material
  default.
- **Acceptance Criteria**:
  - Starting values (tunable later in the palette file):

    | Role | Light (today) | Dark |
    |---|---|---|
    | Page | `#FFF8F5` | `#1B1510` |
    | Card face (white today) | `#FFFFFF` | `#251D16` |
    | Card border / shelf | `#EDE5D8` / `#E2D7C5` | `#3A2F26` / `#120D09` |
    | Text / muted text | `#231A11` / `#786A5E` | `#F2DFD1` / `#A8988A` |
    | Green text | `#004527` | `#92D5A9` |
    | Green button / its shelf | `#1B5E3B` / `#124027` | `#1B5E3B` / `#0B2E1A` |
    | Gold text / terracotta text | `#8D4F00` / `#7D0301` | `#FFB875` / `#FFB4A8` |
    | Correct / wrong answer face | `#E8F8F0` / `#FDF0EE` | `#173826` / `#3D1D18` |
    | Streak, gem, XP accents | bright | unchanged |

  - The 3D look stays: every shelf is darker than the face above it and
    than the page, since soft shadows barely show on a dark page.
  - Lesson pictures sit on a light rounded card in dark mode too, so
    pictures drawn on white don't glare.
  - The phone's status and navigation bars follow the theme (light icons
    on dark), and the Android launch screen uses the dark page colour in
    dark mode.
- **Priority**: Must

### FR-5: The Appearance Setting
- **Description**: Settings has an "Appearance" row with System, Light and
  Dark.
- **Acceptance Criteria**:
  - Default: System (follows the phone's own light/dark setting, and
    changes with it while the app is open).
  - The choice applies at once, on every screen, with no restart.
  - It is kept on the phone (like the sound switch), survives restarts and
    sign-out, and also applies to the screens before sign-in.
- **Priority**: Must

### FR-6: Preview in the Gallery
- **Description**: The debug component gallery shows the palette and lets
  the developer flip themes, so a colour change can be checked in seconds.
- **Acceptance Criteria**:
  - A "Colours" page lists every role with its name and its light and dark
    swatch and hex, side by side.
  - A light/dark toggle in the gallery redraws every component page in the
    other theme.
- **Priority**: Should

### FR-7: Contrast Guard
- **Description**: A test checks that text stays readable on its
  background in both palettes, so editing a colour can't quietly break it.
- **Acceptance Criteria**:
  - A listed set of text-on-background pairs (body text on page and card,
    muted text, each tone's ink on its surface, text on each button fill,
    answer states) is checked in both palettes: at least 4.5:1 for body
    text, 3:1 for large text and icons.
  - A failing pair names the two roles and the ratio.
- **Priority**: Must

### FR-8: Account Settings as JSON
- **Description**: Each account has one JSON settings column; new account
  settings go there, not into new columns.
- **Acceptance Criteria**:
  - `users.settings` is a JSON column, never null, empty (`{}`) by default.
    Adding it is this intent's only migration; existing rows need no
    backfill.
  - A registry in the backend code lists every known setting: its key, its
    type (bool, int, string, or one of a fixed list) and its default.
  - Reading an account's settings returns every registry key: the stored
    value if there is one, otherwise the default. So a setting added later
    works for every existing account with no migration, seed or backfill.
  - `PATCH /api/v1/users/me/settings` takes a partial map and merges it:
    an unknown key, or a value of the wrong type, is refused (422) and
    nothing is saved.
  - The session check returns the full `settings` map, and so does the
    PATCH.
  - A stored key that is no longer in the registry is ignored when read.
  - Existing columns (`selected_language`, `daily_xp_target`,
    `notification_enabled`) stay as they are; moving them is not part of
    this intent.
- **Priority**: Must

### FR-9: App Configuration as JSON
- **Description**: App-wide values the team may want to change without a
  deploy live in one `app_config` table, one row per key, with a JSON
  value.
- **Acceptance Criteria**:
  - `app_config` has `key` (primary key), `value` (JSON) and `updated_at`.
    It starts empty; nothing is seeded.
  - A registry in the backend code lists every known key with its type and
    default; reading a key with no row returns its default.
  - `GET /api/v1/config` returns every registry key with its current value
    (no sign-in needed; nothing secret is ever stored there).
  - To change a value, a row is written (by hand or by a script for now);
    no code change or deploy is needed.
  - Existing constants (beans, bean regeneration, refill cost) stay in code
    in this intent; the registry is where they would move later.
- **Priority**: Should

### FR-10: The App Reads Both, With Defaults
- **Description**: The app understands account settings and app
  configuration without breaking when new keys appear.
- **Acceptance Criteria**:
  - The app keeps its own list of the keys it knows, each with a default;
    a missing key uses the default, and an unknown key is ignored, so an
    older app keeps working when the backend adds a setting.
  - The last copy received is kept on the phone, so it also works offline.
  - Adding a setting in the app is one line in that list plus the code that
    uses it.
- **Priority**: Must

## Non-Functional Requirements

- **NFR-1 No light regressions**: all existing tests pass; light mode is
  pixel-identical where tests compare pictures.
- **NFR-2 Performance**: switching theme redraws in one frame; no extra
  work per build beyond reading the theme. Settings add no extra query to
  the session check (they sit on the `users` row); config is one small
  query.
- **NFR-3 Web**: both themes and the setting work on the web build.
- **NFR-4 Accessibility**: WCAG AA contrast (FR-7); the Appearance row is
  one readable node with its current value.
- **NFR-5 Maintainability**: adding a colour role, or a third palette
  later (for example high contrast), touches only the palette file and the
  place that uses the new role. Adding a setting or config key touches only
  its registry line and the code that uses it.
- **NFR-6 Both databases**: the JSON columns behave the same on SQLite
  (local) and Postgres (Neon); tests cover the merge on SQLite. The Neon
  migration runs only with the owner's go-ahead.

## Decisions

- **D1 Palette in Dart, not JSON** (accepted 2026-09-30): the palette is a
  Dart file, so a missing or misspelled role is a compile error and hot
  reload shows a change at once.
- **D2 Default System** (accepted).
- **D3 Appearance kept on the phone only** (accepted): it applies before
  sign-in and is a per-phone choice. The JSON settings store (FR-8) would
  let it follow the account later with one registry line.
- **D4 Warm dark** (accepted): the FR-4 values as the starting point,
  tuned on a real phone during construction.
- **D5 Light values unchanged**: the refactor renames and regroups tokens
  but keeps every light colour's value.
- **D6 Colours stay in the app** (accepted): not changeable from the
  server; the palette file is the one place to edit.
- **D7 Registry with defaults instead of seeds** (the owner's request): a
  value is stored only when it differs from, or was set over, the default.
  Defaults live in code, so there is never anything to seed.
- **D8 JSON, not key-value rows, for accounts**: one column on the `users`
  row the session check already reads, so settings cost no extra query.
  App configuration uses rows, because each key is written on its own.

## Open Questions

| Question | Owner | Status |
|----------|-------|--------|
| Default System, or always start Light? | User | **Resolved** (2026-09-30): System |
| Keep the choice on the phone only, or follow the account? | User | **Resolved** (2026-09-30): phone only |
| Are the FR-4 dark values the right direction? | User | **Resolved** (2026-09-30): yes, tuned on a phone |
| Should colours be changeable without an app update? | User | **Resolved** (2026-09-30): no |
| An admin screen to edit app configuration? | User | Open (recommend later; rows can be written by a script for now) |
