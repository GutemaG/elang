---
id: 042-design-foundation
unit: 001-design-foundation-ui
intent: 018-mobile-design-system
type: simple-construction-bolt
status: complete
stories:
  - 001-design-tokens-shadows-and-motion
  - 002-bundled-fonts-with-ethiopic-fallback
  - 003-buttons
  - 004-gallery-and-rules-test
created: '2026-09-24T12:55:00Z'
started: '2026-09-24T12:59:00Z'
completed: '2026-09-24T14:08:11Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-09-24T13:10:00Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-09-24T13:32:00Z'
    artifact: implementation-walkthrough.md
  - name: test
    completed: '2026-09-24T14:08:11Z'
    artifact: test-walkthrough.md
requires_bolts: []
enables_bolts:
  - 043-design-surfaces
requires_units: []
blocks: false
complexity:
  avg_complexity: 2
  avg_uncertainty: 2
  max_dependencies: 1
  testing_scope: 2
---

# Bolt: 042-design-foundation

## Objective

Lay the foundation: every token, the bundled fonts, `AppButton`/`AppIconButton`, the debug gallery and the rules test with its allow-list. No screen looks different yet.

## Stories Included

- [x] **001-design-tokens-shadows-and-motion** (Must)
- [x] **002-bundled-fonts-with-ethiopic-fallback** (Must)
- [x] **003-buttons** (Must)
- [x] **004-gallery-and-rules-test** (Must)

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [x] **1. Plan**: includes choosing and recording each story's reference design (FR-11): the Stitch mockup, or fetched external designs
- [x] **2. Implement**
- [x] **3. Test**

## Expected Outputs

- New tokens in `lib/shared/theme/` (`app_shadows.dart`, `app_motion.dart`, colour and radius additions)
- `assets/fonts/` with licences; `pubspec.yaml` fonts
- `AppButton`, `AppIconButton`; `TactileButton` delegating
- Debug gallery screen and entry point
- `test/design_rules_test.dart` with the allow-list, gallery test, component tests

## Dependencies

### Requires
- None

### Enables
- `043-design-surfaces`

## Success Criteria

- Every story's acceptance criteria met
- Gallery shows every new component and state
- Rules test passes; its allow-list is no longer than before
- `flutter analyze` clean; full Flutter test suite passes
