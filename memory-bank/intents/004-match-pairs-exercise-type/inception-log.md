---
intent: 004-match-pairs-exercise-type
created: '2026-09-17T04:00:00Z'
completed: '2026-09-17T04:40:00Z'
status: complete
---

# Inception Log: match-pairs-exercise-type

## Overview

**Intent**: Add the `match_pairs` exercise type (4th of the 5 originally-planned exercise types) to the lesson engine, client-side and backend.
**Type**: brown-field (extends `002-core-lesson-loop`'s existing exercise-type dispatch)
**Created**: 2026-09-17

## Artifacts Created

| Artifact | Status | File |
|----------|--------|------|
| Requirements | ✅ | requirements.md |
| System Context | ✅ | system-context.md |
| Units | ✅ | units/{unit-name}/unit-brief.md |
| Stories | ✅ | units/{unit-name}/stories/*.md |
| Bolt Plan | ✅ | memory-bank/bolts/011-match-pairs-service/bolt.md, memory-bank/bolts/012-match-pairs-ui/bolt.md |

## Summary

| Metric | Count |
|--------|-------|
| Functional Requirements | 4 |
| Non-Functional Requirements | 0 (reuses existing standards, no new NFRs) |
| Units | 2 |
| Stories | 3 (1 retired post-approval — see Scope Changes) |
| Bolts Planned | 2 |

## Units Breakdown

| Unit | Stories | Bolts | Priority |
|------|---------|-------|----------|
| 001-match-pairs-service | 1 | 1 (011-match-pairs-service) | Must |
| 002-match-pairs-ui | 2 | 1 (012-match-pairs-ui) | Must |

## Decision Log

| Date | Decision | Rationale | Approved |
|------|----------|-----------|----------|
| 2026-09-17 | Split the "2 remaining exercise types + missing Settings screen" gap analysis into 3 separate intents (004-match-pairs-exercise-type, 005-profile-and-settings, 006-speak-check-exercise-type), built in that order | match_pairs has no external dependency (build first); speak_check needs Google Cloud Speech-to-Text (bigger lift, sequenced last); Settings is unrelated scope, sequenced between them per user's stated priority | Yes |
| 2026-09-17 | Pair content is text ↔ text only for v1 (Amharic term ↔ English translation), interaction is tap-tile-pairs (not drag-to-match) | User's explicit choice at Checkpoint 1 — simplest to build, reuses existing curriculum data and existing tap-based interaction pattern | Yes |
| 2026-09-17 | Decomposed into 2 units mirroring the existing backend-service + frontend-UI split used by `002-core-lesson-loop` and `003-offline-caching-and-sync` | Consistency with established project decomposition pattern; clean dependency seam (UI needs the real backend contract first) | Yes |

## Scope Changes

| Date | Change | Reason | Impact |
|------|--------|--------|--------|
| 2026-09-17 | Retired story `002-grade-match-pairs-attempts` from `001-match-pairs-service`; reassigned FR-2 to `002-match-pairs-ui` (no new story needed — covered by existing `001-match-pairs-exercise-screen` AC) | Discovered during Construction bolt `011-match-pairs-service`'s Stage 1 prior-decision lookup: ADR-5 already established that all exercise grading is client-side, not backend | -1 story, `001-match-pairs-service` shrinks to FR-1 only; `002-match-pairs-ui`'s scope description updated, no new story or bolt needed |
| 2026-09-17 | FR-1's content model corrected: separate `content`/`answer_key` fields (mirroring `multiple_choice`), not one self-revealing blob; a migration (`c726efa81972`) was needed after all | Discovered reading real code at bolt `011`'s Implement stage: `Exercise.answer_key` is mandatory and every existing type keeps it separate; `exercises.type` has a `CHECK` constraint that doesn't auto-widen | No story/bolt count change — same story, corrected implementation detail |
| 2026-09-17 | FR-3's interaction model corrected: atomic build-then-Check grading (matching every other exercise type), not live per-pair lock/flash feedback | Discovered reading real code at bolt `012`'s Plan stage: no exercise type in this codebase has live per-token feedback before an explicit Check; introducing one here would be inconsistent and unnecessary extra work | No story/bolt count change — same story, corrected UX detail, approved at bolt 012's Stage 1 checkpoint |

## Ready for Construction

**Checklist**:
- [x] All requirements documented
- [x] System context defined
- [x] Units decomposed
- [x] Stories created for all units
- [x] Bolts planned
- [x] Human review complete

## Next Steps

1. Begin Construction Phase
2. Start with Unit: `001-match-pairs-service`
3. Execute: `/specsmd-construction-agent --unit="001-match-pairs-service"`

## Dependencies

Depends on `002-core-lesson-loop` (extends its exercise-type dispatch) and `003-offline-caching-and-sync` (must remain compatible with the offline-take/download path). No unit in this intent is depended on by `005-profile-and-settings` or `006-speak-check-exercise-type`.
