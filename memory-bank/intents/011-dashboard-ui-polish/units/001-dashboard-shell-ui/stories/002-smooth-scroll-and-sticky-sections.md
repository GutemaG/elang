---
id: 002-smooth-scroll-and-sticky-sections
unit: 001-dashboard-shell-ui
intent: 011-dashboard-ui-polish
status: complete
priority: must
created: '2026-09-21T02:40:00Z'
assigned_bolt: 028-dashboard-shell
implemented: true
---

# Story: 002-smooth-scroll-and-sticky-sections

## User Story

**As a** Buna learner
**I want** the whole page to scroll as one smooth surface, with the current section's
banner staying beneath the header
**So that** moving through a long course feels fluid and I never lose track of which
section I am in

## Acceptance Criteria

- [ ] **Given** the dashboard, **When** it builds, **Then** one scroll view owns the page and there is no nested vertical scrollable on it
- [ ] **Given** a course with less content than the viewport, **When** the learner drags, **Then** the page still responds and settles back rather than refusing to move
- [ ] **Given** the learner scrolls inside a category, **When** its nodes pass by, **Then** that category's banner stays pinned directly under the header
- [ ] **Given** the learner reaches the next category, **When** its banner arrives, **Then** it pushes the previous one away and takes its place
- [ ] **Given** a course with exactly one category, **When** scrolled, **Then** that banner stays pinned for the whole page
- [ ] **Given** the course changes, **When** the new tree renders, **Then** the scroll position returns to the top with an animation, not an instant jump
- [ ] **Given** the sync banner or offline note appears or disappears, **When** it does, **Then** the header does not move
- [ ] **Given** 320dp at 1.3x text with the longest seeded category title, **When** the banner is pinned, **Then** nothing overflows
- [ ] **Given** the learner scrolls, **When** frames are produced, **Then** the header's stat pills are not rebuilt per frame

## Technical Notes

- Today `SyncStatusBanner` and `_OfflineNote` sit in a fixed `Column` above the scroll
  view; they become slivers so the header is the only pinned chrome.
- The sticky-banner mechanism (`SliverPersistentHeader` per category versus one banner
  driven by scroll position) is a Technical Design decision for this bolt.
- Physics choice must keep the page always draggable (`AlwaysScrollableScrollPhysics`)
  regardless of content height, so pull-to-settle works on a short course.
- The existing `skill_tree_dashboard_categories_test` asserts banner content and
  ordering; update it against the pinned structure rather than weakening its assertions.

## Dependencies

### Requires
- `001-pinned-header-with-stats` (the header the banners pin beneath)

### Enables
- Nothing; this completes the shell

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Course with zero categories | No banner; the page still scrolls and shows the Practice card |
| Category with zero nodes | Its banner still renders with 0/0 and an empty progress bar |
| Very tall category (many nodes) | Banner stays pinned for the whole category |
| Course switch while scrolled deep | Animated return to top before the new tree is read |

## Out of Scope

- Changing the serpentine node layout or node spacing
- Pull-to-refresh (a separate feature, not requested)
- Section collapse/expand
