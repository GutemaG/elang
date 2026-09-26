---
id: 003-lesson-complete-and-lesson-sheets-on-the-library
unit: 003-screen-migration-ui
intent: 018-mobile-design-system
status: complete
priority: must
created: '2026-09-24T12:55:00Z'
assigned_bolt: 048-lesson-complete-and-sheets-on-kit
implemented: true
---

# Story: 003-lesson-complete-and-lesson-sheets-on-the-library

## User Story

**As a** Buna learner
**I want** the end of a lesson and every lesson pop-up to look celebratory and consistent
**So that** finishing a lesson feels rewarding and every sheet looks like the same family

## Acceptance Criteria

- [x] **Given** the lesson-complete screen, **When** shown, **Then** it uses `AppPage` with the celebration background, `StatCard`s, the accuracy `AppCard` with `AppProgressBar`, an `InfoBanner` and a docked Continue, matching its mockups
- [x] **Given** the exit-lesson, level-up, review-skill and out-of-beans sheets, **When** opened, **Then** each uses `showAppSheet` + `SheetHero`, matching the level-up and out-of-beans mockups; exit and review follow the same pattern (level-up uses `showAppDialog` + `SheetHero`, as its mockup is a dialog: Plan checkpoint choice 2)
- [x] **Given** "Not now", "Keep learning" versus "Leave" and similar pairs, **When** shown, **Then** the main action is primary, a real alternative is secondary and a dismissal is a text link
- [x] **Given** the lesson-complete and sheet tests, **When** run, **Then** all pass, changed only for replaced types, and each sheet returns the same result as before

## Reference Design (FR-11)

- `stich-screens/extracted/stitch_ethiopian_language_learning_app/lesson_complete_summary_1`, `lesson_complete_summary_2`, `level_up_streak_freeze_modal`, `out_of_beans_refill_modal`
- Exit and review sheets: follow the out-of-beans pattern, plus a fetched reference in Plan

## Technical Notes

- The existing icons stand in for mascot art in `SheetHero`'s illustration slot.

## Dependencies

### Requires
- 001-design-foundation-ui

### Enables
- 005-consistency-sweep

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Completion save failed | The error and retry show as today, in the shared style |

## Out of Scope

- New stats (gems, time) that the app does not have today
