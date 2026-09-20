---
id: 028-dashboard-shell
unit: 001-dashboard-shell-ui
intent: 011-dashboard-ui-polish
type: simple-construction-bolt
status: complete
stories:
  - 001-pinned-header-with-stats
  - 002-smooth-scroll-and-sticky-sections
created: '2026-09-21T03:00:00Z'
started: '2026-09-21T03:05:00Z'
completed: '2026-09-20T10:22:15Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-09-21T03:30:00Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-09-21T04:10:00Z'
    artifact: implementation-walkthrough.md
requires_bolts: []
enables_bolts:
  - 029-course-switcher-panel
requires_units: []
blocks: false
complexity:
  avg_complexity: 3
  avg_uncertainty: 2
  max_dependencies: 0
  testing_scope: 4
---

# Bolt: 028-dashboard-shell

## Overview

Rebuild the dashboard as one scroll surface: move the stats into a pinned header, turn the
sync banner and offline note into slivers, and pin each category's banner beneath the
header while its nodes scroll past.

## Objective

The skill path is the dominant element of the dashboard, the learner's stats never scroll
away, and the current section is always named at the top of the content.

## Stories Included

- **001-pinned-header-with-stats** (Must)
- **002-smooth-scroll-and-sticky-sections** (Must)

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [ ] **1. Plan**
- [ ] **2. Implement**
- [ ] **3. Test**

## Dependencies

### Requires
- None (intent 010 is complete)

### Enables
- `029-course-switcher-panel`

## Success Criteria

- [ ] One `CustomScrollView` owns the dashboard; the stats sit in a pinned header
- [ ] Each category's banner pins beneath the header and is replaced by the next
- [ ] The page is always draggable and returns to the top with an animation on a course change
- [ ] No overflow at 320dp and 360dp at 1.3x text
- [ ] Existing dashboard tests updated to the new structure, not deleted; suite green

## Notes

Leave `_CourseChip` and the Downloads/Settings icon buttons in place inside the new
header. Bolt 029 replaces them, so this bolt's diff stays about layout only.
