---
unit: 001-lesson-service
intent: 002-core-lesson-loop
phase: inception
status: complete
created: '2026-09-15T18:00:00Z'
updated: '2026-09-15T18:00:00Z'
unit_type: backend
default_bolt_type: ddd-construction-bolt
---

# Unit Brief: Lesson Service

## Purpose

Own the core lesson loop for Buna: serve skill/lesson/exercise content, validate exercise answers, track the Beans (hearts) life system, award XP on lesson completion, track skill progress and crown levels, and track the daily streak (with freeze protection).

## Scope

### In Scope
- Skill tree, lesson, and exercise content model + serving endpoints
- Exercise-answer validation (multiple-choice, listening, sentence-construction)
- Beans: consumption on wrong answer, lesson interruption at 0, time-based regeneration, immediate refill
- XP award on lesson completion, exactly once per completion, tied to the existing `users.daily_xp_target`
- Skill progression: unlocking the next skill node, crown-level increment (1-5) on repeat completion
- Daily streak: increment on first completion of a calendar day, reset on a missed day, streak-freeze protection
- Seed data: a small, real, hand-authored English→Amharic curriculum (2-3 skills)

### Out of Scope
- Rendering any UI (owned by `002-core-lesson-loop-ui`)
- Authentication/session issuance (owned by the existing `001-auth-service` from intent `001-auth-onboarding` — this unit only validates an existing session token)
- Speech/pronunciation exercises (deferred per requirements.md constraints)
- Full gem/currency economy, in-app purchases, leaderboards, social features (deferred to a future `gamification-engine` intent)
- Spaced-repetition review scheduling (deferred to a future `SRS` intent)

---

## Assigned Requirements

| FR | Requirement | Priority |
|----|-------------|----------|
| FR-2 | Lesson Exercise Engine | Must |
| FR-3 | Hearts ("Beans") Life System | Must |
| FR-4 | Daily Streak | Must |
| FR-5 | Lesson Completion & XP Award | Must |
| FR-6 | Skill Progression & Crown Levels | Should |
| FR-7 | Seed Curriculum Content | Must |

---

## Domain Concepts

### Key Entities
| Entity | Description | Attributes |
|--------|-------------|------------|
| Skill | A node in the skill tree | id, title, order, lesson_ids |
| Lesson | An ordered set of exercises belonging to a skill | id, skill_id, order, exercise_ids |
| Exercise | A single question of one of 3 types | id, lesson_id, type (multiple_choice/listening/sentence_construction), prompt, correct_answer, distractors/word_bank, audio_url (listening only) |
| UserSkillProgress | Per-user, per-skill progress state | user_id, skill_id, unlocked, crown_level (1-5), completed_at |
| UserBeans | Per-user Beans state | user_id, current_count, last_regen_at |
| UserStreak | Per-user streak state | user_id, current_streak, last_completed_date, active_freeze_count |
| LessonAttempt | One in-progress or completed attempt at a lesson | id, user_id, lesson_id, beans_consumed, xp_awarded, completed_at |

