---
last_updated: 2026-09-21T06:10:00Z
total_decisions: 15
---

# Decision Index

This index tracks all Architecture Decision Records (ADRs) created during Construction bolts.
Use this to find relevant prior decisions when working on related features.

## How to Use

**For Agents**: Scan the "Read when" fields below to identify decisions relevant to your current task. Before implementing new features, check if existing ADRs constrain or guide your approach. Load the full ADR for matching entries.

**For Humans**: Browse decisions chronologically or search for keywords. Each entry links to the full ADR with complete context, alternatives considered, and consequences.

---

## Decisions

### ADR-15: The course rail is the courses the learner has opened, derived from the offline cache
- **Status**: accepted
- **Date**: 2026-09-21
- **Bolt**: 029-course-switcher-panel (001-dashboard-shell-ui)
- **Path**: `bolts/029-course-switcher-panel/adr-15-course-rail-membership.md`
- **Summary**: `GET /courses` returns the whole catalog and the backend has no enrolment, so the dashboard's course rail derives membership on the client: a course is on the rail if it has a cached dashboard (ADR-14 already writes one per course after every successful load, so this means "opened"), or is active, or reports progress. Coming-soon courses never appear. No backend change; one new read, `CourseCacheStore.cachedCourseIds`. The rail is per device, and anything that clears cached dashboards also empties it.
- **Read when**: Touching the dashboard course rail, `CourseCacheStore`, clearing local data on log out (it now also empties the rail), or considering real per-user course enrolment on the backend.

### ADR-14: Offline course switching: a per-course dashboard cache and a locally pending switch
- **Status**: accepted
- **Date**: 2026-09-21
- **Bolt**: 027-course-offline-and-verification (002-courses-ui)
- **Path**: `bolts/027-course-offline-and-verification/adr-14-offline-course-switching.md`
- **Summary**: The client had no skill-tree cache and switching needs the server. Decided: cache one dashboard per course id; show the active course's copy offline with a note; allow an offline switch only to a cached course, recorded as pending and sent to the server before the next load; a failure carrying a backend `error_code` is never treated as offline. Lesson packs stay keyed by lesson id (completions are gated by the lesson's own course), with display-only course columns.
- **Read when**: Touching the dashboard load, `CachingCourseApi`, `CourseCacheStore`, offline switching, the lesson-pack store schema, or clearing local data on log out.

### ADR-13: `User.selected_language` becomes a mirror of the active course, written only by `ActivateCourse` (amends ADR-7)
- **Status**: accepted
- **Date**: 2026-09-20
- **Bolt**: 024-courses-service (001-courses-service)
- **Path**: `bolts/024-courses-service/adr-13-selected-language-as-mirror-of-active-course.md`
- **Summary**: ADR-7 allowed `selected_language` to change only via `UpdateUserPreferences`; with courses, the learning language is determined by the active course and the shipped client still reads `selected_language`. Decided: the column stays as a mirror of the active course's learning language; a single `ActivateCourse` operation (used by signup, the switch endpoint and `UpdateUserPreferences`) is its only writer, in one transaction with `active_course_id`; the from-language is derived, not stored.
- **Read when**: Modifying `User`, signup/onboarding, `UpdateUserPreferences`, `selected_language`, or adding any other way to change a user's language or course (must go through `ActivateCourse`).

### ADR-12: Courses as the top content level: explicit `course_id` on categories and vocab, active course on `users`, additive skill-tree envelope, lessons accessed by their own course
- **Status**: accepted
- **Date**: 2026-09-20
- **Bolt**: 024-courses-service (001-courses-service)
- **Path**: `bolts/024-courses-service/adr-12-courses-as-top-content-level.md`
- **Summary**: The app had one implicit course, but learners need any (learning, from) language pair. Decided: a `courses` table above categories; explicit `course_id` on `categories` and `vocab_items`; `users.active_course_id`; the skill-tree response stays additive (scoped to the active course, gains a `course` object); a lesson is startable/completable by its own course being available, not the active one, so queued offline completions survive a switch; progress separates per course through content ownership.
- **Read when**: Adding a language or course, changing the skill-tree, Practice, or lesson-access rules, working on offline caching or sync across courses, or anything that assumes a single global course.

### ADR-11: Categories as a first-class level: per-category skill ordering, additive skill-tree envelope, one shared `SkillPath` rule
- **Status**: accepted
- **Date**: 2026-09-19
- **Bolt**: 021-categories-service (001-categories-service)
- **Path**: `bolts/021-categories-service/adr-11-categories-additive-envelope-and-per-category-order.md`
- **Summary**: The curriculum was a flat, globally ordered skill list under a hardcoded "Unit 1". Decided: skill `order_index` becomes unique per category; `GET /skill-tree` gains `categories` and per-skill `category_id` additively (keeping `unit_title`/`unit_subtitle` as deprecated, derived from the first category) so the shipped client keeps working; a pure `SkillPath` value object is the single definition of "first / next skill in a category" for the tree read, access check and completion unlock. Every category is open; progression is linear only within one.
- **Read when**: Modifying skill ordering/progression, `SkillTreeProgressionPolicy`/`LessonCompletionService`, the skill-tree response shape, or adding anything that assumes a single global skill chain.

