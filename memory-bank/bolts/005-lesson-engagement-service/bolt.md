---
id: 005-lesson-engagement-service
unit: 001-lesson-service
intent: 002-core-lesson-loop
type: ddd-construction-bolt
status: complete
stories:
  - 002-answer-exercises-and-manage-beans
  - 003-complete-lesson-award-xp-and-progress
  - 004-daily-streak-and-freeze
created: '2026-09-15T18:00:00Z'
started: '2026-09-16T12:00:00Z'
current_stage: null
stages_completed:
  - name: model
    completed: '2026-09-16T12:05:00Z'
    artifact: ddd-01-domain-model.md
  - name: design
    completed: '2026-09-16T12:20:00Z'
    artifact: ddd-02-technical-design.md
  - name: adr
    completed: '2026-09-16T12:30:00Z'
    artifact: adr-5-client-side-grading-with-bounded-server-ledger.md
  - name: implement
    completed: '2026-09-16T13:45:00Z'
    artifact: (code changes across app/domain/lesson, app/application, app/infrastructure)
  - name: test
    completed: '2026-09-16T14:00:00Z'
    artifact: ddd-03-test-report.md
requires_bolts:
  - 004-lesson-content-service
enables_bolts:
  - 007-core-lesson-loop-ui
requires_units:
  - 001-auth-service
blocks: true
complexity:
  avg_complexity: 3
  avg_uncertainty: 2
  max_dependencies: 1
  testing_scope: 3
completed: '2026-09-16T07:36:35Z'
---

# Bolt: 005-lesson-engagement-service

## Overview

Second bolt for the `001-lesson-service` unit. Builds the engagement mechanics layered on top of bolt 004's content model: answer grading + the Beans (hearts) lifecycle, XP award + lesson completion + skill progression/crown levels, and the daily streak with freeze protection.

## Objective

Deliver the write-side/state-tracking half of the lesson loop: grading answers, managing beans, awarding XP exactly once per completion, updating skill progress and the daily streak.

## Stories Included

- **002-answer-exercises-and-manage-beans**: Validate answers + manage Beans lifecycle (Must)
- **003-complete-lesson-award-xp-and-progress**: Complete lesson, award XP, update skill progress (Must)
- **004-daily-streak-and-freeze**: Daily streak + freeze protection (Should)

## Bolt Type

**Type**: DDD Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/ddd-construction-bolt.md`

## Stages

- ✅ **1. Domain Model**
- ✅ **2. Technical Design**
- ✅ **3. ADR Analysis** (ADR-5, supersedes ADR-4's answer-key clause)
- ✅ **4. Implement**
- ✅ **5. Test**

## Dependencies

### Requires
- `004-lesson-content-service` (Required): must be complete — this bolt validates answers and completes lessons against real content/seed data

### Enables
- `007-core-lesson-loop-ui` (the UI's real-integration story needs this bolt's endpoints live)

## Success Criteria

- [x] Wrong answers consume a bean; 0 beans interrupts the lesson; beans regenerate over time
- [x] Lesson completion awards XP exactly once, idempotent on retry
- [x] Skill progression (unlock next skill, crown level) updates correctly on completion
- [x] Daily streak increments once per day, resets on a missed day unless a freeze is active

## Notes

This bolt spans 3 distinct-but-related aggregates (Beans, XP/progress, streak) rather than one — if Technical Design finds these warrant further splitting, that's an acceptable replan (per Construction's ownership of bolt replanning), but they're grouped here because all 3 are triggered by the same `CompleteLesson`/`SubmitExerciseAnswer` operations and share the same session/user-resolution context.
