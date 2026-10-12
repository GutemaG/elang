---
intent: 027-generated-voice-audio
created: 2026-10-12T09:30:00Z
completed: 2026-10-12T18:35:00Z
status: complete
---

# Inception Log: 027-generated-voice-audio

## Overview

**Intent**: Add a Generate tab, next to Record, Upload and Link, that
turns Amharic or Afaan Oromo text into a clip with Addis AI. The voice
and speed are set per language on a new Voices page. The clip is trimmed
in the clip editor before it is stored.
**Type**: brown-field
**Created**: 2026-10-12T09:30:00Z

## Artifacts Created

| Artifact | Status | File |
|----------|--------|------|
| Requirements | ✅ | requirements.md |
| System Context | ✅ | requirements.md, held there as in 021–026 |
| Units | ✅ | units.md, units/*/unit-brief.md |
| Stories | ✅ | in each unit brief (001–021) |
| Bolt Plan | ✅ | memory-bank/bolts/089–099 |

## Summary

| Metric | Count |
|--------|-------|
| Functional Requirements | 21 |
| Non-Functional Requirements | 4 |
| Units | 6 |
| Stories | 21 |
| Bolts Planned | 11 |

## Units Breakdown

| Unit | Stories | Bolts | Priority |
|------|---------|-------|----------|
| 001-voice-settings-service | 3 | 2 (089, 090) | Must |
| 002-addis-voice-client | 4 | 2 (091, 092) | Must |
| 003-voice-generation-api | 4 | 1 (093) | Must |
| 004-voices-admin-page | 4 | 2 (094, 095) | Must |
| 005-generate-tab | 5 | 3 (096, 097, 098) | Must |
| 006-generated-clip-label | 1 | 1 (099) | Could |

## Decision Log

| Date | Decision | Rationale | Approved |
|------|----------|-----------|----------|
| 2026-10-12T09:30:00Z | Default voices: Amharic Yohanes (`am-yohanes-calm`) and Loza (`am-loza`); Afaan Oromo Diriba (`om-diriba`) and Obse (`om-obse`) | Owner's choice | Yes |
| 2026-10-12T09:30:00Z | Generate is a fourth tab in AudioField, and the clip goes through the existing ClipEditor before upload | Reuses silence trim, handles, effects and storage | Yes |
| 2026-10-12T09:30:00Z | Voices and speed are admin settings stored on the server | Owner wants control from the admin site | Yes |
| 2026-10-12T09:50:00Z | Default speed 50; the Male/Female choice is remembered per browser | Owner asked to continue; both can be changed later | Yes |
| 2026-10-12T09:50:00Z | Generation returns mp3 bytes and stores nothing; "Use this clip" stores it through the existing uploader | One storage path; no orphan files from takes the admin doesn't keep | Yes |
| 2026-10-12T09:55:00Z | Small units and bolts (6 units, 11 bolts) | Owner asked for small units and bolts | Yes |

## Scope Changes

| Date | Change | Reason | Impact |
|------|--------|--------|--------|
| 2026-10-12T09:50:00Z | Requirements expanded from 7 to 21 FRs | Owner asked for detailed requirements | +6 units, +11 bolts |

## Ready for Construction

**Checklist**:
- [x] All requirements documented
- [x] System context defined
- [x] Units decomposed
- [x] Stories created for all units
- [x] Bolts planned
- [x] Human review complete

## Next Steps

Construction is complete (bolts 089–099, 2026-10-12). Still to do before
production:

1. Replace the Addis key that was shared in chat with a new one.
2. With the owner's go-ahead, set `ADDIS_API_KEY` on Vercel and migrate
   Neon to `a3f7c2e9b1d4`.
3. Confirm that Addis AI's terms allow generated audio in a commercial
   app.

## Dependencies

- **Order:** 089 → 090 → 091 → 092 → 093, then 094 → 095 and
  096 → 097 → 098 → 099.
- **Builds on:** 017-content-admin-web (AudioField, ClipEditor, uploads)
  and 025-curriculum-workspace (Workbook item recordings).