### ADR-10: Widen `complete_lesson`'s request contract to carry missed-exercise data, amending ADR-5's server-bounded-ledger boundary
- **Status**: accepted
- **Date**: 2026-09-17
- **Bolt**: 019-srs-tracking-service (001-srs-tracking-service)
- **Path**: `bolts/019-srs-tracking-service/adr-10-widen-completion-contract-for-vocab-tracking.md`
- **Summary**: `CompleteLessonRequest` only ever carried aggregate `correct_count`/`total_count` (ADR-5), which can't support per-vocab-item box-up/box-reset on lesson completion. Decided: add `missed_exercise_ids: list[str] = []`, populated from `LessonController`'s already-tracked (but previously unexposed) retry-queue state — touches already-shipped `002-core-lesson-loop-ui` code, chosen over keeping regular lessons box-up-only and reserving resets for Practice.
- **Read when**: Modifying `CompleteLessonRequest`/`complete_lesson`, `LessonController`'s retry-queue logic, or any future feature needing per-exercise (not just aggregate) signal from a lesson completion.

### ADR-9: Bean-refill retry double-spend gap is knowingly preserved, not fixed, by this bolt
- **Status**: accepted
- **Date**: 2026-09-17
- **Bolt**: 017-amole-service (001-amole-service)
- **Path**: `bolts/017-amole-service/adr-9-bean-refill-idempotency-gap-accepted.md`
- **Summary**: A retried Bean-refill request has no idempotency protection today (the existing column mutation has the same gap) and this bolt's ledger retrofit doesn't fix it either, since doing so would require a request-contract change beyond this bolt's scope. Decided: accept the pre-existing gap explicitly, narrow the Reliability NFR to awards only, and leave a client-supplied idempotency key as a future story if real-world double-spends are ever observed.
- **Read when**: Modifying the Bean-refill endpoint/flow, adding a new spend category for Amole (streak-freeze, cosmetics — Phase 2), or designing idempotency for any other client-mutation endpoint that currently lacks a client-supplied key.

### ADR-8: Amole balance moves to a real append-only ledger table, not a mutable column — accepting an asymmetry with XP
- **Status**: accepted
- **Date**: 2026-09-17
- **Bolt**: 017-amole-service (001-amole-service)
- **Path**: `bolts/017-amole-service/adr-8-amole-ledger-not-column.md`
- **Summary**: `user_beans.amole_balance` was a plain mutable column with no audit trail, insufficient once Amole gained multiple independent award writers. Decided: introduce `amole_transactions` (SUM(amount) = balance, UNIQUE(source, reference_id) for idempotency), removing the column entirely — but deliberately do not build the analogous `xp_transactions` table, since XP has no current multi-writer correctness problem to solve.
- **Read when**: Modifying Amole balance/award/spend logic, adding a new Amole source, or considering whether XP (or any other account-ledger-like value) should move from a computed-sum/mutable-column representation to a real ledger table.

