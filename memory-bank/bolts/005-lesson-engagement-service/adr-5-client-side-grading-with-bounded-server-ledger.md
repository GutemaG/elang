---
bolt: 005-lesson-engagement-service
created: 2026-09-16T12:30:00Z
status: accepted
supersedes: adr-4-server-side-only-answer-keys.md
superseded_by: null
---

# ADR-5: Exercise grading moves client-side; the account ledger stays server-bounded, not server-computed

## Context

Bolt `004`'s ADR-4 decided the lesson-content payload never includes correct-answer data, and that a future `SubmitExerciseAnswer` operation would grade every answer server-side. Building this bolt against that contract surfaces a direct conflict: `requirements.md`'s Performance NFR requires instant exercise feedback with **no network call per exercise** (lesson payload fetched once at lesson start). A per-exercise `SubmitExerciseAnswer` call *is* a network call per exercise — ADR-4 was never checked against this NFR when it was written. One of the two has to give, and the NFR is an Inception-level requirement, not a bolt-local preference.

## Decision

1. The lesson-content response now includes each exercise's correct-answer data (`correct_choice_id` / `correct_sequence`), so the client grades every answer instantly and locally. There is no per-exercise endpoint.
2. `POST /lessons/{lesson_id}/complete` accepts the client's reported `correct_count`/`total_count` for XP purposes, but **bounds** it: the implied wrong-answer count may not exceed the user's actual server-side beans balance at attempt start, or the completion is rejected (`beans_exhausted`). Idempotent on a client-generated `attempt_id`.

## Rationale

Once instant, network-free feedback is required, the client must be able to determine correctness on its own — there is no scheme (hashing, obfuscation) that provides real protection here; ADR-4 itself already rejected an obfuscated-answer-key alternative as "security theater" for the same reason. Given the client can therefore always determine the correct answer, it can also always *report* a maximally favorable result; no amount of hiding the grading endpoint changes that once the answer key is client-visible. Full server-side re-grading of every submitted answer at completion would require the server to already know what the client saw (the same exposed answer key) and would only catch a client that reports *inconsistently* with what it displayed — a narrow, low-value integrity gain for a single-player, non-monetized educational feature (no PvP ranking, no real-money economy competes on these numbers). The chosen bound (wrong-answer count can't exceed the account's actual beans) still prevents the concrete abuse that matters in this app's ledger: manufacturing XP/beans state the account could not have reached, e.g. claiming a perfect run after the account should have been locked out at 0 beans.

### Alternatives Considered

| Alternative | Pros | Cons | Why Rejected |
|-------------|------|------|--------------|
| Keep ADR-4 as-is: server-side-only grading via a per-exercise call | Strongest integrity; matches ADR-4's original reasoning | Violates the Performance NFR outright (a network call per exercise) | The NFR is an Inception-level requirement; a bolt's ADR can't override it |
| Full server-side re-grading of each submitted answer at completion (batch, one call) | No per-exercise call; strongest integrity given that constraint | Requires the client to also submit every individual response (not just aggregate counts) — a further amendment to the already-built, tested `LessonController`/`LessonApi` beyond the `attempt_id` addition already needed; the integrity gain over the bound in the chosen decision is narrow, since the answer key is client-visible either way | Disproportionate implementation cost (a second Flutter-side amendment) for a security property that's already mostly achieved by the cheaper bound |
| Client-side grading, no server bound at all (trust `correct_count`/`total_count` outright) | Simplest | An account could self-report unlimited XP/never run out of beans | Rejected — the bound costs nothing extra to implement and closes the concrete abuse case that matters |

## Consequences

### Positive
- Satisfies the Performance NFR exactly as written, using the same instant-feedback architecture the (already-built, verified) Flutter UI already assumed.
- The account ledger (actual persisted beans/XP) still cannot be pushed further than the account's real beans would allow, closing the main abuse vector without full re-grading cost.
- Idempotent completion (via `attempt_id`) delivers story 003's "exactly once" requirement independently of this decision.

### Negative
- A modified client can always display (and self-report) a correct answer for an exercise the real user got wrong, up to the beans bound — accepted, since the account-level abuse case is what's actually guarded.
- Reverses ADR-4's "no client can read the correct answer" property entirely.

### Risks
- If a future intent adds a competitive-ranking or monetized feature whose integrity depends on grading a user cannot influence, this decision must be revisited — the bound here is not suffient for that class of feature. Flagged, not silently carried forward.

## Related

- **Supersedes**: ADR-4 (`004-lesson-content-service`) — its "never expose `answer_key`" clause specifically; its `content`/`answer_key`-as-separate-value-objects modeling (ADR-3-adjacent) is unaffected and still what makes this bolt's schema change a field addition, not a re-model.
- **Stories**: 002-answer-exercises-and-manage-beans, 003-complete-lesson-award-xp-and-progress (idempotency)
- **Standards**: `memory-bank/standards/coding-standards.md` ("ledger-affecting endpoints must be transactional")
