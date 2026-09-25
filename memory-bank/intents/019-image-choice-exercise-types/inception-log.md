---
intent: 019-image-choice-exercise-types
created: '2026-09-24T21:22:18Z'
completed: '2026-09-25T06:23:36Z'
status: complete
---

# Inception Log: image-choice-exercise-types

## Overview

**Intent:** Add image-choice and audio-image-choice question types across
the backend, the admin site, offline packs and the mobile lesson.
**Type:** brown-field (extends the exercise-type dispatch, following
`004`, `015` and `016`)
**Created:** 2026-09-24
**Requested:** by the owner, 2026-09-24, at the bolt 045 Plan checkpoint.
It was planned to follow bolt 045 so the picture tile builds on the
finished lesson screen.

## Artifacts Created

| Artifact | Status | File |
|----------|--------|------|
| Requirements | ✅ approved (Checkpoint 2) | requirements.md |
| System Context | ✅ | system-context.md |
| Units | ✅ | units.md, units/{unit-name}/unit-brief.md |
| Stories | ✅ | units/{unit-name}/stories/*.md |
| Bolt Plan | ✅ approved (Checkpoint 3) | memory-bank/bolts/050-054 |

## Summary

| Metric | Count |
|--------|-------|
| Functional Requirements | 10 |
| Non-Functional Requirements | 5 groups (performance, security, accessibility, reliability, compatibility) |
| Units | 3 |
| Stories | 10 |
| Bolts Planned | 5 (050-054) |

## Units Breakdown

| Unit | Stories | Bolts | Priority |
|------|---------|-------|----------|
| 001-image-choice-service | 3 | 050, 051 | Must |
| 002-image-choice-admin | 2 | 052 | Must |
| 003-image-choice-ui | 5 | 053, 054 | Must (story 004 Should) |

## Decision Log

| Date | Decision | Rationale | Approved |
|------|----------|-----------|----------|
| 2026-09-24 | Separate intent, not part of bolt 045 | Needs backend, storage, admin and offline changes beyond a UI bolt | Yes (bolt 045 Plan checkpoint) |
| 2026-09-24 | Audio in these questions plays by itself on first appearance | Owner's rule for every question with audio, built in bolt 045 | Yes |
| 2026-09-24 | Checkpoint 1: 1b 2a 3a 4a 5a 6c 7a | Per-question uploads; 2-4 unlabelled pictures with alt text; audio question shows no text; offline packs carry pictures; 512 px WebP/JPEG shrunk in the browser; Claude picks and downloads free-licensed sample pictures; practice includes them | Yes |
| 2026-09-25 | Requirements approved | Owner: "lets continue" at Checkpoint 2 | Yes |
| 2026-09-25 | Three units: service, admin site, app | The same seams as 017 and the earlier exercise types; admin and app each depend only on the service | Yes (Checkpoint 3) |
| 2026-09-25 | Sample pictures committed outside `backend/media` and seeded locally only, like the Audio Lab | `backend/media` is git-ignored; production waits for the owner | Yes (Checkpoint 3) |
| 2026-09-25 | Each sample question gets its own vocabulary word | Practice shows the first question by id per word (finding 1) | Yes (Checkpoint 3) |
| 2026-09-25 | Picture credits via a new "Licences" entry and Flutter's licence page | The app has no licences page today (finding 2) | Yes (Checkpoint 3) |
| 2026-09-25 | Artifacts approved | Checkpoint 3: "1" | Yes |

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

## Next Steps

1. Begin Construction with unit `001-image-choice-service`, bolt `050-image-choice-service`
2. Execute: `/specsmd-construction-agent --unit="001-image-choice-service" --bolt-id="050-image-choice-service"`

## Dependencies

- Uses the question kit from intent 018 (bolts 044 and 045, complete).
- Bolt 054's Licences entry goes on whichever settings screen exists then; bolt 049 moves settings onto the library.
- Neon migration and seeding, production R2 uploads and any R2 CORS change wait for the owner's go-ahead.