### ADR-7: `User.selected_language`/`daily_xp_target` amended from strict write-once to write-once-then-only-via-`UpdateUserPreferences`
- **Status**: accepted
- **Date**: 2026-09-17
- **Bolt**: 013-user-preferences-service (001-user-preferences-service)
- **Path**: `bolts/013-user-preferences-service/adr-7-user-preferences-write-once-exception.md`
- **Summary**: `User`'s "written exactly once, never overwritten by a later authentication" invariant was written to prevent an auth-flow bug, not to block a deliberate user-initiated settings change. Decided: the invariant is amended, not removed — these fields are still write-once at creation, and after creation the only sanctioned mutation path is the new `UpdateUserPreferences` operation; no auth/re-authentication path may ever write them.
- **Read when**: Modifying `User`/`entities.py`, any authentication or re-authentication flow that touches `selected_language`/`daily_xp_target`, or adding any further legitimate way to change these fields (must extend this ADR's exception list explicitly, not bypass it silently). Amended by ADR-13 for `selected_language`.

### ADR-6: Offline sync replays the existing per-completion endpoint; no batch-sync endpoint
- **Status**: accepted
- **Date**: 2026-09-16
- **Bolt**: 008-offline-sync-service (001-offline-sync-service)
- **Path**: `bolts/008-offline-sync-service/adr-6-no-batch-sync-endpoint.md`
- **Summary**: Whether offline lesson-completion sync should get a new batch endpoint or just replay the existing per-completion endpoint N times was left open at Inception. Decided: no batch endpoint — the existing endpoint is already idempotent and now timestamp-aware, so calling it once per queued entry is correct; a batch endpoint would only be a performance optimization for a queue-size problem not yet shown to exist.
- **Read when**: Designing any client-side offline queue/retry mechanism against this backend, adding a new bulk/batch variant of an existing endpoint, or revisiting sync performance if real-world offline queues turn out larger than expected.

### ADR-5: Exercise grading moves client-side; the account ledger stays server-bounded, not server-computed
- **Status**: accepted
- **Date**: 2026-09-16
- **Bolt**: 005-lesson-engagement-service (001-lesson-service)
- **Path**: `bolts/005-lesson-engagement-service/adr-5-client-side-grading-with-bounded-server-ledger.md`
- **Supersedes**: ADR-4's "never expose `answer_key`" clause
- **Summary**: ADR-4's server-side-only grading (via a per-exercise call) turned out to conflict with `requirements.md`'s "no network call per exercise" NFR. The lesson-content response now includes correct-answer data so the client grades instantly and locally; the account ledger (beans/XP) is still bounded server-side (can't exceed what the account's real beans balance would allow) and completion is idempotent on a client-generated `attempt_id`, so the integrity that matters (the persisted ledger) is preserved without a per-exercise round trip.
- **Read when**: Implementing or modifying lesson-content/exercise API responses, the `/lessons/{id}/complete` endpoint, Beans/XP ledger logic, or reviewing any endpoint where a client-asserted lesson result is trusted (know the bound before assuming it's unchecked).

### ADR-4: Lesson-content API responses never include correct answers — grading is server-side-only
- **Status**: superseded by ADR-5
- **Date**: 2026-09-16
- **Bolt**: 004-lesson-content-service (001-lesson-service)
- **Path**: `bolts/004-lesson-content-service/adr-4-server-side-only-answer-keys.md`
- **Summary**: Whether the lesson-content payload includes correct answers or withholds them is a real API contract decision the next bolt depends on. `answer_key` is never serialized into any API response; grading is entirely server-side via a future `SubmitExerciseAnswer` use case reading the stored answer key directly.
- **Read when**: Understanding why the lesson-content schema originally excluded answer data, and why that no longer holds (see ADR-5) — the per-exercise-call approach this ADR planned around was never actually built.

### ADR-3: Single polymorphic `exercises` table with JSON `content`/`answer_key` columns
- **Status**: accepted
- **Date**: 2026-09-16
- **Bolt**: 004-lesson-content-service (001-lesson-service)
- **Path**: `bolts/004-lesson-content-service/adr-3-polymorphic-exercises-table.md`
- **Summary**: The lesson engine's 3 fixed exercise types need different rendering/answer data but share the same surrounding shape. Model exercises as one `exercises` table with a `type` discriminator plus JSON `content`/`answer_key` columns, not per-type tables.
- **Read when**: Implementing or modifying the `exercises` table/schema, adding a new exercise type, or working on any other closed, small-type-count polymorphic data model where per-type tables vs. a single JSON-backed table is a live question.

### ADR-2: Verify Sign in with Apple identity tokens via raw JWT-over-JWKS, no vendor SDK
- **Status**: accepted
- **Date**: 2026-09-15
- **Bolt**: 001-auth-service (001-auth-service)
- **Path**: `bolts/001-auth-service/adr-2-apple-jwt-jwks-verification.md`
- **Summary**: Story 003 requires verifying Apple's identity token server-side before creating/loading a `User`, and no Python SDK exists for this. Verify Apple identity tokens as standard JWTs against Apple's published JWKS using PyJWT + cryptography.
- **Read when**: Implementing or modifying Apple/Sign-in-with-Apple token verification, JWKS caching/rotation logic, or any other provider integration lacking an official SDK (this establishes the "raw JWT-over-JWKS" pattern as the fallback approach).

### ADR-1: Session tokens stored as SHA-256 hashes, not plaintext or a slow password hash
- **Status**: accepted
- **Date**: 2026-09-15
- **Bolt**: 001-auth-service (001-auth-service)
- **Path**: `bolts/001-auth-service/adr-1-session-token-hashing.md`
- **Summary**: The `AuthSession` aggregate needed a storage representation for its session token at rest, validated on a hot path. Store SHA-256(token_value), not plaintext or a slow password-hashing algorithm.
- **Read when**: Implementing or modifying session/token storage, working on any other high-entropy machine-generated secret (API keys, refresh tokens) where the "is this a password?" question comes up again, or reviewing security/logging conventions for tokens.
