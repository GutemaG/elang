---
intent: 017-content-admin-web
created: '2026-09-22T09:00:00Z'
completed: null
status: in-progress
---

# Inception Log: content-admin-web

## Overview

**Intent**: A React web admin tool, backed by new admin endpoints on the
FastAPI service, for managing courses, sections, skills, lessons, exercises,
vocabulary and audio without editing seed code or SQL.
**Type**: brown-field (a new front end and admin API over the content schema
from `002-core-lesson-loop`, `009-course-categories` and
`010-multi-language-courses`)
**Created**: 2026-09-22

## Artifacts Created

| Artifact | Status | File |
|----------|--------|------|
| Requirements | ✅ approved (Checkpoint 2) | requirements.md |
| System Context | 📝 awaiting review (Checkpoint 3) | system-context.md |
| Units | 📝 awaiting review | units.md, units/{unit-name}/unit-brief.md |
| Stories | 📝 awaiting review | units/{unit-name}/stories/*.md |
| Bolt Plan | 📝 awaiting review | memory-bank/bolts/034-040 |

## Summary

| Metric | Count |
|--------|-------|
| Functional Requirements | 8 |
| Non-Functional Requirements | 3 areas (security, performance, reliability) |
| Units | 2 |
| Stories | 12 |
| Bolts Planned | 7 (034-040) |

## Units Breakdown

| Unit | Stories | Bolts | Priority |
|------|---------|-------|----------|
| 001-content-admin-api | 6 | 034, 035, 036, 040 (shared) | Must |
| 002-content-admin-web | 6 | 037, 038, 039, 040 (shared) | Must |

## Decision Log

| Date | Decision | Rationale | Approved |
|------|----------|-----------|----------|
| 2026-09-22 | The front end is React, as a separate app in this repo | User request: managing tutorials needs a web tool; React only for now | Yes |
| 2026-09-22 | The learner Flutter app is out of scope | The admin tool writes the same tables the app already reads | Yes |
| 2026-09-22 | The database is the source of truth; seeds become insert-only | Otherwise every seed run overwrites admin edits (Checkpoint 1) | Yes |
| 2026-09-22 | Admins are the emails in `ADMIN_EMAILS` | No migration; access changes by editing one Vercel variable (Checkpoint 1) | Yes |
| 2026-09-22 | Vite + React + TypeScript in `admin/`, its own Vercel project | Independent deploys; plain CSS keeps the bundle small (Checkpoint 1) | Yes |
| 2026-09-22 | Admin edits go live immediately | One to three careful admins; server validation blocks broken exercises (Checkpoint 1) | Yes |
| 2026-09-22 | Audio uploads use presigned PUT URLs to R2 | Avoids Vercel's 4.5 MB body limit; R2 keys stay on the backend | Default |
| 2026-09-22 | Audio can be recorded in the browser, uploaded, or linked by URL | Admins record directly or reuse hosted clips (Checkpoint 2 feedback) | Yes |
| 2026-09-22 | Keep the local Audio Lab until FR-5 ships | Still the only way to hear real clips locally | Default |

## Pre-Inception Findings

- The seeds (`seed_lesson_content.py`, `seed_course_content.py`) upsert every
  row by uuid5 content id, so any edit made outside the seed is overwritten on
  the next run. The source-of-truth question must be settled before units.
- `tech-stack.md` says there is no admin/content-manager role; this intent
  changes that on the backend.
- R2 bucket `ethio-lang` holds four clips with Amharic keys at the bucket
  root. Its public dev URL currently returns 404, which must be fixed before
  FR-5 can be verified.

| 2026-09-22 | Seeds go insert-only in the first bolt, before any admin write exists | Closes the window in which a seed run erases admin edits | Yes |
| 2026-09-22 | Validation reuses the domain value objects; no admin-only rule set | A second copy would drift and let the app be served content it cannot render | Yes |

## Scope Changes

| Date | Change | Reason | Impact |
|------|--------|--------|--------|
| 2026-09-22 | FR-5 widened from upload-only to record, upload or link | User feedback at Checkpoint 2 | Browser recording moved into scope |

## Ready for Construction

**Checklist**:
- [ ] All requirements documented
- [ ] System context defined
- [ ] Units decomposed
- [ ] Stories created for all units
- [ ] Bolts planned
- [ ] Human review complete

## Next Steps

1. Answer the Checkpoint 1 open questions in requirements.md
2. Approve requirements (Checkpoint 2)
3. Review system context, units, stories and bolts (Checkpoint 3)
4. Start construction with bolt `034-admin-api-foundation`
