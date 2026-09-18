---
bolt: 019-srs-tracking-service
created: '2026-09-17T21:45:00Z'
status: accepted
superseded_by: null
---

# ADR-10: Widen `complete_lesson`'s request contract to carry missed-exercise data, amending ADR-5's server-bounded-ledger boundary

## Context

Story `002-vocab-progress-retrofit`'s AC2 requires that a lesson completion touching a vocab item the user has seen before update that item's Leitner box — up on correct, reset on incorrect. Reading the real current code (Stage 3, not assumed at Stage 1-2) confirms the request contract cannot support this today:

- `CompleteLessonRequest` (`backend/app/infrastructure/api/lesson_schemas.py`) carries only `attempt_id`, `correct_count`, `total_count`, `time_spent_seconds`, `client_completed_at` — an aggregate, not per-exercise result.
- Flutter's `LessonController` (`lib/features/lesson/state/lesson_controller.dart`) tracks a retry queue internally (a missed exercise's index is requeued to the end of the lesson) but never exposes or sends which exercises were missed — only aggregate `_correctCount`/`_wrongCount`.
- Because of that retry-until-correct design, every exercise in a completed lesson has, by construction, eventually been answered correctly — there is no "the lesson ended with this one still wrong" case to report, only "was this one ever missed before eventually getting it right."

This is exactly the boundary ADR-5 drew deliberately: the server receives an aggregate `correct_count`/`total_count`, not per-exercise detail, so the lesson-completion round trip stays a single call. Satisfying story 002 as written requires crossing that boundary, and doing so touches `LessonController`/`HttpLessonApi`/`LessonApi` — already-shipped code belonging to a different, completed unit (`002-core-lesson-loop-ui`, bolts 006/007), not this bolt's own backend-only unit.

## Decision

Widen the completion contract with a new field carrying which exercises were ever missed during the attempt (not full per-attempt detail, just the retry-queue membership the client already tracks internally):

- `CompleteLessonRequest` gains `missed_exercise_ids: list[str] = []` — the set of exercise IDs that were answered incorrectly at least once before the lesson finished (derived from `LessonController`'s existing retry-queue behavior — no new client-side tracking logic needed, just exposing state that already exists).
- `complete_lesson`'s vocab-progress side effect (inside the existing `attempt_id` idempotency boundary) treats any vocab-linked exercise in the lesson as: first appearance → create at box 1; seen before and **not** in `missed_exercise_ids` → box up; seen before and **in** `missed_exercise_ids` → box reset.
- This amends ADR-5's boundary — it does not reopen server-side grading (the client still grades locally and the server still never learns the actual selected answer), it only adds a coarse per-exercise pass/fail-at-least-once signal on top of the aggregate.

## Rationale

The alternative (leaving the contract untouched, letting regular-lesson vocab updates only ever box-up, and reserving true box-reset for a new Practice-only completion endpoint) was concretely on the table and was rejected by explicit user decision: it would narrow story 002's AC2 for the regular-lesson path, and the user preferred literal correctness over avoiding the cross-unit touch.

### Alternatives Considered

| Alternative | Pros | Cons | Why Rejected |
|-------------|------|------|--------------|
| Widen the contract (chosen) | Satisfies story 002's AC2 exactly; single mechanism for both regular lessons and (later) Practice | Touches already-shipped Flutter code outside this bolt's declared unit | User's explicit choice — correctness over avoiding cross-unit scope |
| No contract change; regular lessons only box-up, resets reserved for Practice's own new endpoint | Zero touch to shipped code; clean bolt boundary | Narrows AC2 for the regular-lesson path; two different vocab-update code paths (lesson vs. practice) to keep consistent forever | Rejected by user in favor of the accurate option |
| Send full per-exercise result list (not just missed IDs) | More future-proof for other per-exercise analytics | No current requirement needs more than "was this missed"; larger payload and larger Flutter change for no present benefit | Rejected as over-scoped for this story |

## Consequences

### Positive

- Story 002's AC2 (box-up vs. box-reset on every lesson completion, not just Practice) is satisfiable exactly as written.
- One vocab-update code path serves both regular lessons and (later) Practice sessions, rather than two divergent mechanisms.
- The exposed retry-queue data is state `LessonController` already computes for its own requeue behavior — no new grading/tracking logic, only a new getter and a new field on the existing completion payload.

### Negative

- This bolt (`001-srs-tracking-service`, backend-only per its unit brief) now also requires a small change to `002-core-lesson-loop-ui`'s already-shipped `LessonController`/`HttpLessonApi`/`FakeLessonApi`, and their existing tests, to populate and send `missed_exercise_ids`.
- `CompleteLessonRequest`'s shape changes — any other client of this endpoint (there are none known today besides the Flutter app) would need the same update; the field defaults to `[]` so older clients remain valid, just without vocab-reset accuracy.

### Risks

- Risk: forgetting to update the Flutter side leaves the field always empty, silently degrading every "seen before" vocab update to always box-up, never reset. Mitigation: Stage 4/5 must include an integration-style test asserting a `missed_exercise_ids`-bearing request actually resets the box, not just that box-up works.

## Related

- **Stories**: `002-vocab-progress-retrofit`, `003-leitner-box-algorithm`
- **Standards**: none new — this is a contract amendment, not a new pattern
- **Previous ADRs**: Amends ADR-5's server-bounded-ledger boundary (aggregate-only completion data); composes with ADR-6's offline-replay-via-existing-endpoint (the widened field replays the same way as the rest of the request on a delayed sync)
