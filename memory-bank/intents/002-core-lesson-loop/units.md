---
intent: 002-core-lesson-loop
phase: inception
status: units-decomposed
updated: 2026-09-15T18:00:00Z
---

# Core Lesson Loop - Unit Decomposition

## Requirement-to-Unit Mapping

- **FR-1** (Home / Skill-Tree Dashboard) → `002-core-lesson-loop-ui`
- **FR-2** (Lesson Exercise Engine) → `001-lesson-service`
- **FR-3** (Hearts/"Beans" Life System) → `001-lesson-service`
- **FR-4** (Daily Streak) → `001-lesson-service`
- **FR-5** (Lesson Completion & XP Award) → `001-lesson-service`
- **FR-6** (Skill Progression & Crown Levels) → `001-lesson-service`
- **FR-7** (Seed Curriculum Content) → `001-lesson-service`

Note: `002-core-lesson-loop-ui` implements the screens for FR-2 through FR-6 as well (it's the only client), but the acceptance criteria and business rules for those FRs are owned by `001-lesson-service` — same pattern as `001-auth-onboarding`.

## Units Overview

This intent decomposes into 2 units of work:

### Unit 1: 001-lesson-service

**Description**: FastAPI backend service owning skill/lesson/exercise content, answer validation, the Beans (hearts) life system, XP award, skill-progress/crown-level tracking, and the daily streak.

**Stories**:

- 001-serve-skill-tree-and-lesson-content
- 002-answer-exercises-and-manage-beans
- 003-complete-lesson-award-xp-and-progress
- 004-daily-streak-and-freeze
- 005-seed-curriculum-content

**Deliverables**:

- `skills`, `lessons`, `exercises` content tables + seed data (via SQLAlchemy, per `data-stack.md`)
- `user_skill_progress` (crown level, unlock state), `user_beans`, `user_streaks` tables
- REST endpoints: fetch skill tree, fetch lesson content, submit exercise answer, complete lesson, refill beans

**Dependencies**:

- Depends on: `001-auth-service` (existing, from intent `001-auth-onboarding`) for session validation and the `users` row (`daily_xp_target`, `selected_language`)
- Depended by: `002-core-lesson-loop-ui`

**Estimated Complexity**: L

### Unit 2: 002-core-lesson-loop-ui

**Description**: Flutter client screens for the skill-tree home dashboard, lesson exercise screens (multiple-choice, listening, sentence-construction), the out-of-beans refill modal, the lesson-complete summary, and the streak/level-up modal. Matches the Stitch designs already produced (`4._home_skill_tree_dashboard`, `lesson_complete_summary_1/2`, `level_up_streak_freeze_modal`, `out_of_beans_refill_modal`).

**Stories**:

- 001-skill-tree-dashboard-screen
- 002-lesson-exercise-screens
- 003-out-of-beans-and-refill-modal
- 004-lesson-complete-streak-and-levelup-modals
- 005-real-backend-integration

**Deliverables**:

- Flutter screens for the full lesson loop, matching the exported Stitch designs
- Local in-lesson state holder (current exercise index, beans remaining this attempt)
- API client calls into `001-lesson-service` endpoints

**Dependencies**:

- Depends on: `001-lesson-service` (needs its API contract to integrate against; can scaffold screens from Technical Design stage before backend implementation is complete — same pattern as `001-auth-onboarding`)
- Depended by: None

**Estimated Complexity**: M

## Unit Dependency Graph

```text
[001-lesson-service] ──> [002-core-lesson-loop-ui]
```

## Execution Order

Based on dependencies:

1. `001-lesson-service` first (foundation — defines the API contract the UI integrates against)
2. `002-core-lesson-loop-ui` second (can start screen-building in parallel once the API contract from `001-lesson-service`'s Technical Design stage is available, but full integration waits on backend implementation — planned explicitly as its own story this time, story 005, rather than a surprise addition like `001-auth-onboarding`'s bolt 003)
