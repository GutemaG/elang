---
stage: plan
bolt: 020-practice-ui
created: '2026-09-17T23:15:00Z'
---

## Implementation Plan: practice-ui

### Objective

A learner sees an accurate due-count on the dashboard, can start a Practice session assembled entirely from due vocab items' linked exercises, answers them via the exact same widgets a regular lesson uses, and completes the session through a small, dedicated backend path that awards XP/Amole and updates vocab progress — without touching the daily streak or skill-tree progression, and without ever letting a locked skill block a due item from appearing.

### Real-Source Findings (Plan-stage, not assumed)

Reading `main.dart` confirms there is no tabbed navigation shell — `home` routes directly to `SkillTreeDashboardScreen`. Reading `complete_lesson`/`get_lesson_content` confirms **two structural gaps** the original Inception correctly flagged as open but couldn't resolve without Construction-time source access:

1 - `complete_lesson` requires a single `lesson_id` and validates `total_count == that lesson's exercise count`, and `LessonAccessPolicy` blocks a locked skill's lesson. A Practice due-set spans arbitrary lessons/skills and must work even for a locked skill's item (story 002's explicit edge case) — `complete_lesson` cannot be reused, confirmed by decision (see below).
2 - `GET /api/v1/lessons/{lesson_id}` (the only way to fetch full exercise content today) also runs `LessonAccessPolicy`, so it 403s for a locked skill's lesson. Practice therefore cannot fetch exercise content via the existing endpoint either — due-items must carry full exercise content itself.

Reading `lesson_screen.dart` confirms every exercise-rendering widget (`_MultipleChoiceBody`, `_ListeningBody`, `_SentenceConstructionBody`, `_MatchPairsBody`, `_ExerciseBody`, `_ActionBar`, `_ProgressHeader`) is a **private class in that one file**, hard-typed to the concrete `LessonController`. Genuine reuse with zero new rendering code is only possible by extending `LessonController`/`LessonScreen` themselves.

### User Decisions (this session)

1 - Practice completion gets a small, new, dedicated backend path — not a reuse of `complete_lesson`. It awards XP (`XP_PER_CORRECT_ANSWER` per correct vocab answer, same rate as lessons) and a new flat Amole bonus, and updates `UserVocabProgress` via the already-built `LeitnerBoxPolicy`. It does **not** touch `UserStreak` or `UserSkillProgress`/crown level — Practice stays independent of skill-tree/streak semantics, exactly as story 002's edge case already implies for unlock-independence.
2 - `GET /api/v1/practice/due-items` (built in bolt 019) is widened to return each item's full exercise content inline, reusing the existing per-type response serialization (`MultipleChoiceExerciseResponse` etc.) — extracted so both this endpoint and the regular lesson-content endpoint share the mapping code. No access-policy check on this endpoint (due-ness is Practice's only real gate).
3 - `LessonController`/`LessonScreen` gain a narrow **practice mode**: skips Beans consumption/interruption entirely (Practice isn't gated by mistake tolerance — there is no product requirement for it, and gating *review* behind the same currency that gates *forward progress* would be the wrong incentive), and calls the new practice-completion endpoint instead of `complete_lesson` at finish time. This is the smallest-diff option, consistent with this codebase's "extend, don't pre-abstract" convention — but it touches the most heavily-tested file in the app, so Stage 3 must include an explicit regression pass over the *regular* (non-practice) lesson flow, not just new practice tests.

### Deliverables

**Backend** (small, mechanical additions reusing bolt 019's already-built domain logic — no new DDD modeling):

- Extract the existing `_to_exercise_response`-style exercise mapping (`lesson_routers.py`) into a shared, importable function so `practice_routers.py` can reuse it without duplication.
- `LessonRepository.list_exercises_by_vocab_item_ids` → return full `Exercise` domain entities (or a parallel method), not just ids; `get_due_items` composes these into each `DueItem`.
- `DueItemResponse` gains full exercise fields (reusing `ExerciseResponse`'s discriminated union) instead of a bare `exercise_id`.
- New `AmoleSource.PRACTICE_SESSION` value (StrEnum + DB `CHECK` constraint widen, same migration pattern as `c726efa81972`'s `match_pairs` addition) and `AMOLE_PRACTICE_SESSION_AWARD` constant.
- New `PracticeAttempt` entity + `PracticeAttemptRepository` (mirrors `LessonAttempt`'s idempotency shape — `id` client-supplied, `get`/`add` only — but its own table, since practice spans multiple lessons/skills and has no `lesson_id`/`skill_id` to anchor to).
- New application use case `complete_practice_session`: idempotent on a client-supplied `session_id`; for each `{vocab_item_id, correct}` result, runs the existing vocab-progress logic (same first-appearance/box-transition code path `complete_lesson` already has — extracted into a small shared helper so the two call sites can't drift); awards XP/Amole; persists a `PracticeAttempt`.
- New endpoint `POST /api/v1/practice/complete`.

**Frontend**:

- `LessonController`: an optional practice-mode constructor path — no Beans decrement/interruption, calls the new practice-completion API method instead of `completeLesson`, maps the response into the existing `LessonCompletionResult` shape (streak/crown/skill-unlock fields at their "not applicable" defaults, matching the existing `pendingSync`-style "safe defaults when not applicable" convention already in that model).
- `LessonApi`/`HttpLessonApi`/`FakeLessonApi`: new `getDueCount()`, `getDueItems()`, `completePracticeSession(...)` methods; new client models mirroring the widened due-items/practice-complete response shapes.
- `LessonScreen`: an optional practice-session construction path — accepts pre-assembled exercises directly (no `startLesson` fetch, no offline-pack-download-required check, since Practice is online-only per FR-5) and threads practice mode into `LessonController`.
- New `PracticeEntryCard` (or similar) on `SkillTreeDashboardScreen`: due-count display, disabled (not hidden) when `ConnectivityMonitor.isOnline()` is false — reusing the existing connectivity plumbing already wired into the dashboard, same "disable, don't hide" convention as the out-of-Beans modal's insufficient-Amole state.
- Tapping it fetches due-items and launches `LessonScreen` in practice mode; on completion, returns to the dashboard and refreshes (so due-count reflects the change immediately, per story 002's last acceptance criterion).

### Acceptance Criteria (from stories 001/002)

- [ ] Due-count visible and matches the backend's due-count endpoint
- [ ] Zero due items shown clearly (not hidden)
- [ ] Entry point visibly disabled (not hidden) when offline
- [ ] A session includes only exercises linked to currently-due vocab items, up to the backend's limit
- [ ] Every practice exercise renders via the exact same widget a regular lesson uses — no new rendering code
- [ ] A due item whose lesson is locked for the user still appears and is answerable in Practice
- [ ] Session completion awards XP/Amole and updates vocab progress; does not touch streak or skill-progress
- [ ] Due-count after a session reflects the just-reviewed items no longer being due
- [ ] Zero regression to the regular (non-practice) lesson-taking flow — explicit regression pass at Stage 3
