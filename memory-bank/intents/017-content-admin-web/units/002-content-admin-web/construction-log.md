---
unit: 002-content-admin-web
intent: 017-content-admin-web
created: '2026-09-22T15:19:04Z'
last_updated: '2026-09-28T20:43:39Z'
---

# Construction Log: content-admin-web

## Original Plan

**From Inception**: 4 bolts planned (one shared with `001-content-admin-api`)
**Planned Date**: 2026-09-22

| Bolt ID | Stories | Type |
|---------|---------|------|
| 037-admin-web-shell | 001-admin-web-scaffold-and-sign-in, 002-content-tree-browser-and-editing | simple-construction-bolt |
| 038-admin-exercise-editors | 003-exercise-editors, 005-exercise-preview | simple-construction-bolt |
| 039-admin-audio-ui | 004-audio-record-upload-link | simple-construction-bolt |
| 040-admin-vocabulary | 006-vocabulary-screen (+ api 006-vocabulary-api) | simple-construction-bolt |
| 055-admin-tree-polish | none (criteria in its implementation-plan.md) | simple-construction-bolt |
| 056-exercise-import | none (criteria in its implementation-plan.md) | simple-construction-bolt |

## Replanning History

| Date | Action | Change | Reason | Approved |
|------|--------|--------|--------|----------|
| 2026-09-28 | Added bolt 055 | Drag-and-drop reordering brought into scope; picture descriptions made optional; the tree remembers what was open | Feedback from using the admin site | Yes |
| 2026-09-28 | Added bolt 056 | Import a lesson's exercises from CSV or JSON, and export them; one new API endpoint (unit 001) | Adding exercises one at a time is slow | Yes |

## Execution Log

- **2026-09-22T15:19:04Z**: 037-admin-web-shell started - Stage 1: plan
- **2026-09-22T16:05:00Z**: 037-admin-web-shell stage-complete - plan → implement
- **2026-09-22T17:00:00Z**: 037-admin-web-shell stage-complete - implement (admin/ scaffold, sign-in, content tree)
- **2026-09-22T17:25:00Z**: 037-admin-web-shell stage-complete - test (50 tests, 6 falsification runs)
- **2026-09-22T17:30:00Z**: 037-admin-web-shell completed - stories 001, 002 complete
- **2026-09-24T08:03:32Z**: 038-admin-exercise-editors started - Stage 1: plan
- **2026-09-24T08:11:03Z**: 038-admin-exercise-editors stage-complete - plan → implement
- **2026-09-24T08:36:28Z**: 038-admin-exercise-editors stage-complete - implement → test
- **2026-09-24T08:52:47Z**: 038-admin-exercise-editors completed - stories 003, 005 complete (330 tests, 14 falsification runs)
- **2026-09-24T09:10:00Z**: 039-admin-audio-ui started - Stage 1: plan
- **2026-09-24T09:20:00Z**: 039-admin-audio-ui stage-complete - plan → implement
- **2026-09-24T09:17:00Z**: 039-admin-audio-ui stage-complete - implement → test
- **2026-09-24T09:35:41Z**: 039-admin-audio-ui completed - story 004 complete (395 tests, 18 falsification runs; manual phone check pending)
- **2026-09-28T00:00:00Z**: 040-admin-vocabulary started - Stage 1: plan
- **2026-09-28T14:43:14Z**: 040-admin-vocabulary completed - stories 006-vocabulary-api and 006-vocabulary-screen complete; also fixed the clipped Add exercise type menu (backend 1280 tests, admin suite green; run by the user)
- **2026-09-28T19:41:33Z**: 055-admin-tree-polish started - Stage 1: plan
- **2026-09-28T19:52:00Z**: 055-admin-tree-polish stage-complete - plan → implement
- **2026-09-28T20:11:01Z**: 055-admin-tree-polish stage-complete - implement → test
- **2026-09-28T20:12:44Z**: 055-admin-tree-polish completed - drag to reorder with one Save, optional picture descriptions (admin, API, app), tree keeps open rows and scroll (admin 534, backend 1282 tests)
- **2026-09-28T20:43:39Z**: 056-exercise-import started - Stage 1: plan
- **2026-09-28T20:45:35Z**: 056-exercise-import stage-complete - plan → implement
- **2026-09-28T21:10:25Z**: 056-exercise-import stage-complete - implement → test
- **2026-09-28T21:13:07Z**: 056-exercise-import completed - import a lesson's exercises from CSV or JSON with preview and samples, export to both (admin 612, backend 1299 tests)
