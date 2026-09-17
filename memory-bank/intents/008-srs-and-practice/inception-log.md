---
intent: 008-srs-and-practice
created: '2026-09-17T16:40:00Z'
completed: '2026-09-17T17:15:00Z'
status: complete
---

# Inception Log: srs-and-practice

## Overview

**Intent**: Add a spaced-repetition retention engine (Leitner boxes) with a Practice entry point that reuses the existing exercise-engine UI.
**Type**: greenfield data model (vocab_items, user_vocab_progress, exercises FK) + a retrofit of shipped grading code (`complete_lesson`) + a new client entry point.
**Created**: 2026-09-17

## Artifacts Created

| Artifact | Status | File |
|----------|--------|------|
| Requirements | ✅ | requirements.md |
| System Context | ✅ | system-context.md |
| Units | ✅ | units/{unit-name}/unit-brief.md |
| Stories | ✅ | units/{unit-name}/stories/*.md |
| Bolt Plan | ✅ | memory-bank/bolts/019-srs-tracking-service/bolt.md, memory-bank/bolts/020-practice-ui/bolt.md |

## Summary

| Metric | Count |
|--------|-------|
| Functional Requirements | 6 |
| Non-Functional Requirements | 2 (Data Integrity, Performance) |
| Units | 2 |
| Stories | 6 |
| Bolts Planned | 2 |

## Units Breakdown

| Unit | Stories | Bolts | Priority |
|------|---------|-------|----------|
| 001-srs-tracking-service | 4 | 1 (019-srs-tracking-service) | Must |
| 002-practice-ui | 2 | 1 (020-practice-ui) | Must |

## Decision Log

| Date | Decision | Rationale | Approved |
|------|----------|-----------|----------|
| 2026-09-17 | Corrected scope after reading real source: `vocab_items`/`user_vocab_progress` don't exist anywhere (only mentioned aspirationally in standards docs), and `exercises` has no `vocab_item_id`. This is greenfield schema, not a dormant-column retrofit. | Verified against `database-schema.md`'s real `exercises` table definition and a codebase-wide search | Yes |
| 2026-09-17 | No tabbed/bottom-nav shell exists in `main.dart` today — "Practice tab" placement is deliberately left open as a Technical Design/Plan-stage decision rather than assumed | Verified by reading `main.dart`'s real current routing | Yes |
| 2026-09-17 | Proceed with full scope (both bolts) despite the larger-than-assumed backend unit | User's explicit Checkpoint 1 choice | Yes |
| 2026-09-17 | Split into a 4th backend story (`004-due-items-and-count-endpoints`) separate from the algorithm story, since the endpoints and the transition math are independently testable concerns | Keeps each story's acceptance criteria focused; mirrors how other intents split "policy" stories from "endpoint" stories | Yes |
| 2026-09-17 | Flagged (not resolved) that `complete_lesson`'s completion request may need to widen to carry per-exercise correctness, since the client currently reports only aggregate `correct_count`/`total_count` | This codebase's `LessonAttempt`/`complete_lesson` shape wasn't confirmed to carry per-exercise detail during Inception (source-reading is deferred to Construction Stage 4 for DDD bolts) — explicitly flagged in story `002-vocab-progress-retrofit` rather than silently assumed either way | Yes |

## Scope Changes

| Date | Change | Reason | Impact |
|------|--------|--------|--------|
| 2026-09-17 | Expanded `001-srs-tracking-service` from "retrofit if missing" to "full greenfield schema + retrofit" | No existing schema to retrofit at all | Bolt `019` is larger/higher-complexity than the original build prompt implied |
| 2026-09-17 | Left Practice's UI placement (tab vs. dashboard element) unresolved at Inception | No tabbed nav shell exists to plug into; forcing a "tab" would be an undocumented UI-structure decision made without reading real navigation code | Explicit open question carried to Technical Design/Plan stage in both requirements.md and the `002-practice-ui` unit brief |

## Ready for Construction

**Checklist**:
- [x] All requirements documented
- [x] System context defined
- [x] Units decomposed
- [x] Stories created for all units
- [x] Bolts planned
- [x] Human review complete

No external precondition blocks this intent — both bolts (`019-srs-tracking-service`, `020-practice-ui`) are ready to start Construction whenever the user says so, sequenced after `007-amole-currency`'s bolts by user preference.

## Next Steps

1. Finish `007-amole-currency`'s Construction first (user's stated sequencing preference).
2. Start Construction on `019-srs-tracking-service` when the user is ready.
3. Then `020-practice-ui`.
4. Do not auto-start any bolt on a generic "continue" — confirm which bolt the user wants started next.

## Dependencies

Retrofits `005-lesson-engagement-service`'s `complete_lesson`. Reuses (does not modify) exercise-engine UI from `002-core-lesson-loop-ui`/`006-core-lesson-loop-ui`/`012-match-pairs-ui`. Composes with `003-offline-caching-and-sync`'s idempotent-replay mechanism. Should coordinate with, but does not hard-block on, `007-amole-currency`.
