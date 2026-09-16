---
intent: 002-core-lesson-loop
phase: inception
status: complete
created: '2026-09-15T17:00:00Z'
updated: '2026-09-15T18:00:00Z'
---

# Requirements: Core Lesson Loop

## Intent Overview

Let a signed-in, onboarded Buna user actually take a lesson and see progress. This replaces the "Home (out of scope for this bolt)" placeholder that `001-auth-onboarding` currently lands on, and is the foundation every later intent (gamification engine, SRS) builds on — there is nothing to gamify or review without a lesson loop first. Covers the skill-tree home dashboard, the lesson exercise engine, the hearts ("Beans") life system, the daily streak, and lesson completion/XP award — matching the already-produced Stitch designs (`4._home_skill_tree_dashboard`, `lesson_complete_summary_1/2`, `level_up_streak_freeze_modal`, `out_of_beans_refill_modal`).

## Business Goals

| Goal | Success Metric | Priority |
|------|----------------|----------|
| A signed-in user can complete a full lesson end-to-end | Skill-tree node state updates (locked → active → completed) after a lesson finishes | Must |
| Daily goal chosen at onboarding becomes a visible, trackable mechanic | XP earned today vs. the account's `daily_xp_target` is shown after each lesson | Must |
| Users have a reason to return daily | Streak counter increments on any day with ≥1 completed lesson, resets on a missed day (unless frozen) | Must |
| Mistakes have a real but non-punishing cost | Beans deplete on wrong answers and interrupt the lesson at 0, without permanently blocking progress (regen over time) | Must |

---

## Functional Requirements

