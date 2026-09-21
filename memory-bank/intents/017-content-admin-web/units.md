---
intent: 017-content-admin-web
phase: inception
status: units-decomposed
updated: '2026-09-22T10:00:00Z'
---

# Content Admin Web - Unit Decomposition

## Units Overview

There are two units, split backend-service + frontend-UI like every earlier
intent. The seam is the `/admin/*` HTTP contract. The web unit needs the real
endpoints and error shapes before it can build forms against them.

Unlike an exercise-type intent, **both** units are large. The backend adds a
whole API surface, an authorization rule and an external integration. The web
unit is a new application. Each unit is therefore spread across several bolts.

### Unit 1: 001-content-admin-api

**Description**: The backend half. It adds admin authorization, the admin
content API with type-aware validation and guarded deletes, insert-only seeds,
audio presigning and link checking, and a vocabulary API.

**Requirements**: FR-1 (server), FR-2, FR-3, FR-4 (server validation), FR-5
(server), FR-6, FR-8 (server)

**Deliverables**:
- `require_admin` dependency backed by `ADMIN_EMAILS`, failing closed when it
  is unset; the verified email kept per user or session (see finding 1 in
  `system-context.md`)
- Seeds made insert-only
- `/admin/courses/...` tree read, CRUD and reorder endpoints for sections,
  skills, lessons and exercises
- Delete guard that counts learner history before deleting
- Exercise writes validated through the existing domain value objects
  (`422` naming the field)
- `POST /admin/audio/uploads` → presigned PUT; `POST /admin/audio/links` →
  checked https link
- Audit log line per admin write
- Vocabulary list/update endpoints (Could)

**Dependencies**:
- Depends on: none (extends existing backend in place)
- Depended by: `002-content-admin-web`

**Estimated Complexity**: L

### Unit 2: 002-content-admin-web

**Description**: The new Vite + React + TypeScript admin site in `admin/`,
deployed as its own Vercel project.

**Requirements**: FR-1 (client), FR-2, FR-3, FR-4 (forms), FR-5 (record,
upload, link UI), FR-7, FR-8 (client)

**Deliverables**:
- App scaffold, API client, Google sign-in, not-authorised screen
- Content tree browser with create/edit/reorder/delete
- One editor form per exercise type
- Audio panel: record (MediaRecorder), upload a file, paste a link, play
- Exercise preview (Should)
- Vocabulary screen (Could)

**Dependencies**:
- Depends on: `001-content-admin-api`
- Depended by: none

**Estimated Complexity**: L

## Unit Dependency Graph

```text
[001-content-admin-api] ──> [002-content-admin-web]
```

Within the units the bolts interleave, so there is something usable early:

```text
034 auth+seed ─> 035 content API ─> 037 web shell+tree ─> 038 exercise editors
                        └─> 036 audio API ─────────────────> 039 audio UI
                                                     040 vocabulary (Could, both sides)
```

## Execution Order

1. `034-admin-api-foundation`: admin authorization, insert-only seeds
2. `035-admin-content-api`: tree, CRUD, reorder, delete guard, validation
3. `036-admin-audio-api`: presign, link check
4. `037-admin-web-shell`: scaffold, sign-in, tree browsing and editing
5. `038-admin-exercise-editors`: six editors and preview
6. `039-admin-audio-ui`: record / upload / link
7. `040-admin-vocabulary`: Could; both sides in one bolt

## Note on Insert-Only Seeds Going First

FR-6 is in the **first** bolt on purpose. The day the admin tool can write,
any seed run would erase its work. Making the seed insert-only before any
admin write exists closes that window instead of racing it.

## Note on Validation

There is deliberately no "admin validation" layer. The rules for what makes
an exercise valid already exist in the domain value objects and the
repository's JSON reconstruction. The admin API builds those same objects and
lets them refuse bad input. A second copy of the rules would drift, and a
drifted copy is exactly how the app ends up served content it cannot render.
