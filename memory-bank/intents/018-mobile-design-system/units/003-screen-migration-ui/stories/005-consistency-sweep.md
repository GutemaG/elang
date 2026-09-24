---
id: 005-consistency-sweep
unit: 003-screen-migration-ui
intent: 018-mobile-design-system
status: draft
priority: must
created: '2026-09-24T12:55:00Z'
assigned_bolt: 049-settings-downloads-and-sweep
implemented: false
---

# Story: 005-consistency-sweep

## User Story

**As a** Buna learner
**I want** every screen checked together against the same rules
**So that** nothing in the app still looks different from page to page

## Acceptance Criteria

- [ ] **Given** the rules test, **When** run, **Then** its allow-list is empty and it passes (NFR-1)
- [ ] **Given** every screen, **When** rendered in tests at 360×640 and 430×932 at 1.0× and 1.3× text, **Then** nothing overflows (NFR-2, NFR-4)
- [ ] **Given** reduced motion, **When** buttons are pressed and wrong answers given, **Then** no press movement or shake happens (NFR-2)
- [ ] **Given** a real Android phone and an iPhone (or the iOS simulator), **When** the main flows are walked (onboarding, sign-in, dashboard, a lesson with each question type, lesson complete, settings, downloads), **Then** the fonts are the bundled ones and each screen matches its reference; findings are recorded in the test walkthrough
- [ ] **Given** `flutter analyze` and the full test suite, **When** run, **Then** 0 issues and 100% pass (NFR-5)
- [ ] **Given** `TactileButton`, **When** the sweep ends, **Then** it is either deleted or a documented thin alias, with no unused shared widget left behind

## Reference Design (FR-11)

- All references recorded in the earlier stories

## Technical Notes

- The on-device check is manual and recorded, like bolt 039's phone check.

## Dependencies

### Requires
- All other stories in this intent

### Enables
- Bolt 033 (spell tiles) and any future screen

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| A violation found late | Fixed by moving code into the library, never by re-adding to the allow-list |

## Out of Scope

- Dark mode, tablet, landscape
