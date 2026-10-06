---
intent: 026-lesson-path-nodes
created: 2026-10-06T08:56:00Z
completed: 2026-10-06T08:58:00Z
status: complete
---

# Inception Log: 026-lesson-path-nodes

## Overview

**Intent**: One bubble per lesson on the home path, instead of one per
skill with "Lesson 1 of 3".
**Type**: brown-field
**Created**: 2026-10-06T08:56:00Z

## Artifacts Created

| Artifact | Status | File |
|----------|--------|------|
| Requirements | ✅ | requirements.md |
| System Context | ✅ | requirements.md (held there, as in 021-025) |
| Units | ✅ | units.md, units/*/unit-brief.md |
| Stories | ✅ | in each unit brief |
| Bolt Plan | ✅ | memory-bank/bolts/087-088 |

## Summary

| Metric | Count |
|--------|-------|
| Functional Requirements | 5 |
| Non-Functional Requirements | 3 |
| Units | 2 |
| Stories | 5 |
| Bolts Planned | 2 |

## Units Breakdown

| Unit | Stories | Bolts | Priority |
|------|---------|-------|----------|
| 001-path-lessons-service | 1 | 1 | Must |
| 002-path-lessons-app | 4 | 1 | Must |

## Decision Log

| Date | Decision | Rationale | Approved |
|------|----------|-----------|----------|
| 2026-10-06T08:56:00Z | One bubble per lesson, with the skill's title as a label | "Lesson 1 of 3" in one bubble is confusing; the user chose this over one skill per lesson in the content | Yes |
| 2026-10-06T08:56:00Z | Progress, crowns and unlocking stay per skill | No migration, nothing lost for existing learners | Yes |
| 2026-10-06T08:56:00Z | Lessons open in order within a skill | Same rule the path already uses for skills | Yes (recommended) |
| 2026-10-06T08:56:00Z | Crown on the skill's label | Crowns are earned per skill | Yes (recommended) |
| 2026-10-06T08:56:00Z | The field is additive; an old app keeps one bubble per skill | Learners update at different times | Yes |

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
- [x] Human review complete (the user asked to go on with the recommended options)

## Next Steps

1. Begin construction with unit `001-path-lessons-service`, bolt 087
2. Then `002-path-lessons-app`, bolt 088

## Dependencies

Builds on 002-core-lesson-loop (skill tree), 014-path-node-types,
020-dashboard-section-header.

087 → 088.
