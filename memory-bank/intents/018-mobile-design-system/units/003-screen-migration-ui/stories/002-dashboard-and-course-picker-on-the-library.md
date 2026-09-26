---
id: 002-dashboard-and-course-picker-on-the-library
unit: 003-screen-migration-ui
intent: 018-mobile-design-system
status: complete
priority: must
created: '2026-09-24T12:55:00Z'
assigned_bolt: 047-dashboard-on-kit
implemented: true
---

# Story: 002-dashboard-and-course-picker-on-the-library

## User Story

**As a** Buna learner
**I want** the home screen to look like the mockup, with the same cards, pills and sheets as the rest of the app
**So that** the screen I open every day is the most polished one

## Acceptance Criteria

- [x] **Given** the dashboard, **When** shown, **Then** it uses `AppPage` with the patterned background, `StatPill`s in the header, `AppCard` for the practice entry, and the shared banner and node styles, matching the dashboard mockup
- [x] **Given** `SkillPathNode` and `CategoryBanner`, **When** shown, **Then** their colours and shelves come from tokens, with no local `Color(0x…)` or `BoxShadow`
- [x] **Given** the course picker, **When** opened, **Then** it is a `showAppSheet` with `AppCard` rows
- [x] **Given** the sync banner and offline note, **When** shown, **Then** they use `InfoBanner`
- [x] **Given** the home placeholder, **When** shown, **Then** it uses `AppPage` and `EmptyState`
- [ ] **Given** the dashboard, picker, HUD and offline tests, **When** run, **Then** all pass (updated only for replaced types), the sticky banners and pinned header behave as before (both verified by tests), and there is no dropped frame while scrolling in profile mode (still to check by hand on a device)

## Reference Design (FR-11)

- `stich-screens/extracted/stitch_ethiopian_language_learning_app/4._home_skill_tree_dashboard`
- Course picker: fetched references in Plan (no mockup)

## Technical Notes

- Intent 011's scroll behaviour (pinned header, sticky banners) is kept exactly.

## Dependencies

### Requires
- 001-design-foundation-ui

### Enables
- 005-consistency-sweep

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Offline from cache | The offline `InfoBanner` shows; everything else as today |

## Out of Scope

- Bottom navigation tabs
- New dashboard content
