---
intent: 006-speak-check-exercise-type
created: '2026-09-17T04:00:00Z'
completed: null
status: in-progress
---

# Inception Log: speak-check-exercise-type

## Overview

**Intent**: Add the `speak_check` exercise type (5th and final originally-planned exercise type), using Google Cloud Speech-to-Text.
**Type**: brown-field (extends `002-core-lesson-loop`'s exercise-type dispatch) with a new external dependency
**Created**: 2026-09-17

## Artifacts Created

| Artifact | Status | File |
|----------|--------|------|
| Requirements | 🔲 draft | requirements.md |
| System Context | 🔲 | system-context.md |
| Units | 🔲 | units/{unit-name}/unit-brief.md |
| Stories | 🔲 | units/{unit-name}/stories/*.md |
| Bolt Plan | 🔲 | memory-bank/bolts/bolt-*.md |

## Summary

| Metric | Count |
|--------|-------|
| Functional Requirements | TBD |
| Non-Functional Requirements | TBD |
| Units | TBD |
| Stories | TBD |
| Bolts Planned | TBD |

## Decision Log

| Date | Decision | Rationale | Approved |
|------|----------|-----------|----------|
| 2026-09-17 | Sequenced last of the 3 gap-closing intents, after 004-match-pairs-exercise-type and 005-profile-and-settings | Needs Google Cloud Speech-to-Text (external dependency, bigger lift) per user's explicit instruction | Yes |

## Scope Changes

| Date | Change | Reason | Impact |
|------|--------|--------|--------|

## Ready for Construction

**Checklist**:
- [ ] All requirements documented
- [ ] System context defined
- [ ] Units decomposed
- [ ] Stories created for all units
- [ ] Bolts planned
- [ ] Human review complete

## Next Steps

1. Checkpoint 1: clarifying questions (requirements skill)
2. Checkpoint 2: requirements review
3. Auto-continue: context → units → stories → bolt-plan → review (Checkpoint 3)
4. Checkpoint 4: ready for Construction

## Dependencies

Depends on `002-core-lesson-loop` (extends its exercise-type dispatch). New external dependency: Google Cloud Speech-to-Text. Sequenced after `004-match-pairs-exercise-type` and `005-profile-and-settings` by user preference, not technical necessity.
