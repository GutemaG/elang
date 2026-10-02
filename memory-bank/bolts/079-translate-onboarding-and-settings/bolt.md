---
id: 079-translate-onboarding-and-settings
unit: 003-screen-translations
intent: 024-app-localization
type: simple-construction-bolt
status: complete
stories: []
created: '2026-10-02T19:12:33Z'
started: '2026-10-02T19:52:00Z'
completed: '2026-10-02T20:36:05Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-10-02T19:52:00Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-10-02T20:32:16Z'
    artifact: implementation-plan.md
  - name: test
    completed: '2026-10-02T20:32:16Z'
    artifact: implementation-plan.md
requires_bolts:
  - 078-localization-foundation
enables_bolts: []
requires_units: []
blocks: false
complexity:
  avg_complexity: 2
  avg_uncertainty: 2
  max_dependencies: 1
  testing_scope: 2
---

# Bolt: 079-translate-onboarding-and-settings

## Objective

Every screen's words, the daily reminder and dates in English, Amharic and Afaan Oromo, the sweep in every language, and the reviewer's guide. Replanned at the user's request to take all of unit 003 (stories 008-016); bolts 080 and 081 are folded in.

## Stories Included

Written in the unit brief (`intents/024-app-localization/units/003-screen-translations/unit-brief.md`), not
as separate files, so `stories:` above is empty.

- [x] **008-onboarding-and-sign-in**
- [x] **009-settings-and-feedback**
- [x] **010-daily-reminder**
- [x] **011-dashboard-path-and-courses**
- [x] **012-league-and-stat-sheets**
- [x] **013-dates-in-the-app-language**
- [x] **014-lessons-exercises-and-practice**
- [x] **015-every-screen-in-every-language**
- [x] **016-reviewer-guide**

## Expected Outputs

- ARB keys and am/om drafts for these screens
- Reminder text from the app language; reschedule on change
- Allow-list shortened; tests

## Dependencies

### Requires
- `078-localization-foundation`

### Enables
None (080 and 081 folded in).
