---
id: 043-design-surfaces
unit: 001-design-foundation-ui
intent: 018-mobile-design-system
type: simple-construction-bolt
status: complete
stories:
  - 005-page-shell-and-backgrounds
  - 006-cards-and-surfaces
  - 007-sheets-and-dialogs
  - 008-status-and-feedback-pieces
created: '2026-09-24T12:55:00Z'
started: '2026-09-24T14:14:32Z'
completed: '2026-09-24T18:18:19Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-09-24T14:20:49Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-09-24T15:57:24Z'
    artifact: implementation-walkthrough.md
  - name: test
    completed: '2026-09-24T18:18:18Z'
    artifact: test-walkthrough.md
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

- [x] **005-page-shell-and-backgrounds** (Must)
- [x] **006-cards-and-surfaces** (Must)
- [x] **007-sheets-and-dialogs** (Must)
- [x] **008-status-and-feedback-pieces** (Must)

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [x] **1. Plan**: includes choosing and recording each story's reference design (FR-11): the Stitch mockup, or fetched external designs
- [x] **2. Implement**
- [x] **3. Test**

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
