---
id: 002-grade-match-pairs-attempts
unit: 001-match-pairs-service
intent: 004-match-pairs-exercise-type
status: retired
priority: must
created: '2026-09-17T04:30:00Z'
assigned_bolt: null
implemented: false
---

# Story: 002-grade-match-pairs-attempts (RETIRED)

**Retired 2026-09-17, during Construction bolt `011-match-pairs-service`'s Stage 1 (Domain Model) prior-decision lookup.**

This story assumed backend-side grading. That contradicts **ADR-5** (`memory-bank/bolts/005-lesson-engagement-service/adr-5-client-side-grading-with-bounded-server-ledger.md`): all exercise grading in this codebase is client-side — the lesson-content response carries the correct-answer data and the Flutter client grades instantly and locally; the backend only bounds the Beans/XP ledger, it never re-validates per-exercise correctness itself.

For `match_pairs`, this means: the backend serves `content` (`MatchPairsContent`) and `answer_key` (`PairAnswerKey`, holding `correct_pairs`) as two separate fields in the same response — same split as `multiple_choice` — but never compares a submitted attempt against them itself. The actual tap-and-compare logic is client-side and is already covered by `002-match-pairs-ui`'s story `001-match-pairs-exercise-screen` acceptance criteria. (An earlier draft of this note incorrectly claimed content alone was the ground truth with no separate answer key — corrected once `011-match-pairs-service`'s Implement stage found `Exercise.answer_key` is a mandatory, separate field for every exercise type.)

**No replacement story was created** — the behavior this story described is delivered entirely by `002-match-pairs-ui/001-match-pairs-exercise-screen`. See `requirements.md`'s FR-2 (updated with the same correction) and the Decision Log in `../../inception-log.md`.

This file is kept (not deleted) as an audit trail of the correction, consistent with how this project has handled prior discovered-during-construction mistakes (see the SQLite-migration and seed-audio-URL errata in `003-offline-caching-and-sync`'s logs).
