---
id: 006-cards-and-surfaces
unit: 001-design-foundation-ui
intent: 018-mobile-design-system
status: complete
priority: must
created: '2026-09-24T12:55:00Z'
assigned_bolt: 043-design-surfaces
implemented: true
---

# Story: 006-cards-and-surfaces

## User Story

**As a** Buna learner
**I want** every card, row and banner to have the same border, corner and shadow
**So that** the app feels crafted and calm instead of pieced together

## Acceptance Criteria

- [x] **Given** `AppCard`, **When** built, **Then** it is a white face, 2 px border, 24 px radius and `AppShadows.card` (Tactile Level 1)
- [x] **Given** a `tone` (neutral, primary, secondary, tertiary), **When** set, **Then** border and shelf take that tone's tint, as in the lesson-complete stat cards
- [x] **Given** `topStripe: true`, **When** set, **Then** a Tibeb stripe runs along the top edge, as on the milestone and refill-timer cards
- [x] **Given** `onTap`, **When** tapped, **Then** the card presses like a button and exposes a button semantic
- [x] **Given** `StatCard`, `InfoBanner`, `ListRow` and `SectionHeader`, **When** built, **Then** each matches its mockup (stat cards and the daily-goal banner in lesson complete; list rows follow the FR-11 reference) and appears in the gallery
- [x] **Given** `SelectableOptionCard`, **When** this story is done, **Then** it is built on `AppCard` with its three states unchanged

## Reference Design (FR-11)

- `stich-screens/extracted/stitch_ethiopian_language_learning_app/lesson_complete_summary_1` (stat cards, accuracy card, daily-goal banner)
- `stich-screens/extracted/stitch_ethiopian_language_learning_app/4._home_skill_tree_dashboard` (milestone card with stripe)
- ListRow: fetched references for settings rows (e.g. Duolingo settings, Material 3 lists) in Plan

## Technical Notes

- `StatCard`'s ribbon ("+1 TODAY") uses `RibbonBadge` from story 008; build 006 and 008 together or stub the ribbon.

## Dependencies

### Requires
- 001-design-tokens-shadows-and-motion

### Enables
- Every screen story

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Card inside a tinted parent | Keeps its white face; tone only tints border and shelf |

## Out of Scope

- Moving real screens onto the cards (unit 003)
