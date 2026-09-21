---
unit: 001-content-admin-api
intent: 017-content-admin-web
phase: inception
status: stories-defined
created: '2026-09-22T10:00:00Z'
updated: '2026-09-22T10:00:00Z'
---

# Unit Brief: Content Admin API

## Purpose

Give the FastAPI backend an admin-only API for managing lesson content and
audio. The database becomes the source of truth for content, and no content
the app cannot render can ever be saved.

## Scope

### In Scope
- `require_admin` (the `ADMIN_EMAILS` allow-list, failing closed when unset),
  keeping the verified email, and CORS for the admin origin
- Insert-only seeds (`seed_content` and its three callers)
- `/admin/*` tree read, CRUD and reorder for sections, skills, lessons and
  exercises; editing course titles
- A delete guard driven by learner history
- Exercise write validation through the existing domain value objects
- R2 presigned uploads and a checked audio-link endpoint
- An audit log line per admin write
- Vocabulary list/update (Could)

### Out of Scope
- Any learner endpoint or its behaviour
- Creating or deleting courses
- Drafts, versioning, undo
- Transcoding audio

---

## Assigned Requirements

| FR | Requirement | Priority |
|----|-------------|----------|
| FR-1 | Admin sign-in and authorization (server) | Must |
| FR-2 | Browse the content tree (API) | Must |
| FR-3 | Create, edit, reorder and delete content (API) | Must |
| FR-4 | Exercise validation (server) | Must |
| FR-5 | Audio: record, upload or link (server) | Must |
| FR-6 | Seed becomes insert-only | Must |
| FR-8 | Vocabulary management (API) | Could |

---

## Domain Concepts

### Key Entities
| Entity | Description |
|--------|-------------|
| Admin | A signed-in user whose verified email is in `ADMIN_EMAILS`. There is no new aggregate; this is a rule over `User` |
| Content node | Existing `Course`, `Category`, `Skill`, `Lesson` and `Exercise` rows |
| Audio object | A key in bucket `ethio-lang`, public at `AUDIO_BASE_URL` + key |

### Key Operations
| Operation | Inputs | Outputs |
|-----------|--------|---------|
| Authorize admin | session token | admin email or `401`/`403` |
| Reorder children | parent id, full ordered id list | new order, or `422` |
| Guarded delete | node id, `confirm` | deleted, or `409` with counts |
| Validate exercise | type, prompt, content, answer_key | domain exercise, or `422` naming the field |
| Presign upload | exercise id, content type, size | PUT URL, key, public URL |
| Check link | https URL | accepted URL, or `422` with the reason |

---

## Story Summary

| Story | Priority | Bolt |
|-------|----------|------|
| 001-admin-authorization | Must | 034 |
| 002-seed-insert-only | Must | 034 |
| 003-content-tree-and-crud-api | Must | 035 |
| 004-exercise-write-validation | Must | 035 |
| 005-audio-upload-and-link-api | Must | 036 |
| 006-vocabulary-api | Could | 040 |

## Dependencies

- Depends on: none
- Depended by: `002-content-admin-web`

## Technical Context

- Read `system-context.md` → "Pre-Construction Findings" before bolt `034`.
  Findings 1 (no email stored), 2 (a single Google audience) and 4 (the seeds
  upsert) each change what the first bolt does.
- Follow the existing layering: domain → `app/application/*_use_cases.py` →
  `app/infrastructure/api/*_routers.py`, with thin routers.
