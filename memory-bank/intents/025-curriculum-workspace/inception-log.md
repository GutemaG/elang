---
intent: 025-curriculum-workspace
created: 2026-10-05T10:00:00Z
completed: 2026-10-05T10:40:00Z
status: complete
---

# Inception Log: 025-curriculum-workspace

## Overview

**Intent**: Prepare a course's curriculum in the admin site: load it from
the curriculum Excel file, review and record each word and sentence there,
and publish a lesson into the app when it is ready.
**Type**: brown-field
**Created**: 2026-10-05T10:00:00Z

## Artifacts Created

| Artifact | Status | File |
|----------|--------|------|
| Requirements | ✅ | requirements.md |
| System Context | ✅ | requirements.md (held there, as in 021-024) |
| Units | ✅ | units.md, units/*/unit-brief.md |
| Stories | ✅ | in each unit brief |
| Bolt Plan | ✅ | memory-bank/bolts/082-086 |

## Summary

| Metric | Count |
|--------|-------|
| Functional Requirements | 10 |
| Non-Functional Requirements | 4 |
| Units | 2 |
| Stories | 15 |
| Bolts Planned | 5 |

## Units Breakdown

| Unit | Stories | Bolts | Priority |
|------|---------|-------|----------|
| 001-curriculum-service | 6 | 2 | Must |
| 002-curriculum-admin | 9 | 3 | Must |

## Decision Log

| Date | Decision | Rationale | Approved |
|------|----------|-----------|----------|
| 2026-10-05T10:00:00Z | Move curriculum collection from the spreadsheet / Google Sheets into the admin | Collecting text in a sheet and recording separately is two processes and hard to keep in step | Yes |
| 2026-10-05T10:00:00Z | The Excel file is the first load only; the admin is the source of truth afterwards | Avoids two master copies | Yes |
| 2026-10-05T10:20:00Z | Admins only for now; no reviewer role | Admin accounts will move from the env variable to a DB table in a later intent, and a reviewer role can follow | Yes |
| 2026-10-05T10:20:00Z | Published lessons sit beside existing ones | Hand-made content is kept until deleted by hand | Yes |
| 2026-10-05T10:20:00Z | Generated exercises can be edited; regenerating keeps edits | The rules will not always be right | Yes |
| 2026-10-05T10:20:00Z | Publish one lesson at a time | Lessons reach learners as soon as each is ready | Yes |
| 2026-10-05T10:30:00Z | Exercises are built in the admin with the CSV import's rules; the backend stores and publishes | Generated and imported lessons match; one set of rules | Yes |

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

1. Artifacts reviewed and approved (2026-10-05T10:40:00Z)
2. Begin construction with unit `001-curriculum-service`, bolt 082
3. Execute: `/specsmd-construction-agent --unit="001-curriculum-service" --bolt-id="082-curriculum-store"`

## Dependencies

Builds on 017-content-admin-web (admin site, lesson import, recorder).

082 → 083 → 084; 082 → 085; 084 + 085 → 086.
