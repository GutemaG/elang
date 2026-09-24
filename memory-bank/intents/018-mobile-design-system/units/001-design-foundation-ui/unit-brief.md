---
unit: 001-design-foundation-ui
intent: 018-mobile-design-system
unit_type: frontend
default_bolt_type: simple-construction-bolt
phase: inception
status: complete
created: '2026-09-24T12:55:00Z'
updated: '2026-09-24T12:55:00Z'
---

# Unit Brief: Design Foundation UI

## Purpose

The shared design library every screen is built from: tokens (colour, shadow, radius, motion), bundled fonts, buttons, the page shell and backgrounds, cards, sheets and dialogs, status pieces, a debug gallery and the rules test that keeps screens on the library.

## Scope

### In Scope
- `lib/shared/theme/` additions: colours, `AppShadows`, `AppMotion`, radii, typography with fonts
- `assets/fonts/` and the `pubspec.yaml` fonts section
- `lib/shared/widgets/`: `AppButton`, `AppIconButton`, `AppPage`, `AppCard`, `StatCard`, `InfoBanner`, `ListRow`, `SectionHeader`, `showAppSheet`, `showAppDialog`, `SheetHero`, `StatPill`, `CountBadge`, `RibbonBadge`, `AppProgressBar`, `IconBadge`, `EmptyState`, `ErrorState`, `LoadingState`
- `TactileButton` and `SelectableOptionCard` rebuilt on the new components
- The debug gallery and the rules test (with its allow-list)

### Out of Scope
- Changing how any real screen looks (units 002 and 003)
- The question-type kit (unit 002)
- Dark mode, tablet, new artwork

---

## Assigned Requirements

| FR | Requirement | Priority |
|----|-------------|----------|
| FR-1 | Complete design tokens | Must |
| FR-2 | Buttons | Must |
| FR-3 | Page shell and backgrounds | Must |
| FR-4 | Cards and surfaces | Must |
| FR-5 | Sheets and dialogs | Must |
| FR-6 | Status and feedback pieces | Must |
| FR-9 | Bundled fonts | Must |
| FR-10 | Component gallery | Must |
| FR-11 | Every design follows a reference (process owner) | Must |

NFR-1 to NFR-5 apply to every story.

---

## Story Summary

| Metric | Count |
|--------|-------|
| Total Stories | 8 |
| Must Have | 8 |
| Should Have | 0 |
| Could Have | 0 |

### Stories

| Story ID | Title | Priority | Status |
|----------|-------|----------|--------|
| 001-design-tokens-shadows-and-motion | Colour, shadow, radius and motion tokens | Must | Planned |
| 002-bundled-fonts-with-ethiopic-fallback | Bundled Plus Jakarta Sans with Noto Sans Ethiopic fallback | Must | Planned |
| 003-buttons | AppButton variants and AppIconButton | Must | Planned |
| 004-gallery-and-rules-test | Debug component gallery and design rules test | Must | Planned |
| 005-page-shell-and-backgrounds | AppPage shell with plain, patterned and celebration backgrounds | Must | Planned |
| 006-cards-and-surfaces | AppCard and its family: StatCard, InfoBanner, ListRow, SectionHeader | Must | Planned |
| 007-sheets-and-dialogs | showAppSheet, showAppDialog and SheetHero | Must | Planned |
| 008-status-and-feedback-pieces | StatPill, badges, AppProgressBar, IconBadge and empty/error/loading states | Must | Planned |

---

## Dependencies

### Depends On
None

### Depended By
`002-question-kit-ui`, `003-screen-migration-ui`

### External Dependencies
| System | Purpose | Risk |
|--------|---------|------|
| Plus Jakarta Sans, Noto Sans Ethiopic (SIL OFL) | Bundled fonts | Low |
| External reference designs | Studied in Plan only (FR-11) | Low: patterns only, nothing copied |

---

## Constraints

- Every story's Plan stage names its reference design (Stitch mockup, or a fetched external design) and what is taken from it, before code.
- Highland Pulse tokens only; a new value becomes a token first.
- No behaviour change; existing tests change only where a replaced widget type was found.
- The rules test allow-list only ever shrinks.
- No overflow at 360×640 and 430×932 with 1.3× text; tap targets at least 48dp; semantics kept.

## Bolt Suggestions

| Bolt | Type | Stories | Objective |
|------|------|---------|-----------|
| 042-design-foundation | simple-construction-bolt | 001, 002, 003, 004 | Tokens, fonts, buttons, gallery and rules test |
| 043-design-surfaces | simple-construction-bolt | 005, 006, 007, 008 | Page shell and backgrounds, cards, sheets and dialogs, status pieces |
