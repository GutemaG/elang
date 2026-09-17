---
id: 020-practice-ui
unit: 002-practice-ui
intent: 008-srs-and-practice
type: simple-construction-bolt
status: planned
stories:
  - 001-practice-entry-point-and-due-count
  - 002-practice-session-assembly-and-completion
created: '2026-09-17T17:10:00Z'
started: null
completed: null
current_stage: null
stages_completed: []

requires_bolts:
  - 019-srs-tracking-service
enables_bolts: []
requires_units:
  - 001-srs-tracking-service
blocks: false

complexity:
  avg_complexity: 3
  avg_uncertainty: 3
  max_dependencies: 1
  testing_scope: 3
---

# Bolt: 020-practice-ui

## Overview

The client half of SRS & Practice: a due-count entry point and a practice-session flow built entirely from existing exercise-engine widgets.

## Objective

A learner can see how many words are due, start a practice session covering exactly those, and complete it through the same grading/XP (and Amole, if `007` has landed) path as a regular lesson.

## Stories Included

- **001-practice-entry-point-and-due-count**: entry point + badge (Must)
- **002-practice-session-assembly-and-completion**: session flow (Must)

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- [ ] **1. Plan**: Pending → implementation-plan.md
- [ ] **2. Implement**: Pending → implementation-walkthrough.md
- [ ] **3. Test**: Pending → test-walkthrough.md

## Dependencies

### Requires
- `019-srs-tracking-service` (needs the real due-items/due-count/completion contracts)

### Enables
- None (terminal bolt for this intent)

## Success Criteria

- [ ] Due-count visible and accurate before entering a session
- [ ] Session includes only exercises linked to due vocab items
- [ ] Zero new exercise-rendering code
- [ ] Offline: entry point visibly disabled, not hidden
- [ ] No regression to the regular lesson-taking flow

## Notes

Read `main.dart`'s and the dashboard's real current navigation structure at Plan stage before deciding entry-point placement (tab vs. dashboard element) — not fixed by Inception.
