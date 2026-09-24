---
id: 043-design-surfaces
unit: 001-design-foundation-ui
intent: 018-mobile-design-system
type: simple-construction-bolt
status: planned
stories:
  - 005-page-shell-and-backgrounds
  - 006-cards-and-surfaces
  - 007-sheets-and-dialogs
  - 008-status-and-feedback-pieces
created: '2026-09-24T12:55:00Z'
started: null
completed: null
current_stage: null
stages_completed: []
requires_bolts:
  - 042-design-foundation
enables_bolts:
  - 044-question-kit
  - 046-onboarding-screens-on-kit
  - 047-dashboard-on-kit
  - 048-lesson-complete-and-sheets-on-kit
requires_units: []
blocks: false
complexity:
  avg_complexity: 2
  avg_uncertainty: 2
  max_dependencies: 1
  testing_scope: 2
---

# Bolt: 043-design-surfaces

## Objective

Complete the library: `AppPage` and its three backgrounds, `AppCard` and its family, sheets and dialogs, and the status pieces, all in the gallery.

## Stories Included

- [ ] **005-page-shell-and-backgrounds** (Must)
- [ ] **006-cards-and-surfaces** (Must)
- [ ] **007-sheets-and-dialogs** (Must)
- [ ] **008-status-and-feedback-pieces** (Must)

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [ ] **1. Plan**: includes choosing and recording each story's reference design (FR-11): the Stitch mockup, or fetched external designs
- [ ] **2. Implement**
- [ ] **3. Test**

## Expected Outputs

- `AppPage` (plain, patterned, celebration; top bar; dock; stripe)
- `AppCard`, `StatCard`, `InfoBanner`, `ListRow`, `SectionHeader`; `SelectableOptionCard` on `AppCard`
- `showAppSheet`, `showAppDialog`, `SheetHero`
- `StatPill`, `CountBadge`, `RibbonBadge`, `AppProgressBar`, `IconBadge`, `EmptyState`, `ErrorState`, `LoadingState`
- Gallery sections and tests for each

## Dependencies

### Requires
- `042-design-foundation`

### Enables
- `044-question-kit`
- `046-onboarding-screens-on-kit`
- `047-dashboard-on-kit`
- `048-lesson-complete-and-sheets-on-kit`

## Success Criteria

- Every story's acceptance criteria met
- Gallery shows every new component and state
- Rules test passes; its allow-list is no longer than before
- `flutter analyze` clean; full Flutter test suite passes
