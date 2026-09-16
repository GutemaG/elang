---
unit: 002-core-lesson-loop-ui
intent: 002-core-lesson-loop
phase: inception
status: complete
created: '2026-09-15T18:00:00Z'
updated: '2026-09-15T18:00:00Z'
unit_type: frontend
default_bolt_type: simple-construction-bolt
---

# Unit Brief: Core Lesson Loop UI

## Purpose

Flutter client screens for the full lesson loop: the skill-tree home dashboard, lesson exercise screens (multiple-choice, listening, sentence-construction), the out-of-beans refill modal, the lesson-complete summary, and the streak/level-up modal. Matches the Highland Pulse designs already produced.

## Scope

### In Scope
- Skill-tree dashboard screen (replaces the current `001-auth-onboarding` "Home (out of scope)" placeholder)
- Lesson exercise screens for all 3 supported types, with correct/incorrect tile feedback
- Out-of-beans interruption + refill modal
- Lesson-complete summary screen and the streak/level-up/freeze modal
- Real integration against `001-lesson-service`'s live API

### Out of Scope
- Any backend business logic (owned by `001-lesson-service`)
- Speech/pronunciation UI (no such exercise type exists yet — see requirements.md)
- Any gem-store/IAP purchase UI beyond the single "refill beans" action already covered by the out-of-beans modal

---

## Assigned Requirements

| FR | Requirement | Priority |
|----|-------------|----------|
| FR-1 | Home / Skill-Tree Dashboard | Must |
| FR-2 | Lesson Exercise Engine (UI) | Must |
| FR-3 | Hearts ("Beans") Life System (UI) | Must |
| FR-4 | Daily Streak (UI) | Must |
| FR-5 | Lesson Completion & XP Award (UI) | Must |
| FR-6 | Skill Progression & Crown Levels (UI) | Should |

---

## Domain Concepts

### Key Entities
| Entity | Description | Attributes |
|--------|-------------|------------|
| SkillTreeNode (client model) | One node as rendered on the dashboard | id, title, state (locked/active/completed), crown_level |
| InLessonState (client-only) | Local state for a lesson currently being taken | lesson_id, exercises, current_index, beans_remaining, answers_given |
| LessonResult (client model) | Result shown on the completion screen | xp_earned, daily_xp_total, daily_xp_target, streak_count, skill_unlocked |

### Key Operations
| Operation | Description | Inputs | Outputs |
|-----------|-------------|--------|---------|
| LoadSkillTree | Fetch and render the dashboard | (session token, implicit) | Rendered skill-tree screen |
| StartLesson | Fetch lesson content once, initialize local in-lesson state | lesson_id | Rendered first exercise |
| SubmitAnswer | Send an answer, update local beans/feedback state | exercise_id, answer | Correct/incorrect UI state, updated local beans |
| FinishLesson | Call complete-lesson, render summary | lesson_attempt_id | Rendered completion + streak/level-up UI |

---

## Story Summary

| Metric | Count |
|--------|-------|
| Total Stories | 5 |
| Must Have | 4 |
| Should Have | 1 |
| Could Have | 0 |

### Stories

| Story ID | Title | Priority | Status |
|----------|-------|----------|--------|
| 001-skill-tree-dashboard-screen | Skill-tree home dashboard | Must | Planned |
| 002-lesson-exercise-screens | Lesson exercise screens (3 types) | Must | Planned |
| 003-out-of-beans-and-refill-modal | Out-of-beans interruption + refill | Must | Planned |
| 004-lesson-complete-streak-and-levelup-modals | Lesson-complete summary + streak/level-up | Should | Planned |
| 005-real-backend-integration | Real backend integration | Must | Planned |

---

## Dependencies

### Depends On
| Unit | Reason |
|------|--------|
| `001-lesson-service` | Needs its API contract (available from Technical Design) to integrate the lesson-loop screens; needs it implemented for story 005 |

### Depended By
| Unit | Reason |
|------|--------|
| None | Terminal unit for this intent |

### External Dependencies
| System | Purpose | Risk |
|--------|---------|------|
| None directly (audio fetched via URLs returned by `001-lesson-service`) | — | — |

---

## Technical Context

### Suggested Technology
Flutter/Dart, following the same `features/{feature}/` structure as `001-auth-onboarding`'s `lib/features/auth/`. Reuses the existing `SessionRepository`/secure-storage session mechanism for authenticated API calls — no new session handling needed.

### Integration Points
| Integration | Type | Protocol |
|-------------|------|----------|
| `001-lesson-service` | API | REST over HTTPS, authenticated via existing session token |

### Data Storage
| Data | Type | Volume | Retention |
|------|------|--------|-----------|
| In-lesson state | In-memory (Dart state, not persisted) | Single active lesson | Cleared on lesson exit; server is source of truth for anything durable |

---

## Constraints

- No screen/controller redesign of the existing auth/onboarding flow — this unit only adds the post-sign-in destination and beyond.
- Follows the Highland Pulse design system (`stich-screens/extracted/.../highland_pulse/DESIGN.md`) for all new screens, same as `001-auth-onboarding`'s UI followed it for auth/onboarding screens.

---

## Success Criteria

### Functional
- [ ] Skill-tree dashboard renders real progress state, not mock data (after story 005)
- [ ] All 3 exercise types are playable end-to-end with correct/incorrect feedback
- [ ] Out-of-beans, lesson-complete, and streak/level-up modals render matching the Stitch designs

### Non-Functional
- [ ] No network call per exercise — lesson content fetched once at lesson start
- [ ] Mid-lesson app kill/resume doesn't crash or corrupt local state

### Quality
- [ ] Widget test coverage for all new screens
- [ ] All acceptance criteria met
- [ ] Code reviewed and approved

---

## Bolt Suggestions

| Bolt | Type | Stories | Objective |
|------|------|---------|-----------|
| 006-core-lesson-loop-ui | Simple | 001, 002, 003, 004 | All lesson-loop screens, built against a documented contract/fake API in parallel with backend construction |
| 007-core-lesson-loop-ui | Simple | 005 | Swap the fake API for the real, now-implemented `001-lesson-service` |

---

## Notes

Same split as `001-auth-onboarding` (mock-first UI bolt, then a real-integration bolt) — that pattern worked well there and lets backend/frontend construction proceed in parallel. This time the integration story (005) is planned upfront rather than discovered as a surprise gap after the fact.
