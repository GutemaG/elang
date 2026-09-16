---
unit: 001-lesson-service
bolt: 005-lesson-engagement-service
stage: model
status: complete
created: 2026-09-16T12:05:00Z
---

## Static Model: Lesson Engagement Service

### Bounded Context

Same bounded context as bolt `004` (lesson content), extended with the write-side: grading a completed lesson attempt, the Beans ledger, XP award, skill-progress/crown-level writes, and the daily streak. Bolt `004` owns reads of `Skill`/`Lesson`/`Exercise`/`UserSkillProgress`; this bolt owns all writes to `UserSkillProgress`, plus the new `UserBeans`, `UserStreak`, and `LessonAttempt` aggregates.

### A Carried-Forward Conflict This Stage Must Resolve

`requirements.md`'s Performance NFR is explicit and Inception-level (higher authority than a single bolt's internal decision): *"Exercise transition: instant — no network call per exercise (lesson payload fetched once at lesson start)."* Bolt `004`'s ADR-4 ("`answer_key` never leaves the server; grading is server-side-only via a per-exercise `SubmitExerciseAnswer` call") cannot be satisfied simultaneously with that NFR — a per-exercise server round trip to grade *is* a network call per exercise. This was an internal inconsistency in bolt `004`'s own artifacts (ADR-4 never checked itself against the NFR). It must be resolved here, since this bolt is the first to actually build the answer-validation path. Resolution is detailed in Technical Design (Stage 2) and formalized as ADR-5, which supersedes ADR-4's "never expose `answer_key`" clause while keeping its ledger-integrity spirit intact elsewhere. `adr-4-...md`'s frontmatter is updated (`superseded_by: adr-5-...md`) as part of this bolt, per standard ADR-supersession practice — its historical rationale is left intact, not deleted.

### Entities