### Key Operations
| Operation | Description | Inputs | Outputs |
|-----------|-------------|--------|---------|
| GetSkillTree | Return the user's skill tree with per-skill unlock/crown state | user_id (from session) | List of skills with state |
| GetLessonContent | Return all exercises for a lesson in one payload | lesson_id, user_id | Lesson + ordered exercises (no answer keys leaked beyond what's needed to grade client-side vs. server-side — a Technical Design decision) |
| SubmitExerciseAnswer | Validate one answer; consume a bean on wrong answer; interrupt at 0 | lesson_attempt_id, exercise_id, submitted_answer | Correct/incorrect, beans_remaining |
| CompleteLesson | Finalize a lesson attempt: award XP once, update skill progress/crown level, update streak | lesson_attempt_id | XP awarded, new daily XP total, updated skill state, updated streak |
| RefillBeans | Immediate refill via the minimal introduced currency, or query current regen state | user_id | Beans count, next regen time |

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
| 001-serve-skill-tree-and-lesson-content | Serve skill tree + lesson content | Must | Planned |
| 002-answer-exercises-and-manage-beans | Validate answers + manage Beans lifecycle | Must | Planned |
| 003-complete-lesson-award-xp-and-progress | Complete lesson, award XP, update skill progress | Must | Planned |
| 004-daily-streak-and-freeze | Daily streak + freeze protection | Should | Planned |
| 005-seed-curriculum-content | Seed a small real Amharic curriculum | Must | Planned |

---

## Dependencies

### Depends On
| Unit | Reason |
|------|--------|
| `001-auth-service` (intent `001-auth-onboarding`, existing) | Session validation and the `users` row (`daily_xp_target`, `selected_language`) |

### Depended By
| Unit | Reason |
|------|--------|
| `002-core-lesson-loop-ui` | Needs the lesson-service API contract to integrate the lesson-loop screens |

### External Dependencies
| System | Purpose | Risk |
|--------|---------|------|
| Cloudflare R2 | Hosts listening-exercise audio | Low — static asset hosting, no auth flow involved |

---

## Technical Context

### Suggested Technology
FastAPI + SQLAlchemy (async) + Alembic per `memory-bank/standards/tech-stack.md` and `data-stack.md`, same patterns as `001-auth-service`. Lives in the same `backend/` app, new router module(s) alongside the existing auth router.

**Local dev/test database**: SQLite via `aiosqlite`, same as `001-auth-service`. PostgreSQL remains the real-deployment target.

### Integration Points
| Integration | Type | Protocol |
|-------------|------|----------|
| `002-core-lesson-loop-ui` | API | REST over HTTPS |
| `001-auth-service` | Internal | Shared session-validation dependency, same FastAPI app |
| Cloudflare R2 | External asset host | HTTPS (static URLs) |

### Data Storage
| Data | Type | Volume | Retention |
|------|------|--------|-----------|
| skills, lessons, exercises | SQL (PostgreSQL) | Low (small seed curriculum) | Indefinite (content) |
| user_skill_progress, user_beans, user_streaks, lesson_attempts | SQL (PostgreSQL) | Grows per user per lesson | Indefinite (progress data) |

---

## Constraints

- Every endpoint requires a valid session token from `001-auth-service` — no new auth scheme.
- XP must be awarded exactly once per lesson completion — idempotency on `CompleteLesson` is a hard requirement (NFR: reliability).
- Lesson content must be servable in a single request per the performance NFR (no per-exercise round trip).
- This unit — not a hypothetical future `gamification-engine` unit — owns the streak/beans/XP-per-lesson tables (see `requirements.md` Constraints section for why).

---

## Success Criteria

### Functional
- [ ] A user can fetch the skill tree and see accurate locked/active/completed/crown state
- [ ] A user can fetch a full lesson's exercises in one request and submit answers against it
- [ ] Beans deplete on wrong answers, interrupt the lesson at 0, and regenerate over time
- [ ] Completing a lesson awards XP exactly once, updates skill progress, and updates the streak

### Non-Functional
- [ ] No duplicate XP award on retry/re-navigation after a completed lesson
- [ ] Lesson content payload requires exactly one request per lesson start

### Quality
- [ ] Code coverage > 80% on lesson-service logic
- [ ] All acceptance criteria met
- [ ] Code reviewed and approved

---

## Bolt Suggestions

| Bolt | Type | Stories | Objective |
|------|------|---------|-----------|
| 004-lesson-content-service | DDD | 001, 005 | Content model + serving + seed data — foundation the rest of the unit builds on |
| 005-lesson-engagement-service | DDD | 002, 003, 004 | Answer validation, Beans, XP/completion, streak — the engagement mechanics layered on top of content |

---

## Notes

Split into 2 bolts (unlike `001-auth-service`'s single bolt) because this unit spans multiple distinct aggregates (content vs. Beans vs. streak vs. XP/progress) rather than one cohesive aggregate — the engagement-mechanics bolt genuinely depends on the content bolt existing first (you can't validate an answer or complete a lesson that doesn't exist yet).
