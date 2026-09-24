---
id: 003-buttons
unit: 001-design-foundation-ui
intent: 018-mobile-design-system
status: complete
priority: must
created: '2026-09-24T12:55:00Z'
assigned_bolt: 042-design-foundation
implemented: true
---

# Story: 003-buttons

## User Story

**As a** Buna learner
**I want** every button in the app to look and press the same way for the same kind of action
**So that** I always know which action is the main one and every tap feels solid

## Acceptance Criteria

- [x] **Given** `AppButton`, **When** built as primary, secondary, accent, destructive or text, **Then** it matches DESIGN.md Component 1 and the mockups: pill shape, 4 px shelf in the variant's bevel colour, secondary as a white face with a coloured border and shelf, text as a flat link
- [x] **Given** any tactile variant, **When** pressed, **Then** it moves down by the shelf depth and the shelf flattens within `AppMotion.press`; with reduced motion it only changes shade
- [x] **Given** a leading icon, trailing icon or trailing badge (e.g. "350 Amole"), **When** set, **Then** they sit inside the pill with the mockup's spacing
- [x] **Given** `onPressed == null` or `loading: true`, **When** tapped, **Then** nothing happens; loading shows a spinner in place of the label without the button changing size
- [x] **Given** any `AppButton` or `AppIconButton`, **When** measured, **Then** its tap target is at least 48×48 and it exposes a button semantic with its label or tooltip
- [x] **Given** `AppIconButton`, **When** used for close or back, **Then** it is round on a soft surface, as in the out-of-beans mockup
- [x] **Given** the existing `TactileButton`, **When** this story is done, **Then** it delegates to `AppButton.primary` (or is replaced with its tests updated), so screens keep working unchanged

## Reference Design (FR-11)

- `stich-screens/extracted/stitch_ethiopian_language_learning_app/lesson_complete_summary_1/screen.png` (Continue, Review Mistakes)
- `stich-screens/extracted/stitch_ethiopian_language_learning_app/out_of_beans_refill_modal/screen.png` (accent with badge, secondary with icon, 'Not now' text link, round close)
- DESIGN.md Component 1

## Technical Notes

- Variants are named constructors (`AppButton.primary(...)`) or an enum; choose in Plan.
- Full width is the default inside an action dock; `expand: false` hugs content.

## Dependencies

### Requires
- 001-design-tokens-shadows-and-motion

### Enables
- Every screen story

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Very long label at 1.3× text | Wraps to two lines or scales down; never overflows |
| Button inside a scroll view | Press effect still works; a drag cancels the press |

## Out of Scope

- Swapping buttons on real screens (units 002 and 003)