- **UserBeans**: `user_id`, `current_count` (int, 0..`beans_max`), `last_regen_at` (datetime) — Business rules: regeneration is computed lazily (never a scheduled job) as `min(beans_max, current_count + elapsed_time // regen_interval)` whenever the row is read or written; `last_regen_at` only advances by whole regen intervals consumed, so partial progress toward the next bean isn't lost between reads. A user with no row yet is a valid default state (max beans, no regen owed) — same "absence is meaningful" pattern bolt `004` established for `UserSkillProgress`.
- **UserStreak**: `user_id`, `current_streak` (int, ≥0), `last_completed_date` (date, nullable), `active_freeze_count` (int, ≥0) — Business rules: `current_streak` increments by exactly 1 the first time a day completes a lesson, never again that same calendar day; a gap of exactly one missed calendar day consumes one `active_freeze_count` (if >0) and leaves `current_streak` unchanged; a gap of more than one day, or exactly one day with no freeze available, resets `current_streak` to 1 on the next completion (not 0 — the completing lesson itself counts as day one of a new streak).
- **LessonAttempt**: `id` (client-supplied, opaque string — see Technical Design's idempotency design), `user_id`, `lesson_id`, `correct_count`, `total_count`, `xp_awarded`, `completed_at` — Business rules: a row is created exactly once per genuine attempt, at completion time (not at lesson start — this bolt never models "in-progress" attempts server-side, since grading itself is client-side per the resolved conflict above); a second completion request with the same `id` is a no-op that returns the original stored result unchanged (idempotency — story 003's "exactly once" requirement). `UserSkillProgress` (bolt `004`'s entity, extended here with write operations: `unlocked`/`crown_level`/`completed_at` transitions on skill completion/replay).

### Value Objects

- **BeanRegenConfig**: `max_beans` (int constant), `regen_interval` (duration constant) — Constraints: both fixed Technical Design constants (this bolt picks the values, not product — no external config store exists), applied identically to every user.
- **StreakEvaluation**: `new_streak_count`, `freeze_consumed` (bool) — Constraints: the pure output of `StreakPolicy.evaluate`, never persisted as its own row; the caller writes its fields onto `UserStreak`.
- **LessonCompletionOutcome**: `xp_awarded`, `skill_unlocked` (`Skill | None`), `new_crown_level`, `streak` (`StreakEvaluation`) — Constraints: the full result of one `CompleteLesson` call, returned to the presentation layer for response mapping; never persisted as its own record (its constituent parts are — `LessonAttempt`, `UserSkillProgress`, `UserStreak`).

### Aggregates

- **UserBeans** (Aggregate Root): Members: `UserBeans` entity only — Invariants: `0 <= current_count <= max_beans`; at most one row per `user_id`.
- **UserStreak** (Aggregate Root): Members: `UserStreak` entity only — Invariants: `current_streak >= 0`; `active_freeze_count >= 0`; at most one row per `user_id`.
- **LessonAttempt** (Aggregate Root): Members: `LessonAttempt` entity only — Invariants: `id` is globally unique (it's the idempotency key); `correct_count <= total_count`; `xp_awarded` is fixed forever once written (never recomputed on a later read).
- **UserSkillProgress** (extended, still bolt `004`'s aggregate — this bolt adds writes): Invariants unchanged from bolt `004`; this bolt is the first and only writer.

### Domain Events

None persisted (no event store/outbox in this codebase, matching bolts `001`/`004`). `LessonCompletionOutcome` plays the role of an in-process result object for this request only.

### Domain Services

- **BeanLedger**: `regenerated_count(beans: UserBeans, now: datetime, config: BeanRegenConfig) -> tuple[int, datetime]` (pure function: computes the up-to-date count and the `last_regen_at` that should be persisted); `consume(beans: UserBeans, wrong_count: int, config, now) -> UserBeans` (regenerates first, then subtracts `wrong_count`, clamped at 0 — never goes negative); `refill(beans: UserBeans, config) -> UserBeans` (sets `current_count = max_beans`, `last_regen_at = now`).
- **StreakPolicy**: `evaluate(streak: UserStreak, completion_date: date) -> StreakEvaluation` — same-day completion → unchanged count, no freeze consumed; exactly one day gap with `active_freeze_count > 0` → count unchanged, `freeze_consumed=True`; any other gap (including "no prior completion") → `new_streak_count = 1`, `freeze_consumed=False` unless the gap is exactly the freeze-eligible case above.
- **LessonCompletionService**: `complete(lesson, user_beans, user_streak, progress_rows, all_skills, correct_count, total_count, now) -> LessonCompletionOutcome` — orchestrates: XP (a fixed `XP_PER_CORRECT_ANSWER` Technical Design constant × `correct_count`), skill-progress transition (first-ever full-skill completion → `completed_at` set, `crown_level=1`, next skill by `order_index` unlocked; a replay of an already-completed skill → `crown_level = min(5, crown_level + 1)`, no further unlock), and delegates to `StreakPolicy` for the streak half. Pure domain logic — no repository/DB calls; the application layer feeds it fully-loaded aggregates and persists whatever it returns.

### Repository Interfaces

- **UserBeansRepository**: `get(user_id) -> UserBeans | None`, `upsert(beans: UserBeans) -> None`.
- **UserStreakRepository**: `get(user_id) -> UserStreak | None`, `upsert(streak: UserStreak) -> None`.
- **LessonAttemptRepository**: `get(attempt_id) -> LessonAttempt | None` (idempotency check), `add(attempt: LessonAttempt) -> None`.
- **UserSkillProgressRepository** (bolt `004`'s Protocol, extended): `+upsert(progress: UserSkillProgress) -> None`.

### Ubiquitous Language

- **Attempt id**: A client-generated opaque string identifying one lesson attempt, echoed back on completion; the idempotency key that makes "exactly once" enforceable without the server needing to track in-progress attempts.
- **Regen**: The lazy, read/write-time computation of beans restored since `last_regen_at`, never a background job.
- **Freeze**: A `UserStreak.active_freeze_count` unit that, when consumed, protects exactly one missed calendar day from resetting the streak.
- **Trust boundary for lesson results** (see ADR-5): this bolt grades nothing server-side at completion — it trusts the client-reported `correct_count`/`total_count` for a *given, already-instant-graded* attempt, because per-exercise correctness itself had to move client-side to satisfy the NFR (a client capable of instant local grading is, by the same necessity, capable of self-reporting that grade — full server-side re-grading would require shipping the exact same answer-key data server-side already exposed client-side, so it adds no real integrity beyond what ADR-5 already accepts as a trade-off for a non-monetized, single-player feature).

### Open Items Carried Into Stage 2 (Technical Design)

- Exact `BeanRegenConfig` constants (max beans, regen interval) and `XP_PER_CORRECT_ANSWER` — Technical Design constants, calibrated against existing `daily_xp_target` range (20-80) from intent `001`.
- Exact idempotency mechanics (how `attempt_id` is generated/transported, and the accompanying Flutter-side amendment to `LessonController`/`LessonApi`) — Technical Design.
- Timezone policy for "calendar day" (streak) — Technical Design, per story 004's explicit open item.