### FR-1: Home / Skill-Tree Dashboard
- **Description**: The screen a signed-in user lands on (replacing the current placeholder) shows the skill tree as a serpentine path of nodes, each locked, active, or completed, with a crown-level badge (1-5) on completed skills. Tapping an active node starts a lesson.
- **Acceptance Criteria**:
  - Dashboard is the post-sign-in / post-splash-resume destination for a user with a valid session (per `001-auth-onboarding`'s `AuthFlowController`).
  - Node state (locked/active/completed) reflects the user's actual skill progress, not a static mock.
  - Only the next unlocked skill(s) are tappable; locked nodes show a lock affordance and are not interactive.
- **Priority**: Must
- **Related Stories**: TBD

### FR-2: Lesson Exercise Engine
- **Description**: A lesson is an ordered sequence of exercises drawn from 3 types: multiple-choice translation, audio listening/matching, and sentence construction (tap-to-build from a word bank). Each answer gets immediate correct/incorrect visual feedback matching the design's tile states.
- **Acceptance Criteria**:
  - All 3 exercise types are supported by the lesson engine (not just multiple-choice).
  - A correct answer shows the "correct" tile state and advances to the next exercise.
  - An incorrect answer shows the "incorrect" tile state (shake animation per design) and consumes one bean (see FR-3).
  - Lesson content (all exercises for the lesson) loads once at lesson start — no per-exercise network round trip.
- **Priority**: Must
- **Related Stories**: TBD

### FR-3: Hearts ("Beans") Life System
- **Description**: A user starts each lesson with a fixed number of beans. Each wrong answer consumes one. Reaching 0 beans mid-lesson interrupts the lesson and shows the "out of beans" refill screen.
- **Acceptance Criteria**:
  - Beans are consumed exactly once per wrong answer, never for a correct answer.
  - At 0 beans, the current lesson is interrupted (progress within that lesson attempt is not counted as complete).
  - Beans regenerate automatically over time (rate is a technical-design constant, not fixed here); the refill screen also offers an immediate-refill path using a currency this intent introduces minimally for this purpose (full gem economy/IAP is out of scope — see Constraints).
  - Running out of beans never crashes the app and never loses onboarding/account state.
- **Priority**: Must
- **Related Stories**: TBD

### FR-4: Daily Streak
- **Description**: A visible daily streak counter increments once per calendar day in which the user completes at least one lesson, and resets to 0 if a full day is missed — unless protected by a streak freeze.
- **Acceptance Criteria**:
  - Streak increments at most once per calendar day, regardless of how many lessons are completed that day.
  - Missing a full calendar day resets the streak to 0, unless an active streak freeze protects that day.
  - A streak-freeze consumable exists and, when active, prevents exactly one missed day from resetting the streak (earn/acquisition mechanic is a technical-design decision, not fixed here).
- **Priority**: Must
- **Related Stories**: TBD

### FR-5: Lesson Completion & XP Award
- **Description**: Finishing a lesson (without running out of beans) shows a lesson-complete summary (XP earned, accuracy, streak update) and awards XP toward the account's `daily_xp_target` set during onboarding.
- **Acceptance Criteria**:
  - XP is awarded exactly once per successful lesson completion (no double-award on retry/re-navigation).
  - The summary screen shows XP earned this lesson and progress toward today's `daily_xp_target`.
  - Completing a lesson updates the corresponding skill-tree node's state (e.g., unlocks the next node; see FR-6 for crown levels).
- **Priority**: Must
- **Related Stories**: TBD

### FR-6: Skill Progression & Crown Levels
- **Description**: Completing all lessons in a skill unlocks the next skill node. Replaying a completed skill's lessons again increases that skill's crown level, up to 5, per the design's crown badge.
- **Acceptance Criteria**:
  - A skill's lessons must all be completed at least once before the next skill node unlocks.
  - Crown level starts at 1 on first full completion and increases by 1 per subsequent full replay, capped at 5.
  - Crown level is visible on the skill-tree node (per FR-1).
- **Priority**: Should
- **Related Stories**: TBD

### FR-7: Seed Curriculum Content
- **Description**: A small, real, hand-authored English→Amharic curriculum (2-3 skills, a handful of lessons each, using all 3 exercise types from FR-2) is seeded so the full loop can be exercised end-to-end.
- **Acceptance Criteria**:
  - At least 2 skills exist, each with multiple lessons, each lesson containing a mix of the 3 supported exercise types.
  - Content is real Amharic (not lorem-ipsum placeholders), sufficient to demo the loop, but is explicitly not a complete Phase 1 course.
- **Priority**: Must
- **Related Stories**: TBD

---

## Non-Functional Requirements

### Performance
| Requirement | Metric | Target |
|-------------|--------|--------|
| Exercise transition | Time between submitting an answer and the next exercise rendering | Instant — no network call per exercise (lesson payload fetched once at lesson start) |

### Reliability
| Requirement | Metric | Target |
|-------------|--------|--------|
| Mid-lesson durability | App kill/background during a lesson | No crash; no duplicate XP award; lesson can be safely restarted |

### Data
| Requirement | Standard | Notes |
|-------------|----------|-------|
| Audio assets (listening exercises) | Cloudflare R2 | Per `memory-bank/standards/tech-stack.md` |

---

## Constraints

### Technical Constraints

**Project-wide standards**: Loaded from `memory-bank/standards/` by Construction Agent (tech-stack.md, data-stack.md, coding-standards.md).

**Intent-specific constraints**:
- No microphone/speech-recognition exercise type in this intent — pronunciation practice is explicitly deferred.
- No full gem/currency economy or in-app purchases — a minimal currency concept may be introduced only as a beans-refill mechanism (FR-3); payment integration is out of scope.
- No leaderboards, friend competition, or other social-gamification features — that belongs to a future `gamification-engine` intent.
- No spaced-repetition/review-session logic — lessons here are the forward skill-tree path only; a future `SRS` intent owns review scheduling.
- `database-schema.md`'s existing scope note defers "XP ledger / streak / Beans" tables to a future `gamification-engine` intent — this intent supersedes that note for the specific tables it needs (streak, beans, XP-per-lesson), since a lesson loop without visible streak/beans/XP feedback doesn't match the approved designs. Technical Design for this intent will own those new tables.

### Business Constraints
- Curriculum content authored for this intent is a small proof-of-loop set (FR-7), not a commitment to full Phase 1 course completeness.

---

## Assumptions

| Assumption | Risk if Invalid | Mitigation |
|------------|-----------------|------------|
| New tables for skills/lessons/exercises/progress/streak/beans/XP are this intent's own to design (not a separate `gamification-engine` intent) | Rework/table ownership conflict if a `gamification-engine` intent is scoped later expecting to own streak/beans tables | Flag explicitly in this intent's Technical Design; future intents extend rather than redefine these tables |
| The 3 exercise types (multiple-choice, listening, sentence-construction) in the Stitch "Choice & Match Tiles" component are sufficient for a believable lesson loop without speech input | Users perceive the lesson as incomplete vs. competitor apps | Speech/pronunciation exercises are a clearly scoped future addition, not silently dropped |

---

## Open Questions

| Question | Owner | Due Date | Resolution |
|----------|-------|----------|------------|
| Which exercise types for Phase 1? | Product | Requirements step | ✅ Resolved — multiple-choice + listening + sentence-construction |
| Beans/hearts mechanic? | Product | Requirements step | ✅ Resolved — lose 1 per wrong answer, regen over time, interrupt at 0 |
| Streak system in scope? | Product | Requirements step | ✅ Resolved — yes, streak counter + freeze item |
| Curriculum content scope? | Product | Requirements step | ✅ Resolved — engine + small real placeholder curriculum |
| Exact minutes→daily-XP-target mapping formula | Product/Eng | Technical design (Construction) | Pending — shared open item with `001-auth-onboarding`'s requirements.md |
| Bean regen rate (time per bean) | Eng | Technical design (Construction) | Pending — tunable constant |
| Streak-freeze earn/acquisition mechanic | Product | Technical design (Construction) | Pending |
