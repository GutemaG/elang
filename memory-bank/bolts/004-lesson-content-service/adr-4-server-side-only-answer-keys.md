---
bolt: 004-lesson-content-service
created: 2026-09-16T09:25:00Z
status: superseded
superseded_by: adr-5-client-side-grading-with-bounded-server-ledger.md (memory-bank/bolts/005-lesson-engagement-service/)
---

# ADR-4: Lesson-content API responses never include correct answers — grading is server-side-only

## Context

Story 001's `GET /api/v1/lessons/{lesson_id}` returns a full lesson's exercises in one payload (a hard performance NFR — no per-exercise round trip). Each exercise has both renderable data (`content`: choices, word bank, audio URL) and a correct answer (`answer_key`: which choice, or which sequence, is right). Whether `answer_key` is part of that single response, or withheld and checked some other way, is a real API contract decision — and, per the task, one `005-lesson-engagement-service`'s `SubmitExerciseAnswer` (story 002) has to be built against, so it needs to be decided and documented now rather than left implicit.

## Decision

`answer_key` is never serialized into any API response from this bolt. The lesson-content payload contains only `content`-derived fields (`choices`, `word_bank`, `audio_url`, `prompt`). Grading is entirely server-side: bolt `005`'s `SubmitExerciseAnswer` use case will take `exercise_id` + the learner's `submitted_answer`, look up that exercise's `answer_key` directly from the database (the same JSON column this bolt writes, via its own repository read — not from anything the client sent or was ever given), and compare server-side before reporting correct/incorrect and consuming a Bean on a miss.

## Rationale

Two independent reasons converge on the same answer. First, Beans consumption (`requirements.md` FR-3) already requires server-side grading regardless of this decision — a client can't be trusted to self-report "I got this wrong, please deduct a heart," so the correctness check has to happen on the server either way, meaning there's no client-side grading path that would actually need `answer_key` shipped to the device. Second, given that grading is server-side anyway, shipping `answer_key` in the lesson-content response would be pure, avoidable exposure: any user can inspect network traffic (a browser devtools Network tab equivalent, or a proxy on the mobile client) and read the correct answer directly out of the JSON before even attempting the exercise, defeating the entire gamified-mistake premise (`requirements.md`'s "Mistakes have a real but non-punishing cost" business goal). Withholding it costs nothing here — no legitimate client-side use of the answer key exists — so there's no trade-off being made away from, unlike a typical security-vs-convenience decision.

### Alternatives Considered

| Alternative | Pros | Cons | Why Rejected |
|-------------|------|------|--------------|
| Include `answer_key` in the lesson-content response, grade client-side | Zero extra server round trip per answer; simpler client state machine | Trivially inspectable over the network before attempting the exercise; still needs a server-side re-check for Beans/XP integrity anyway (client-reported "I was wrong" can't be trusted for a gamification ledger), making the client-side copy purely redundant exposure | No genuine benefit once server-side re-validation is required regardless |
| Include `answer_key` but obfuscated/hashed (e.g. a hash of the correct choice id, client submits a hash to compare) | Slightly harder to casually read off the wire | Still guessable/brute-forceable for a handful of multiple-choice options; adds real complexity (hashing scheme, salt management) for a security property it doesn't actually deliver against a determined client | Security theater — doesn't meaningfully raise the bar, adds implementation cost bolt `005` would have to build against for no real gain |
| Never expose `answer_key`; server-side-only grading via a future `SubmitExerciseAnswer` (chosen) | No exposure at all; single source of truth for correctness stays in one place (the DB row this bolt already owns); matches how Beans/XP already have to be server-authoritative | Requires bolt `005` to do a DB lookup per submitted answer (one indexed `get_by_id`-style read) | N/A — this is the decision, and the "cost" is a single cheap indexed read `005` needs to do anyway for other reasons |

## Consequences

### Positive
- No client can read the correct answer for an exercise it hasn't completed by inspecting the lesson-content response.
- Establishes a clear, singular contract for bolt `005`: `SubmitExerciseAnswer` always re-derives correctness from the stored `answer_key`, never trusts a client-asserted "was I right" flag — consistent with the existing project convention (`001-auth-service` never trusts a client-asserted user id either; server-side verification is this codebase's established norm, not a new pattern).
- `content` and `answer_key` staying separate JSON columns (ADR-3) is precisely what makes this enforceable at the schema/repository level, not just "remember not to serialize this field" convention in application code — the Pydantic response schemas for exercises are built from `content`-derived domain fields only; there is no `answer_key` field on them to accidentally serialize.

### Negative
- Bolt `005` must implement its own read path for `answer_key` (its own repository method or reuse of this bolt's `LessonRepository`) — a small, expected coupling, not a new integration.

### Risks
- If a future requirement genuinely needs offline/no-network grading (not in scope for this intent — no offline mode exists in `requirements.md`), this decision would need revisiting. Flagged here so it isn't silently reversed without noticing the reason it was made this way.

## Related

- **Stories**: 001-serve-skill-tree-and-lesson-content (defines the payload this ADR constrains); 002-answer-exercises-and-manage-beans (bolt `005`, the first consumer of `answer_key`, must be built against this contract)
- **Standards**: `memory-bank/standards/coding-standards.md` (server-side validation / "ledger-affecting endpoints must be transactional" convention this decision is consistent with)
- **Previous ADRs**: ADR-3 (the `content`/`answer_key` JSON-column split this decision relies on to be enforceable)
