---
unit: 002-core-lesson-loop-ui
bolt: 007-core-lesson-loop-ui
stage: plan
status: complete
created: 2026-09-16T15:05:00Z
---

# Implementation Plan: Real Backend Integration (007-core-lesson-loop-ui)

## Objective

Replace `FakeLessonApi` with `HttpLessonApi`, a real HTTP-backed `LessonApi` calling `001-lesson-service`'s now-complete endpoints (bolts 004/005) — same seam pattern as `001-auth-onboarding`'s `HttpAuthApi`/bolt 003.

## Approach

`HttpLessonApi` mirrors `HttpAuthApi`'s shape exactly: constructor-injected `http.Client`/`baseUrl`, plus (new, since `LessonApi`'s calls are all authenticated) a `SessionRepository` read fresh on every call to attach `Authorization: Bearer {token}` — the session token isn't known at `LessonDependencies` construction time (app start, pre-sign-in), so it can't be baked in once like `baseUrl` is.

`LessonApi` has no sealed success/failure result type (unlike `AuthApi`) for `getSkillTree`/`startLesson`/`getBeansStatus`/`completeLesson` — errors surface as thrown exceptions, a new `LessonApiException` (message + optional `errorCode`). This requires **no screen changes** for `getSkillTree`/`startLesson`: both already render via `FutureBuilder` with a generic `snapshot.hasError` branch (bolt 006). `refillBeansWithAmole` keeps returning its existing sealed `RefillResult` for the one specific, expected failure (`insufficient_amole` → `RefillFailure`); anything else still throws.

## Checkpoint Decisions (self-review, unattended)

### Decision 1: Two real response-shape gaps found between the fake and the real backend (per story 005's explicit anticipation)

1. **`skills[].lesson_id` doesn't exist in `001-lesson-service`'s skill-tree response.** The fake modeled "one representative lesson per skill node" as a deliberate simplification (`unit-brief.md`'s explicit note); the real backend's seed curriculum has 2 lessons per skill with no "current lesson" concept server-side (a lesson's completion only contributes to a skill-wide cycle-completion *set*, order-independent). **Fix**: extend `GET /skill-tree` (bolt 005's own extension of bolt 004's endpoint, amended again here) to include `lesson_id` per skill — the first lesson (by `order_index`) not yet in that skill's `completed_lesson_ids_this_cycle`, falling back to the first lesson if the cycle set already covers everything. Computed in the `get_skill_tree` use case (application layer), not the pure-domain `SkillTreeProgressionPolicy` (untouched) — it's a repository-composition concern, not a domain rule.
2. **`SkillTreeNode.subtitle` (Flutter) has no backend equivalent** (`Skill` only has `id`/`title`/`order_index` — no tagline). Checked actual usage: `subtitle` is **never rendered** by `SkillPathNode` or anywhere else in the lesson feature (grep-verified) — a Flutter model field the UI never consumes. Fix: `HttpLessonApi` supplies `''` for it. Zero visible impact; flagged here rather than silently patched, per the story's own "explicit finding" guidance.

### Decision 2: `startLesson` makes 2 parallel requests, not 1

The real `GET /lessons/{id}` response has no beans data (bolt 004's contract never included it), but Flutter's `LessonContent.beansAtStart`/`beansMax` need a value. Rather than amend bolt 004's lesson-content schema a third time, `HttpLessonApi.startLesson` issues `GET /lessons/{id}` and `GET /beans` concurrently (`Future.wait`) and merges them. This still satisfies the Performance NFR's actual wording ("no network call *per exercise*, lesson payload fetched once at lesson start") — both calls happen once, at lesson start, never repeated per exercise. No backend change needed for this one.

### Decision 3: `completeLesson`'s error path needs a small, additive `LessonController`/`LessonScreen` fix

Audited the existing "Continue" button flow: `_ActionBar`'s `onPressed: controller.continueToNext` has no try/catch anywhere in the call chain, and `_finishLesson()` itself has none either — with `FakeLessonApi` this was invisible (it never throws), but a real network call realistically can fail (dev server down, timeout). This is exactly the kind of "no screen/controller change" assumption breaking that the story explicitly permits fixing rather than forcing. **Fix** (small, additive, not a redesign): `LessonController` catches the exception, exposes `completionError`, and leaves `_lessonFinished`/`isChecked` state such that the existing "Continue" button (already visible post-grading) simply retries `_finishLesson()` on a second tap — no new button, no new screen. `LessonScreen` shows a one-line inline error above the action bar when `completionError != null`.

### Decision 4: Session token attached per-request, not cached in `HttpLessonApi`

`SessionRepository.getSessionState()` is read at the top of every `HttpLessonApi` method (mirrors how `AuthFlowController` already reads it fresh at splash time) rather than once at construction — `LessonDependencies` (and therefore `HttpLessonApi`) is built at app start, before any sign-in has happened. A missing/expired token at call time throws `LessonApiException` immediately without attempting the request (this path is expected to be unreachable in practice, since the lesson feature is only ever reached via the authenticated `home` route, but it's a cheap, correct guard rather than sending a request guaranteed to 401).

## Files to Add/Change

- **Add**: `lib/shared/services/http_lesson_api.dart` (the real implementation), `lib/shared/services/lesson_api_exception.dart`
- **Change**: `lib/features/lesson/lesson_dependencies.dart` (default to `HttpLessonApi`, needs `SessionRepository`), `lib/main.dart` (wire `AuthDependencies.sessionRepository` into `LessonDependencies`), `lib/features/lesson/state/lesson_controller.dart` (Decision 3), `lib/features/lesson/screens/lesson_screen.dart` (Decision 3's inline error), `lib/shared/models/skill_tree.dart` (n/a — no model shape change needed, `lessonId`/`subtitle` already exist as fields)
- **Backend (amending bolt 005 again)**: `lesson_schemas.py` (+`lesson_id`), `lesson_use_cases.py` (`get_skill_tree`'s next-incomplete-lesson computation), `lesson_repositories.py`/`repositories.py` (`list_lesson_ids_by_skill` returns an ordered `tuple[str, ...]`, not `frozenset`), `lesson_routers.py` (wire the new field through)
- **Tests**: new `test/shared/services/http_lesson_api_test.dart` (mocked `http.Client`, mirrors `http_auth_api_test.dart`'s structure); backend `test_lesson_engagement_use_cases.py`/`test_lesson_engagement_endpoints.py`/`test_lesson_engagement_repositories.py` amended for the ordering change; new `LessonController` test for the completion-retry path

## Out of Scope

- Native SDK equivalents — not applicable (lesson-loop has no third-party auth/SDK dependency).
- Full per-exercise server-side re-grading — unaffected by this bolt (ADR-5 stands).
