---
id: 008-status-and-feedback-pieces
unit: 001-design-foundation-ui
intent: 018-mobile-design-system
status: complete
priority: must
created: '2026-09-24T12:55:00Z'
assigned_bolt: 043-design-surfaces
implemented: true
---

# Story: 008-status-and-feedback-pieces

## User Story

**As a** Buna learner
**I want** my streak, beans, gems, progress and any empty or error message to look the same wherever they appear
**So that** I read my progress at a glance and a problem never looks like a crash

## Acceptance Criteria

- [x] **Given** `StatPill` for streak, beans, gems or XP, **When** built, **Then** it is a translucent white pill with a tinted border, coloured icon and `label-md` number, as in the dashboard HUD, with its semantics label
- [x] **Given** `CountBadge` and `RibbonBadge`, **When** built, **Then** they match "3/5 Completed" and "+1 TODAY" in the mockups
- [x] **Given** `AppProgressBar`, **When** built, **Then** it has a sunken track, a rounded fill, an optional gradient and optional label, and animates value changes within `AppMotion.state`
- [x] **Given** `EmptyState`, `ErrorState` and `LoadingState`, **When** built, **Then** each has an `IconBadge` illustration, title, text and optional action, and `LoadingState` stops animating under `pumpAndSettle` where today's screens rely on that
- [x] **Given** `InfoBanner`, **When** used for sync status, **Then** it can show the three states `SyncStatusBanner` has today

## Reference Design (FR-11)

- `stich-screens/extracted/stitch_ethiopian_language_learning_app/4._home_skill_tree_dashboard` (HUD pills, milestone progress)
- `stich-screens/extracted/stitch_ethiopian_language_learning_app/out_of_beans_refill_modal` (refill timer bar, beans badge)
- `stich-screens/extracted/stitch_ethiopian_language_learning_app/lesson_complete_summary_1` (accuracy bar, ribbon)
- Empty/error states: fetched references in Plan

## Technical Notes

- `LoadingState` must not keep an endless animation where a test calls `pumpAndSettle` (see the comment in `lesson_screen.dart` `_ExerciseBody`).

## Dependencies

### Requires
- 001-design-tokens-shadows-and-motion
- 006-cards-and-surfaces

### Enables
- Dashboard, lesson header, lesson complete, out-of-beans, downloads

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Large numbers (e.g. 12,340 XP) | Formatted and never overflow the pill at 1.3× text |

## Out of Scope

- New stats or new meanings for existing ones
