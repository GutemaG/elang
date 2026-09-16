---
unit: 001-lesson-service
intent: 002-core-lesson-loop
created: 2026-09-16T09:00:00Z
last_updated: 2026-09-16T07:36:35Z
---

# Construction Log: Lesson Service

## Original Plan

**From Inception**: 2 bolts planned
**Planned Date**: 2026-09-15

| Bolt ID | Stories | Type |
|---------|---------|------|
| 004-lesson-content-service | 001, 005 | ddd-construction-bolt |
| 005-lesson-engagement-service | 002, 003, 004 | ddd-construction-bolt |

## Replanning History

| Date | Action | Change | Reason | Approved |
|------|--------|--------|--------|----------|

## Current Bolt Structure

| Bolt ID | Stories | Status | Changed |
|---------|---------|--------|---------|
| 004-lesson-content-service | 001, 005 | ✅ complete | - |
| 005-lesson-engagement-service | 002, 003, 004 | ✅ complete | - |

## Execution History

| Date | Bolt | Event | Details |
|------|------|-------|---------|
| 2026-09-16T09:00:00Z | 004-lesson-content-service | started | Stage 1: Domain Model |
| 2026-09-16T09:05:00Z | 004-lesson-content-service | stage-complete | Domain Model → Technical Design |
| 2026-09-16T09:20:00Z | 004-lesson-content-service | stage-complete | Technical Design → ADR Analysis |
| 2026-09-16T09:25:00Z | 004-lesson-content-service | stage-complete | ADR Analysis → Implement (ADR-3 polymorphic exercises table, ADR-4 server-side-only answer keys) |
| 2026-09-16T10:15:00Z | 004-lesson-content-service | stage-complete | Implement → Test |
| 2026-09-16T11:00:00Z | 004-lesson-content-service | stage-complete | Test → done (145/145 tests passing, verified independently 2026-09-16) |
| 2026-09-16T06:47:19Z | 004-lesson-content-service | completed | All 5 stages done; bolt-complete.cjs run after the construction agent hit a session rate-limit before running it itself |
| 2026-09-16T12:00:00Z | 005-lesson-engagement-service | started | Stage 1: Domain Model |
| 2026-09-16T12:05:00Z | 005-lesson-engagement-service | stage-complete | Domain Model → Technical Design (identified ADR-4/NFR conflict, carried into Stage 2) |
| 2026-09-16T12:20:00Z | 005-lesson-engagement-service | stage-complete | Technical Design → ADR Analysis |
| 2026-09-16T12:30:00Z | 005-lesson-engagement-service | stage-complete | ADR Analysis → Implement (ADR-5 supersedes ADR-4's answer-key clause; also amended bolt 004's schemas/tests and bolt 006's Flutter `LessonApi`/`LessonController`) |
| 2026-09-16T13:45:00Z | 005-lesson-engagement-service | stage-complete | Implement → Test |
| 2026-09-16T14:00:00Z | 005-lesson-engagement-service | completed | All 5 stages done; 215/215 backend tests + 66/66 Flutter tests passing, `bolt-complete.cjs` run |

## Execution Summary

| Metric | Value |
|--------|-------|
| Original bolts planned | 2 |
| Current bolt count | 2 |
| Bolts completed | 2 |
| Bolts in progress | 0 |
| Bolts remaining | 0 |
| Replanning events | 0 |

## Notes

This was the unit's first bolt, run unattended (no human present) per the Construction Agent's process note — each DDD stage checkpoint was treated as a self-review gate rather than a literal pause; engineering-judgment decisions normally raised to a human are documented explicitly in the stage artifacts instead (see `ddd-02-technical-design.md`'s design-decision notes and the two ADRs).

The construction agent hit an API session rate-limit and was terminated mid-execution right after writing the test report, before it could update this log or run the completion script. All artifacts (domain model, technical design, 2 ADRs, implementation notes, test report) were already written to disk. Before marking the bolt complete, the full backend test suite was re-run independently (`uv run pytest -q` from `backend/`) and confirmed 145/145 passing, matching the agent's self-reported test report exactly. `node .specsmd/aidlc/scripts/bolt-complete.cjs 004-lesson-content-service` was then run to close out the bolt/stories per the hard-gate process (this required a one-time local install of the script's missing `fs-extra`/`js-yaml` dependencies in `.specsmd/aidlc/scripts/`, which were not present in the repo).

**Bolt `005-lesson-engagement-service`** (this unit's second and final bolt) surfaced a real architectural conflict during Domain Model/Technical Design: bolt `004`'s ADR-4 (server-side-only grading via a per-exercise `SubmitExerciseAnswer` call) directly contradicted `requirements.md`'s "no network call per exercise" Performance NFR — a conflict bolt `004` itself never checked for. Resolved via ADR-5 (supersedes ADR-4's answer-key clause): grading moves client-side; the account ledger stays server-bounded (beans/XP can't exceed what the account's real beans would allow) rather than fully re-derived, and completion is idempotent on a client-generated `attempt_id`. This required amending two already-complete artifacts in the same session: bolt `004`'s lesson-content schema/router/tests (added `correct_choice_id`/`correct_sequence` fields, flipped the "answer key never leaked" tests to assert presence instead) and bolt `006`'s Flutter `LessonApi`/`LessonController` (added the `attemptId` parameter). Both bolts' full test suites were re-run after the amendments (backend 215/215, Flutter 66/66) rather than assumed unaffected. Also mid-session, per an explicit user request, a "missed exercise loops back into the queue" mechanic was added to `006`'s `LessonController` before this bolt started — unrelated to bolt 005's scope but confirmed still passing throughout.

**Errata (found 2026-09-17, during `010-offline-caching-and-sync-ui`'s physical-device verification)**: bolt `004`'s seeded listening-exercise `audio_url` used a non-resolving placeholder host (`r2-placeholder.buna.dev`) — flagged in that bolt's own test report as "before any real device/QA testing," and that's exactly when it surfaced. Once `010` started actually downloading these URLs for offline caching, every download failed outright on a real device (`SocketException: Failed host lookup`). Fixed by swapping `seed_lesson_content.py`'s `_audio_url()` to a small, genuinely resolvable public placeholder MP3 (`https://www.kozco.com/tech/piano2-CoolEdit.mp3`) and re-running the idempotent seed script — a pure data update, no schema change. One backend test (`test_seed_lesson_content.py::test_listening_exercises_include_a_documented_placeholder_audio_url`) asserted the old URL and was updated to match; full backend suite (242/242) re-run and passing.
