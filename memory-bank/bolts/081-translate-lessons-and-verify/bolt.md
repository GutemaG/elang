---
id: 081-translate-lessons-and-verify
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
  - 080-translate-home-and-league
enables_bolts: []
requires_units: []
blocks: false
complexity:
  avg_complexity: 3
  avg_uncertainty: 2
  max_dependencies: 1
  testing_scope: 3
---

# Bolt: 081-translate-lessons-and-verify

> **Folded into bolt 079** (2026-10-02): the user asked for every screen to be translated at once, so 079 took all of unit 003. Nothing was built under this bolt; see `079-translate-onboarding-and-settings/implementation-plan.md`.

## Objective

Lessons, exercises and practice in all three languages, the screen sweep in every language, the allow-list emptied, and the reviewer's guide.

## Stories Included

Written in the unit brief (`intents/024-app-localization/units/003-screen-translations/unit-brief.md`), not
as separate files, so `stories:` above is empty.

- [ ] **014-lessons-exercises-and-practice**
- [ ] **015-every-screen-in-every-language**
- [ ] **016-reviewer-guide**

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [ ] **1. Plan**
- [ ] **2. Implement**
- [ ] **3. Test**

## Expected Outputs

- ARB keys and am/om drafts for lessons, exercises and practice
- Screen sweep in en/am/om; empty allow-list
- `translation-guide.md`

## Dependencies

### Requires
- `080-translate-home-and-league`

### Enables
None.
