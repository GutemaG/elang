---
unit: 001-lesson-service
bolt: 005-lesson-engagement-service
stage: design
status: complete
created: 2026-09-16T12:20:00Z
---

# Technical Design - Lesson Engagement Service

## Architecture Pattern

Same layered architecture as bolts `001`/`004`, same `app/domain/lesson/` bounded context (extended, not a new subpackage — beans/streak/XP are the same context's write-side, not a separate one). Application layer gains new functions in the existing `app/application/lesson_use_cases.py`. Infrastructure: `db/lesson_models.py`/`lesson_repositories.py` gain new tables/repos; `api/lesson_schemas.py`/`lesson_routers.py` gain new endpoints. One new Alembic migration.

## Resolving the ADR-4 / NFR Conflict (see Domain Model Stage 1)

**Decision (formalized as ADR-5, superseding ADR-4's "never expose `answer_key`" clause):** the `GET /lessons/{lesson_id}` response (bolt `004`) is amended to include each exercise's correct-answer data (`correct_choice_id` for `multiple_choice`/`listening`, `correct_sequence` for `sentence_construction`), so the client can grade every answer instantly, locally, with zero network calls per exercise — satisfying `requirements.md`'s Performance NFR, which bolt `004`'s ADR-4 did not check itself against. Grading itself therefore moves entirely client-side; this bolt never re-grades individual submitted answers server-side (there is no `SubmitExerciseAnswer` endpoint — that per-exercise operation, as originally sketched in the unit brief, is exactly the "network call per exercise" the NFR forbids, so it's dropped in favor of the design below).

**What's kept from ADR-4's intent despite this:** the account *ledger* (Beans actually consumed, XP actually awarded) is never computed from a bare client-asserted number without a bound — `POST /lessons/{lesson_id}/complete` (below) rejects a completion whose implied wrong-answer count exceeds the user's actual server-side beans balance at attempt start (see Decision 2), so a buggy or adversarial client can't manufacture beans/XP out of thin air, even though it *can* see (and could report) the correct answers. This is judged an acceptable trade-off for a non-monetized, single-player educational feature (no PvP, no real-money economy — see `requirements.md` Constraints) — full per-exercise server-side re-grading was considered and rejected as disproportionate cost for the integrity it would add on top of the bound already enforced. Flagged here as revisitable if a competitive or monetized feature is ever added.

`adr-4-server-side-only-answer-keys.md`'s frontmatter is updated (`superseded_by: adr-5-client-side-grading-with-bounded-server-ledger.md`) as part of this bolt; its historical rationale is left intact.

## Layer Structure (additions)

```text
┌──────────────────────────────────────────────────────────────┐
│  Presentation (app/infrastructure/api)                        │
│    lesson_routers.py (+): GET /api/v1/beans                   │
│                            POST /api/v1/beans/refill           │
│                            POST /api/v1/lessons/{id}/complete  │
│    (skill-tree endpoint's response extended, see API Design)   │
├──────────────────────────────────────────────────────────────┤
│  Application (lesson_use_cases.py, +)                          │
│    get_beans_status, refill_beans, complete_lesson              │
│    get_skill_tree (extended: + beans/streak/xp aggregation)     │
├──────────────────────────────────────────────────────────────┤
│  Domain (app/domain/lesson/, extended)                          │
│    UserBeans, UserStreak, LessonAttempt entities                │
│    BeanLedger, StreakPolicy, LessonCompletionService             │
├──────────────────────────────────────────────────────────────┤
│  Infrastructure (app/infrastructure/db)                         │
│    lesson_models.py (+): UserBeansModel, UserStreakModel,        │
│                           LessonAttemptModel                     │
│    lesson_repositories.py (+): matching repo implementations     │
│    Alembic migration                                             │
└──────────────────────────────────────────────────────────────┘
```

## API Design

All endpoints require `Authorization: Bearer {session_token}` via the existing `get_current_user` dependency (unchanged from bolt `004`).

| Endpoint | Method | Request | Response | Status |
|----------|--------|---------|----------|--------|
| `/api/v1/skill-tree` | GET | — | **Extended** (see below) | 200, 401 |
| `/api/v1/lessons/{lesson_id}` | GET | — | **Extended**: each exercise now also carries its correct-answer field(s) | 200, 401, 403, 404 |
| `/api/v1/beans` | GET | — | `{ "beans": int, "beans_max": int, "next_bean_at": string\|null, "regen_minutes_per_bean": int, "amole_balance": int, "refill_cost_amole": int }` | 200, 401 |
| `/api/v1/beans/refill` | POST | — | `{ "beans": int, "amole_balance": int }` | 200, 401, 422 (`insufficient_amole`) |
| `/api/v1/lessons/{lesson_id}/complete` | POST | `{ "attempt_id": string, "correct_count": int, "total_count": int, "time_spent_seconds": number }` | `{ "xp_earned": int, "daily_xp_total": int, "daily_xp_target": int, "streak_count": int, "streak_increased_today": bool, "accuracy_percent": int, "correct_count": int, "total_count": int, "time_spent_seconds": number, "skill_unlocked_title": string\|null, "crown_level": int\|null, "crown_leveled_up": bool, "streak_freeze_unlocked": bool }` | 200, 401, 404 (`lesson_not_found`), 422 (`beans_exhausted`) |

Field names are deliberately close to the already-built Flutter `BeansStatus`/`LessonCompletionResult`/`RefillResult` models (snake_case ↔ camelCase) so bolt `007`'s wire mapping is mechanical, not a redesign.

### Skill-tree response, extended

```jsonc
{
  "unit_title": "Unit 1: Foundations & Greetings",   // Decision 4
  "unit_subtitle": "ሰላምታ እና ፊደል መግቢያ",
  "skills": [ /* unchanged from bolt 004 */ ],
  "streak_count": 6,
  "beans": 5,
  "beans_max": 5,
  "total_xp": 240
}
```

### Lesson-content response, extended (per-exercise, amending bolt `004`)

```jsonc
// type: "multiple_choice" / "listening" — adds correct_choice_id
{ "id": "...", "type": "multiple_choice", "prompt": "...", "choices": [...], "correct_choice_id": "a" }
// type: "sentence_construction" — adds correct_sequence
{ "id": "...", "type": "sentence_construction", "prompt": "...", "word_bank": [...], "correct_sequence": ["w2", "w1"] }
```

### Decision 1: `complete_lesson` trusts, but bounds, the client's reported result

Covered above (ADR-5). Implementation: `wrong_count = total_count - correct_count`; before any state change, load+regenerate `UserBeans`, and if `wrong_count > current_beans` reject with `beans_exhausted` (422) — the attempt implies more mistakes than the account could have afforded, so it must have been interrupted and is not completable (story 003 AC5, story 002's beans-exhaustion rule, enforced server-side as a bound rather than trusted client state).

### Decision 2: Idempotency via a client-generated `attempt_id`

No server-side "in-progress attempt" concept exists (grading is client-side — Decision above), so there's nothing for the server to hand back an id for at lesson start. Instead, `LessonController` (Flutter, amended — see Cross-Cutting Amendments) generates a random opaque `attempt_id` once, at lesson start, kept for the lifetime of that attempt including any completion retries. `POST /complete` first checks `LessonAttemptRepository.get(attempt_id)`; if a row already exists, its stored result is returned unchanged (no re-grading, no double beans/XP) — this is the exactly-once mechanism story 003 requires, without needing a separate "start attempt" round trip (which would itself be a network call the lesson-start flow doesn't otherwise need).

### Decision 3: Beans/XP/Amole constants

| Constant | Value | Rationale |
|----------|-------|-----------|
| `BEANS_MAX` | 5 | Matches the Highland Pulse design's 5-heart HUD and every existing Flutter fixture (`beansMax: 5`). |
| `BEAN_REGEN_MINUTES` | 30 | Matches the existing Flutter test fixtures (`regenMinutesPerBean: 30`); a full refill from 0 takes 2.5 hours, generous enough not to feel punishing per the "non-punishing cost" business goal. |
| `XP_PER_CORRECT_ANSWER` | 5 | A perfect 4-exercise lesson (bolt `004`'s seed shape) = 20 XP, exactly matching the lowest `daily_xp_target` preset (`MINUTES_TO_XP_TARGET[5] = 20`, `001-auth-onboarding`) — one perfect lesson meets the "Casual" daily goal; the "Intense" preset (80) needs 4. |
| `REFILL_COST_AMOLE` | 350 | Matches the existing Flutter test fixture. |
| `STARTING_AMOLE_BALANCE` | 500 | New-user default (row absent = this default, same absence-is-meaningful pattern as `UserSkillProgress`) — enough headroom for one refill without requiring any other Amole-earning mechanic in this intent's scope. |
| `FREEZE_GRANTED_AT_CROWN_LEVEL` | 5 | Matches the already-built `FakeLessonApi`'s documented mechanic ("replay increments crown level, capped at 5, unlocking a streak freeze at 5") — this bolt mirrors it exactly rather than inventing a different mechanic, resolving story 004's "how are freezes earned" open question consistently with already-shipped UI behavior. |

### Decision 4: "Unit" banner is a fixed constant, not a modeled aggregate

`SkillTreeResponse.unit_title`/`unit_subtitle` (Flutter, already built) has no corresponding domain concept in bolt `004`'s flat `Skill` list (no grouping/chapter entity exists). Introducing a full `Unit` aggregate for a 2-skill proof-of-loop curriculum (`requirements.md`'s explicit "not a complete Phase 1 course" scope note) is disproportionate. Returned as a fixed constant, `"Unit 1: Foundations & Greetings"` / `"ሰላምታ እና ፊደል መግቢያ"` — identical text to the existing `FakeLessonApi`'s hardcoded value, so swapping to the real backend in bolt `007` changes nothing visible. Revisit if a future intent introduces a real multi-unit curriculum structure.

### Decision 5: Calendar day = UTC

Streak day-boundary and "today's" XP total both use UTC calendar dates (`completed_at`'s date component in UTC), per story 004's explicit open item — no per-user timezone tracking exists anywhere in this codebase yet, and inventing one for this bolt alone would be scope creep beyond what any story asks for.

### Error Codes (new)

| `error_code` | HTTP Status | Meaning |
|---|---|---|
| `beans_exhausted` | 422 | The completion's implied wrong-answer count exceeds the account's actual beans balance — the attempt should have been interrupted, not completed |
| `insufficient_amole` | 422 | Refill attempted without enough Amole balance |

## Data Model

Three new tables (summarized; full definitions in `database-schema.md`):

| Table | Columns | Relationships |
|-------|---------|----------------|
| `user_beans` | `user_id` (PK, FK `users.id`), `current_count`, `last_regen_at`, `amole_balance`, `created_at` | One row per user, created lazily on first write (refill or lesson completion that consumes a bean); absence = full beans + `STARTING_AMOLE_BALANCE`. |
| `user_streaks` | `user_id` (PK, FK `users.id`), `current_streak`, `last_completed_date` (nullable date), `active_freeze_count`, `created_at` | One row per user, created lazily on first completion; absence = streak 0. |
| `lesson_attempts` | `id` (PK, client-supplied `String(64)`), `user_id` (FK), `lesson_id` (FK), `correct_count`, `total_count`, `xp_awarded`, `completed_at`, `created_at` | Index on `(user_id, completed_at)` for the daily/lifetime XP sum queries. `id` is the idempotency key — never server-generated. |

`user_skill_progress` (bolt `004`) is unchanged in shape; this bolt is its first writer.

## Security Design

| Concern | Approach |
|---------|----------|
| Authentication | Reuses `get_current_user` unchanged. |
| Ledger integrity | Beans/XP are never taken verbatim from the client beyond the bound in Decision 1; idempotency (Decision 2) prevents double-award on retry. |
| Data exposure (amended from ADR-4) | `answer_key`-derived fields are now part of the lesson-content response (ADR-5) — an accepted, documented trade-off, not an oversight. |

## NFR Implementation

| Requirement | Design Approach |
|-------------|-----------------|
| Performance (no network call per exercise) | Achieved precisely *by* moving grading client-side (ADR-5) — this bolt never adds a per-exercise endpoint. |
| Reliability (exactly-once XP) | `LessonAttemptRepository.get(attempt_id)` idempotency check (Decision 2), inside the same transaction as the write. |
| Reliability (no partial-completion state) | XP award, skill-progress write, and streak write all happen in one DB transaction per `coding-standards.md`'s "ledger-affecting endpoints must be transactional" convention (same as `001-auth-service`). |

## Cross-Cutting Amendments to Already-Complete Bolts

- **Bolt `004`** (`lesson_schemas.py`, `lesson_routers.py`, `lesson_use_cases.py`, and their tests): lesson-content response gains `correct_choice_id`/`correct_sequence` fields (ADR-5); skill-tree response/use case gains `unit_title`/`unit_subtitle`/`streak_count`/`beans`/`beans_max`/`total_xp`, requiring the new bolt-`005` repositories as additional `get_skill_tree` dependencies. Bolt `004`'s two tests asserting answer-key absence are updated to assert presence/correctness instead, with a comment pointing at ADR-5 — not silently reversed.
- **Bolt `006`** (`LessonController`, `LessonApi`, `Exercise`/`LessonContent`/`LessonCompletionResult` models, `FakeLessonApi`): `LessonController` generates a random `attemptId` (via `dart:math`'s `Random.secure()`, no new package) at construction and passes it to `completeLesson`; `LessonApi.completeLesson` gains a required `attemptId` parameter. This is additive to the already-built grading logic (which already grades locally using each `Exercise`'s embedded correct-answer field, unaware of and unaffected by where that field originates) — no behavior change to the already-verified requeue/beans/modal flows, confirmed by re-running the full Flutter suite after the change.

## New Open Questions (Not Resolved Here — Flagged for Later)

- Full per-exercise server-side re-grading (dropping the "trust, but bound" approach) if a future intent introduces competitive or monetized elements where the current bound's integrity guarantee is insufficient.
- A real multi-unit curriculum structure (Decision 4) once Phase 1 curriculum authoring is actually scoped.
