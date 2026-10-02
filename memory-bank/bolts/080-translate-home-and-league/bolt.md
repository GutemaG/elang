---
id: 080-translate-home-and-league
unit: 003-screen-translations
intent: 024-app-localization
type: simple-construction-bolt
status: cancelled
stories: []
created: '2026-10-02T19:12:33Z'
started: null
completed: null
current_stage: null
stages_completed: []
requires_bolts:
  - 079-translate-onboarding-and-settings
enables_bolts:
  - 081-translate-lessons-and-verify
requires_units: []
blocks: false
complexity:
  avg_complexity: 2
  avg_uncertainty: 2
  max_dependencies: 1
  testing_scope: 2
---

# Bolt: 080-translate-home-and-league

> **Folded into bolt 079** (2026-10-02): the user asked for every screen to be translated at once, so 079 took all of unit 003. Nothing was built under this bolt; see `079-translate-onboarding-and-settings/implementation-plan.md`.

## Objective

The dashboard, path, courses, league and stat sheets in all three languages, with month and weekday names from the app language.

## Stories Included

Written in the unit brief (`intents/024-app-localization/units/003-screen-translations/unit-brief.md`), not
as separate files, so `stories:` above is empty.

- [ ] **011-dashboard-path-and-courses**
- [ ] **012-league-and-stat-sheets**
- [ ] **013-dates-in-the-app-language**

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [ ] **1. Plan**
- [ ] **2. Implement**
- [ ] **3. Test**

## Expected Outputs

- ARB keys and am/om drafts for these screens and shared widgets
- Dates through `intl`; durations as plurals
- Allow-list shortened; tests

## Dependencies

### Requires
- `079-translate-onboarding-and-settings`

### Enables
- `081-translate-lessons-and-verify`
