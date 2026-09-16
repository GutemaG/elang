---
intent: 002-core-lesson-loop
created: 2026-09-15T17:00:00Z
completed: 2026-09-15T18:00:00Z
status: complete
---

# Inception Log: 002-core-lesson-loop

## Overview

**Intent**: The skill-tree home dashboard, lesson exercise engine (multiple-choice, listening, sentence-construction), hearts ("Beans") life system, daily streak, and lesson completion/XP award. Chosen as intent 002 because it's the most foundational remaining piece — everything else (gamification engine's leaderboards/social features, SRS review scheduling) needs lessons to exist first, and it directly replaces the "Home (out of scope)" placeholder `001-auth-onboarding` currently lands on.
**Type**: green-field
**Created**: 2026-09-15

## Artifacts Created

| Artifact | Status | File |
|----------|--------|------|
| Requirements | ✅ | requirements.md |
| System Context | ✅ | system-context.md |
| Units | ✅ | units/001-lesson-service/unit-brief.md, units/002-core-lesson-loop-ui/unit-brief.md |
| Stories | ✅ | units/001-lesson-service/stories/*.md (5), units/002-core-lesson-loop-ui/stories/*.md (5) |
| Bolt Plan | ✅ | memory-bank/bolts/004-lesson-content-service/bolt.md, memory-bank/bolts/005-lesson-engagement-service/bolt.md, memory-bank/bolts/006-core-lesson-loop-ui/bolt.md, memory-bank/bolts/007-core-lesson-loop-ui/bolt.md |

## Summary

| Metric | Count |
|--------|-------|
| Functional Requirements | 7 |
| Non-Functional Requirements | 3 (Performance, Reliability, Data) |
| Units | 2 |
| Stories | 10 |
| Bolts Planned | 4 |

## Units Breakdown

| Unit | Stories | Bolts | Priority |
|------|---------|-------|----------|
| 001-lesson-service | 5 | 2 (004-lesson-content-service, 005-lesson-engagement-service) | Must |
| 002-core-lesson-loop-ui | 5 | 2 (006-core-lesson-loop-ui, 007-core-lesson-loop-ui) | Must |

## Decision Log

| Date | Decision | Rationale | Approved |
|------|----------|-----------|----------|
| 2026-09-15 | Selected "Core lesson loop" as intent 002 over "Gamification engine" and "SRS" | Both alternatives need lessons/completion data to exist first; this also replaces the current post-sign-in placeholder | Yes |
| 2026-09-15 | Exercise types: multiple-choice + listening/audio-matching + sentence-construction, no speech/pronunciation | Matches the 3 types already in the Highland Pulse "Choice & Match Tiles" design component; speech recognition is significant extra scope, deferred | Yes |
| 2026-09-15 | Hearts ("Beans"): lose 1 per wrong answer, regen over time, lesson interrupted at 0 | Classic Duolingo-style model; matches the existing `out_of_beans_refill_modal` design screen | Yes |
| 2026-09-15 | Daily streak in scope, including a streak-freeze consumable | Matches the existing `level_up_streak_freeze_modal` design screen | Yes |
| 2026-09-15 | Content scope: engine + small real (non-lorem) placeholder curriculum, not a full course | Proves the loop end-to-end without committing this intent to full Phase 1 curriculum authoring | Yes |
| 2026-09-15 | This intent (not a future "gamification-engine" intent) owns the new streak/beans/XP-per-lesson tables | `database-schema.md`'s prior scope note had deferred those tables to a not-yet-scoped future intent, but a lesson loop without visible streak/beans/XP feedback doesn't match the approved designs | Yes |

## Scope Changes

| Date | Change | Reason | Impact |
|------|--------|--------|--------|
| 2026-09-16 | A missed exercise now loops back into the lesson queue and must be answered correctly before the lesson finishes, instead of being graded once and left behind | Explicit user request after bolt 006 completed — matches the standard Duolingo-style "retry misses within the same lesson" mechanic, which the original requirements didn't call out explicitly | `002-core-lesson-loop-ui` story 002 amended and re-verified (`LessonController` queue-based retry logic, new widget test, full suite + analyzer re-run clean); no backend/`001-lesson-service` change needed since grading and in-lesson queue state are entirely client-side |
| 2026-09-16 | Exercise grading moves client-side (ADR-5, supersedes bolt 004's ADR-4); the account ledger (beans/XP) stays server-bounded rather than fully re-derived | Bolt 005's Technical Design found ADR-4's planned per-exercise `SubmitExerciseAnswer` call would violate `requirements.md`'s "no network call per exercise" NFR — an inconsistency bolt 004 introduced without checking against Inception-level requirements | Bolt 004's lesson-content schema/tests amended (answer data now included, "never leaked" tests flipped to "present and correct"); bolt 006's `LessonApi`/`LessonController` amended (added `attemptId` idempotency key). Both bolts' full suites re-run and passing after the change |
| 2026-09-16 | `GET /skill-tree` extended with a per-skill `lesson_id` (bolt 007, amending bolt 005 again) | The real backend has multiple lessons per skill with no server-side "current lesson" ordering; the fake's "one lesson per skill" simplification had no real equivalent | Computed via one grouped query (`list_lesson_ids_by_skills`), not a per-skill loop — an N+1 was briefly introduced and caught immediately by the existing query-count performance test before being fixed properly |
| 2026-09-16 | `LessonController`/`LessonScreen` gained a completion-error retry path (bolt 007) | Audited the real-integration error-handling assumption and found `completeLesson`'s failure path genuinely didn't exist (invisible with the fake, which never throws) — the story explicitly permits fixing this rather than forcing the "no redesign" assumption | Small, additive fix: existing "Continue" button becomes the retry affordance; no new screen |
| 2026-09-16 | A "Let's fix that" interstitial now shows before a requeued (previously missed) exercise reappears, instead of it silently popping back up | Explicit user follow-up on the missed-question-loop feature — wanted the loop-back to be called out, not invisible | `LessonController` gained `awaitingRetryIntro`/`startRetryExercise()` (set whenever `continueToNext()` advances to a queue position past the original exercise count, since the queue only ever appends); `LessonScreen` gained a private `_MistakeReviewCard` full-body interstitial with its own "Continue" button. Client-side only, no backend change. Existing loop-back widget test updated to tap through the new screen; full Flutter suite (79/79) and analyzer re-run clean |

## Ready for Construction

**Checklist**:
- [x] All requirements documented
- [x] System context defined
- [x] Units decomposed
- [x] Stories created for all units
- [x] Bolts planned
- [x] Human review complete (Checkpoint 3 approved 2026-09-15)

## Next Steps

**Intent complete.** Both units (`001-lesson-service`, `002-core-lesson-loop-ui`) and all 4 bolts (004, 005, 006, 007) are done. The skill-tree dashboard, lesson exercise engine, Beans lifecycle, daily streak, and lesson completion/XP all run end-to-end against the real backend. Next intent (gamification engine, SRS, or otherwise) is a fresh Inception pass.

## Dependencies

Depends on `001-auth-onboarding` (needs a signed-in, onboarded user and the `users.daily_xp_target`/`selected_language` fields it created) — complete.
