---
id: 005-page-shell-and-backgrounds
unit: 001-design-foundation-ui
intent: 018-mobile-design-system
status: draft
priority: must
created: '2026-09-24T12:55:00Z'
assigned_bolt: 043-design-surfaces
implemented: false
---

# Story: 005-page-shell-and-backgrounds

## User Story

**As a** Buna learner
**I want** every screen to sit on the same warm background with the same margins, top bar and bottom action area
**So that** moving from page to page feels like one app

## Acceptance Criteria

- [ ] **Given** `AppPage`, **When** a screen uses it, **Then** it gets the cream background, safe area, 20 px side margins and scrolling content without setting any of them itself
- [ ] **Given** `background: patterned`, **When** shown, **Then** the faint diagonal lattice from the dashboard mockup is painted once and repaints only on resize (NFR-3)
- [ ] **Given** `background: celebration`, **When** shown, **Then** a soft radial glow sits behind the hero area, as in the lesson-complete mockup
- [ ] **Given** a `topBar` (leading close/back, centred title or logo, trailing actions or stat pills), **When** set, **Then** it lines up with the page margins on every screen
- [ ] **Given** a `bottomDock`, **When** set, **Then** its buttons are pinned above the safe area with the same padding on every screen, and content scrolls behind it without being hidden
- [ ] **Given** `footerStripe: true`, **When** shown, **Then** the Tibeb stripe (green, gold, terracotta diagonal band) sits at the bottom, as in the out-of-beans mockup

## Reference Design (FR-11)

- `stich-screens/extracted/stitch_ethiopian_language_learning_app/4._home_skill_tree_dashboard` (lattice)
- `stich-screens/extracted/stitch_ethiopian_language_learning_app/lesson_complete_summary_1` (glow, Skip/back top bar, docked Continue)
- `stich-screens/extracted/stitch_ethiopian_language_learning_app/out_of_beans_refill_modal` (stripe footer, top bar with pills and close)

## Technical Notes

- The lattice is a `CustomPainter` inside a `RepaintBoundary`; `repeating-linear-gradient(45deg/135deg, #231a11 1px …)` at very low opacity in the mockup.

## Dependencies

### Requires
- 001-design-tokens-shadows-and-motion
- 003-buttons

### Enables
- Every screen story

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Keyboard open (sign-in) | Dock stays above the keyboard or scrolls with content; nothing is covered |
| Very short screen (360×640) | Content scrolls; the dock stays visible |

## Out of Scope

- Bottom navigation tabs from the dashboard mockup
