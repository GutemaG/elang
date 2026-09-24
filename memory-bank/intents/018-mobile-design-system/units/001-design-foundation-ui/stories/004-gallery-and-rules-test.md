---
id: 004-gallery-and-rules-test
unit: 001-design-foundation-ui
intent: 018-mobile-design-system
status: complete
priority: must
created: '2026-09-24T12:55:00Z'
assigned_bolt: 042-design-foundation
implemented: true
---

# Story: 004-gallery-and-rules-test

## User Story

**As a** Buna developer
**I want** one screen that shows every token and component in every state, and a test that fails when a screen draws its own decoration
**So that** I can check a design against its reference in one place and consistency cannot quietly drift again

## Acceptance Criteria

- [x] **Given** a debug build, **When** the developer opens the gallery (a debug-only entry, e.g. a long-press on the Settings title or a debug route), **Then** it lists the colour, shadow and radius tokens, the type scale with Latin and Fidel samples, and every component with all its states
- [x] **Given** a release build, **When** built, **Then** the gallery cannot be reached (guarded by `kDebugMode`, and its entry point is absent)
- [x] **Given** the rules test, **When** it scans `lib/`, **Then** it fails on a `Color(0x…)` outside `lib/shared/theme/`, and outside `lib/shared/` on: `BoxShadow(`, a numeric `BorderRadius.circular(`, `TextButton`/`ElevatedButton`/`FilledButton`/`OutlinedButton`/bare `IconButton(`, `showModalBottomSheet`/`showDialog`, and a `Scaffold` `backgroundColor:`
- [x] **Given** files not yet migrated, **When** the rules test runs, **Then** they are skipped through a named allow-list in the test; any file **not** on the list that breaks a rule fails the test
- [x] **Given** the gallery test, **When** it builds the gallery at 360×640 and 430×932, at 1.0× and 1.3× text, **Then** there is no overflow

## Reference Design (FR-11)

- Storybook / Widgetbook-style catalogues as the pattern (fetched in Plan); no mockup exists

## Technical Notes

- Keep it dependency-free (a plain `ListView` of sections), unless Plan finds a strong reason for `widgetbook`.
- Each later story adds its components to the gallery and removes its migrated files from the allow-list.

## Dependencies

### Requires
- 001-design-tokens-shadows-and-motion
- 002-bundled-fonts-with-ethiopic-fallback
- 003-buttons

### Enables
- Every later story (gallery entries and allow-list shrinkage)

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| A rule needs a legitimate exception inside a feature file | Move that code into `lib/shared/widgets/` instead of widening the rule |

## Out of Scope

- Golden (screenshot) tests (Checkpoint 1: 5a)
