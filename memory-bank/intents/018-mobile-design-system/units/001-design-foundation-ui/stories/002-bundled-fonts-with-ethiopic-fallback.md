---
id: 002-bundled-fonts-with-ethiopic-fallback
unit: 001-design-foundation-ui
intent: 018-mobile-design-system
status: complete
priority: must
created: '2026-09-24T12:55:00Z'
assigned_bolt: 042-design-foundation
implemented: true
---

# Story: 002-bundled-fonts-with-ethiopic-fallback

## User Story

**As a** Buna learner
**I want** the same typeface on my Android phone and my friend's iPhone, in English and Amharic
**So that** the app looks like one designed product rather than whatever each phone defaults to

## Acceptance Criteria

- [x] **Given** `pubspec.yaml`, **When** the app builds, **Then** Plus Jakarta Sans 400/500/700/800 and Noto Sans Ethiopic are bundled from `assets/fonts/`, each with its OFL licence file
- [x] **Given** `AppTypography`, **When** any style renders Fidel, **Then** it falls back to Noto Sans Ethiopic (`fontFamilyFallback`), never the platform font
- [ ] **Given** an Ethiopic-script string, **When** it is shown with a token style, **Then** an Ethiopic variant of that style adds 15-20% line height, and a Fidel prompt in a tile shows no clipped vowel marks at 1.0× and 1.3× text *(Ethiopic variant and line height done and tested; the 1.3× on-device check is in bolt 049's sweep)*
- [x] **Given** no network, **When** the app starts, **Then** every font renders (no run-time download)
- [ ] **Given** a release APK before and after, **When** compared, **Then** the size grows by at most 2 MB (NFR-3) *(the font files total 1.68 MB before compression; the APK comparison is in bolt 049's sweep)*

## Reference Design (FR-11)

- DESIGN.md: Typography (Plus Jakarta Sans; Ge'ez line-height allowance; phonetics in `body-sm` 500 `#786A5E`)
- Every Stitch mockup's text, to check weights

## Technical Notes

- Fonts come from the official Google Fonts / Noto repositories (SIL OFL 1.1).
- Prefer static weight files for the four weights. A variable font is acceptable if it is smaller and Flutter renders its weights correctly on both platforms.
- A small helper (e.g. `AppTypography.forText(style, text)`) picks the Ethiopic variant when the text contains Ethiopic code points (U+1200-U+139F, U+2D80-U+2DDF, U+AB00-U+AB2F).

## Dependencies

### Requires
- Nothing

### Enables
- 004-gallery-and-rules-test (shows Latin and Fidel samples)

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Mixed Latin and Fidel in one string | Latin in Plus Jakarta Sans, Fidel in Noto Sans Ethiopic, with Ethiopic line height |
| Afaan Oromo (Latin script) | Plain Plus Jakarta Sans, no extra line height |

## Out of Scope

- Localising the interface
- Changing the type scale sizes
