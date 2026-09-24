---
unit: 003-screen-migration-ui
intent: 018-mobile-design-system
unit_type: frontend
default_bolt_type: simple-construction-bolt
phase: inception
status: stories-defined
created: '2026-09-24T12:55:00Z'
updated: '2026-09-24T12:55:00Z'
---

# Unit Brief: Screen Migration UI

## Purpose

Every screen outside the lesson moved onto the library, then an app-wide consistency sweep that empties the rules test's allow-list and checks layout, text scale, reduced motion and fonts on real devices.

## Scope

### In Scope
- Splash, onboarding, language, daily goal, sign-in
- Dashboard (header, banners, path nodes, practice card, sync banner), course picker, home placeholder
- Lesson complete and the exit, level-up, review-skill and out-of-beans sheets
- Settings (screen, sheet, dialogs) and download management
- The consistency sweep

### Out of Scope
- The lesson screen (unit 002)
- New features or copy
- Dark mode, tablet

---

## Assigned Requirements

| FR | Requirement | Priority |
|----|-------------|----------|
| FR-8 | Every screen moves onto the shared components: every screen except the lesson screen | Must |

NFR-1 to NFR-5 apply to every story.

---

## Story Summary

| Metric | Count |
|--------|-------|
| Total Stories | 5 |
| Must Have | 5 |
| Should Have | 0 |
| Could Have | 0 |

### Stories

| Story ID | Title | Priority | Status |
|----------|-------|----------|--------|
| 001-onboarding-and-sign-in-on-the-library | Splash, onboarding, language, daily goal and sign-in on the library | Must | Planned |
| 002-dashboard-and-course-picker-on-the-library | Dashboard, header, banners, path nodes and course picker on the library | Must | Planned |
| 003-lesson-complete-and-lesson-sheets-on-the-library | Lesson complete and the lesson sheets on the library | Must | Planned |
| 004-settings-and-downloads-on-the-library | Settings and download management on the library | Must | Planned |
| 005-consistency-sweep | App-wide consistency sweep | Must | Planned |

---

## Dependencies

### Depends On
`001-design-foundation-ui`; story 005 also `002-question-kit-ui`

### Depended By
None

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
| 046-onboarding-screens-on-kit | simple-construction-bolt | 001 | First-run screens |
| 047-dashboard-on-kit | simple-construction-bolt | 002 | Dashboard and course picker |
| 048-lesson-complete-and-sheets-on-kit | simple-construction-bolt | 003 | Lesson complete and lesson sheets |
| 049-settings-downloads-and-sweep | simple-construction-bolt | 004, 005 | Settings, downloads, and the app-wide sweep |
