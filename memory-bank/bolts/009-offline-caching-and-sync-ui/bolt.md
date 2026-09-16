---
id: 009-offline-caching-and-sync-ui
unit: 002-offline-caching-and-sync-ui
intent: 003-offline-caching-and-sync
type: simple-construction-bolt
status: complete
stories:
  - 001-download-lesson-packs
  - 002-offline-lesson-taking
created: '2026-09-16T21:00:00Z'
started: '2026-09-16T23:30:00Z'
completed: '2026-09-17T00:30:00Z'
current_stage: null
stages_completed:
  - name: plan
    completed: '2026-09-16T23:30:00Z'
    artifact: implementation-plan.md
  - name: implement
    completed: '2026-09-16T23:50:00Z'
    artifact: implementation-walkthrough.md
  - name: test
    completed: '2026-09-17T00:20:00Z'
    artifact: test-walkthrough.md

requires_bolts:
  - 008-offline-sync-service
enables_bolts:
  - 010-offline-caching-and-sync-ui
requires_units:
  - 001-offline-sync-service
blocks: false

complexity:
  avg_complexity: 2
  avg_uncertainty: 2
  max_dependencies: 2
  testing_scope: 2
---

# Bolt: 009-offline-caching-and-sync-ui

## Overview

First of two bolts for `002-offline-caching-and-sync-ui`. Makes the core offline capability real: a download manager that caches lesson packs (content + audio) locally, and an offline path through `002-core-lesson-loop`'s existing exercise engine so a downloaded lesson plays with zero network calls.

## Objective

Deliver "download a skill, then take its lessons with the device in airplane mode" end-to-end, reusing the existing `LessonController`/exercise screens rather than forking them.

## Stories Included

- **001-download-lesson-packs**: Download and cache lesson packs (content + audio) (Must)
- **002-offline-lesson-taking**: Take a downloaded lesson with zero connectivity (Must)

## Bolt Type

**Type**: Simple Construction Bolt
**Definition**: `.specsmd/aidlc/templates/construction/bolt-types/simple-construction-bolt.md`

## Stages

- ✅ **1. Plan**: Complete → implementation-plan.md
- ✅ **2. Implement**: Complete → implementation-walkthrough.md
- ✅ **3. Test**: Complete → test-walkthrough.md

**Bolt complete.**

## Dependencies

### Requires
- `008-offline-sync-service` (needs the content-version signal to implement the staleness check; can scaffold local storage/download-manager UI against a documented contract before that bolt fully lands, same pattern `002-core-lesson-loop-ui` used)

### Enables
- `010-offline-caching-and-sync-ui` (nothing to sync or indicate status for until offline-taking exists)

## Success Criteria

- [x] A downloaded lesson pack (all 3 exercise types + audio) plays fully offline with correct grading and Beans/XP bookkeeping
- [x] Cached packs survive app restart
- [x] Attempting an un-downloaded lesson while offline shows a clear "download required" state, not a hang or crash

## Notes

Blocked on `008-offline-sync-service` for the version-signal contract, but the local storage schema and download-manager UI can be scaffolded in parallel once that bolt's Technical Design stage documents the response shape — same parallelization pattern used across `001-auth-onboarding` and `002-core-lesson-loop`.
