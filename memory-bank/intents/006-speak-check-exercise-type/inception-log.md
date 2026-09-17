---
intent: 006-speak-check-exercise-type
created: '2026-09-17T04:00:00Z'
completed: '2026-09-17T15:10:00Z'
status: complete
---

# Inception Log: speak-check-exercise-type

## Overview

**Intent**: Add the `speak_check` exercise type (5th and final originally-planned exercise type), using Google Cloud Speech-to-Text.
**Type**: brown-field (extends `002-core-lesson-loop`'s exercise-type dispatch) with a new external dependency
**Created**: 2026-09-17

## Artifacts Created

| Artifact | Status | File |
|----------|--------|------|
| Requirements | ✅ | requirements.md |
| System Context | ✅ | system-context.md |
| Units | ✅ | units/{unit-name}/unit-brief.md |
| Stories | ✅ | units/{unit-name}/stories/*.md |
| Bolt Plan | ✅ | memory-bank/bolts/015-speak-check-service/bolt.md, memory-bank/bolts/016-speak-check-ui/bolt.md |

## Summary

| Metric | Count |
|--------|-------|
| Functional Requirements | 6 |
| Non-Functional Requirements | 3 (Security & Privacy, Reliability, Cost — all new-to-this-codebase concerns) |
| Units | 2 |
| Stories | 4 |
| Bolts Planned | 2 |

## Units Breakdown

| Unit | Stories | Bolts | Priority |
|------|---------|-------|----------|
| 001-speak-check-service | 2 | 1 (015-speak-check-service) | Must |
| 002-speak-check-ui | 2 | 1 (016-speak-check-ui) | Must |

## Decision Log

| Date | Decision | Rationale | Approved |
|------|----------|-----------|----------|
| 2026-09-17 | Sequenced last of the 3 gap-closing intents, after 004-match-pairs-exercise-type and 005-profile-and-settings | Needs Google Cloud Speech-to-Text (external dependency, bigger lift) per user's explicit instruction | Yes |
| 2026-09-17 | Full Inception produced now; Construction explicitly not started for this intent | Google Cloud Speech-to-Text is not yet provisioned — user's explicit Checkpoint 1 direction: document the requirement, don't implement/defer it | Yes |
| 2026-09-17 | speak_check exercises excluded from downloadable offline packs entirely (not a record-now-score-later queue) | User's explicit Checkpoint 1 choice — simplest, safest, given grading fundamentally requires network | Yes |
| 2026-09-17 | Fuzzy similarity threshold, unlimited retries | User's explicit Checkpoint 1 choice — matches this app's low-stakes, practice-oriented tone | Yes |
| 2026-09-17 | Grading stays server-side for this exercise type (FR-2), a deliberate deviation from ADR-5 | No client-side speech-recognition capability exists in this stack; flagged for its own ADR at Construction rather than silently exempted | Yes |
| 2026-09-17 | 2 units mirroring 004's backend/frontend split, but with grading on the backend unit (unlike 004, where ADR-5 moved grading to frontend) | Consistent unit-decomposition pattern, but grading assignment follows this intent's actual architecture, not a copy-paste of 004's | Yes |

## Scope Changes

| Date | Change | Reason | Impact |
|------|--------|--------|--------|

## Ready for Construction

**Checklist**:
- [x] All requirements documented
- [x] System context defined
- [x] Units decomposed
- [x] Stories created for all units
- [x] Bolts planned
- [x] Human review complete

**⛔ Construction is explicitly not started for this intent.** Both bolts (`015-speak-check-service`, `016-speak-check-ui`) are marked `status: planned` with a prominent "DO NOT START" notice, blocked on Google Cloud Speech-to-Text provisioning (external, not a code dependency).

## Next Steps

1. **Provision Google Cloud Speech-to-Text** (account, project, billing, API credentials) — a precondition for Construction, not for Inception.
2. Once provisioned, begin Construction on `015-speak-check-service`.
3. Then `016-speak-check-ui`.

## Dependencies

Depends on `002-core-lesson-loop` (extends its exercise-type dispatch). New external dependency: Google Cloud Speech-to-Text — **not yet provisioned**. Sequenced after `004-match-pairs-exercise-type` and `005-profile-and-settings` (both now complete) by user preference, not technical necessity.
