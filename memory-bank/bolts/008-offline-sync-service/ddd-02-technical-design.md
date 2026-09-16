---
stage: design
bolt: 008-offline-sync-service
created: '2026-09-16T21:45:00Z'
---

## Technical Design: 001-offline-sync-service

### Architecture Pattern

No new pattern. This bolt amends `001-lesson-service`'s existing FastAPI + SQLAlchemy (async) layered service (bolts 004/005) in place — same router modules, same `LessonAttempt`/`Skill`/`Lesson` models, same session-token auth dependency. Introducing a separate service or module tree would contradict the unit brief's explicit framing ("amendment, not a new service").

### Layer Structure

```text
┌─────────────────────────────┐
│      Presentation           │  Existing lesson-service routers (skill-tree, lesson-content,
│                              │  complete-lesson endpoints) — request/response shape amended
├─────────────────────────────┤
│      Application            │  CompleteLessonUseCase (amended: idempotency-check-first,
│                              │  then CompletionTimestampValidator, then existing ADR-5
│                              │  bounded-ledger logic); GetSkillTree/GetLessonContent
│                              │  use cases (amended: attach ContentVersion)
├─────────────────────────────┤
│        Domain               │  LessonAttempt (amended), CompletionTimestamp (new),
│                              │  ContentVersion (new), StreakAttributionService (amended)
├─────────────────────────────┤
│     Infrastructure          │  LessonAttemptRepository (confirm/add findByAttemptId),
│                              │  Skill/LessonRepository (amended query to surface a MAX
│                              │  last-modified aggregate for ContentVersionResolver)
└─────────────────────────────┘
```

### API Design

- **`GET /skill-tree`** (existing, amended): Response — each skill entry gains `content_version: int` (epoch-millis of the most recent `updated_at` across that skill's lessons and exercises, computed via one `MAX()` aggregate query per skill-tree fetch, not a per-skill round trip — same N+1 discipline bolt 007 already established for this endpoint).
- **`GET /lessons/{lesson_id}`** (existing, amended): Response — gains a top-level `content_version: int` for that lesson (`MAX(lesson.updated_at, exercise.updated_at for all its exercises)`).
- **`POST /lessons/{lesson_id}/complete`** (existing, amended): Request — gains required field `client_completed_at: datetime` (ISO 8601). Existing fields (`attempt_id`, `correct_count`, `total_count`) unchanged. Response — unchanged shape. Behavior:
  1. Look up `attempt_id`. If it already exists → return the stored result immediately (`LessonAttemptReplayed`), skipping every step below. This ordering is deliberate: a previously accepted attempt must never be re-validated or re-rejected on retry.
  2. If new → validate `client_completed_at` via `CompletionTimestampValidator` (see Security Design). Invalid → `422` with `error: "invalid_completion_timestamp"`, no ledger effect (`LessonAttemptRejected`).
  3. Valid → proceed with the existing ADR-5 bounded-ledger logic (correct_count/total_count bounded by real Beans balance), now attributing streak/XP-day using `client_completed_at`'s calendar date instead of the request's arrival time (`LessonAttemptCompleted`).

No new/batch endpoint — see Decision below.

### Decision: No Batch-Sync Endpoint

Story `003-idempotent-offline-replay` left this open. Resolved here: the client calls the existing (now idempotent-and-timestamped) per-completion endpoint once per queued entry, sequentially, in completion order — no new batch endpoint in this bolt.

Rationale: the per-completion endpoint is already correctness-safe to call N times (idempotent, bounded), so a batch endpoint would only buy network-efficiency, not correctness. Given typical offline queue sizes (a handful of lessons between reconnects, per the requirements' own framing — this isn't built for weeks of backlog as the common case, just supported for it), N sequential calls is an acceptable cost. This is flagged as an ADR candidate in Stage 3, since it's a real trade-off (round-trip count vs. added endpoint surface) that a future intent might revisit if queue sizes turn out larger in practice than assumed here.

### Data Model

- **`lesson_attempts`** (existing table, amended): + `client_completed_at TIMESTAMPTZ NOT NULL` — required, not nullable, so online and offline completions share one code path (online completions simply pass "now" as their `client_completed_at`, per the UI unit's story 002 technical notes). Existing idempotency mechanism (unique constraint or equivalent lookup on `attempt_id`, per ADR-5) is re-verified during Implement, not re-designed.
- **Content version**: no new column assumed. Design intent is to derive `ContentVersion` from each row's existing `updated_at` (standard column already used elsewhere in this codebase's SQLAlchemy models). **Open verification item for Implement stage** (source code is off-limits until then, per this stage's constraints): confirm `skills`, `lessons`, and `exercises` tables actually carry `updated_at`; if any is missing, add it via a lightweight additive migration rather than introducing a separate versioning table.

### Security Design

- **Timestamp plausibility bound** (`CompletionTimestampValidator`): reject `client_completed_at` if it is more than **5 minutes in the future** relative to server time (small clock-skew allowance) or **earlier than the user's account `created_at`** (a completion literally cannot predate the account). Deliberately *no* upper bound on how far in the past a valid timestamp may be — the product intent (requirements.md FR-3) is to support long offline gaps without penalizing them; only genuinely impossible timestamps are rejected.
- **Idempotency-before-validation ordering** (see API Design step 1) prevents a subtle bug class: a valid, already-accepted attempt must never fail on retry due to bounds — checking `attempt_id` first guarantees this regardless of what the validator's bounds are.
- **Unchanged from ADR-5**: a client can still self-report a favorable `correct_count`/`total_count` for its own attempt, up to the account's real Beans bound. This bolt does not re-litigate that accepted risk — it only adds a new, independent check on the timestamp dimension.

### NFR Implementation

- **Reliability (never double-award)**: idempotency-first ordering (API Design step 1); re-verified against delayed (not just near-immediate) replay in the Test stage, per story 003's acceptance criteria.
- **Performance (no N+1 on content version)**: one `MAX()` aggregate query per skill-tree fetch, not a per-skill/per-lesson round trip — matches the existing query-count performance test pattern from bolt 007, which will be extended (not replaced) to also cover this new field.
- **No regression**: `002-core-lesson-loop`'s full existing backend suite (215/215 as of bolt 005) is re-run in full during Test, since this bolt touches shared endpoints/logic that suite already covers.

### Integrations

No new integrations. Same FastAPI app, same PostgreSQL database (SQLite for local dev/test, per `data-stack.md`), same session-token auth dependency as every other `001-lesson-service` endpoint.
