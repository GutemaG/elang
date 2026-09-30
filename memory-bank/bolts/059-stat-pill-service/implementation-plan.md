---
stage: plan
bolt: 059-stat-pill-service
created: '2026-09-30T06:37:35Z'
---

## Implementation Plan: stat-pill-service

### Objective

Two read-only endpoints for the signed-in learner, from rows the backend
already keeps (no table, no migration, no Neon change):

- the practised days in a date range, with the current and longest streak
  (story 001-streak-history-read, FR-4);
- the most recent Amole ledger entries (story 002-amole-history-read,
  FR-6).

### What the code says (checked before planning)

- **F1: Replays are lesson attempts too, but not streak days.** Replaying
  a completed skill (a review) adds a `lesson_attempts` row with
  `xp_awarded` 0 and `result.is_review` true, and leaves the streak alone.
  So "a day with any attempt" would mark days the streak never counted.
  `is_review` lives only inside the `result` JSON; rows from before
  reviews existed lack it (and were never reviews).
- **F2: The day rule.** The streak uses `client_completed_at.date()`; the
  app always sends UTC (`toUtc().toIso8601String()`), and the row keeps it
  as `completed_at`. So a practised day is the UTC date of `completed_at`.
- **F3: The pill's streak can be out of date.** The dashboard shows
  `user_streaks.current_streak` as stored. It only resets at the next
  finished lesson, so a learner who stopped a week ago still sees their
  old number until they finish one. The calendar will show the gap under
  that number. Not in this bolt's scope (see Question Q1).
- **F4: No longest streak is stored; freezes are never granted**, so a
  run is plain consecutive dates.
- **F5: The app needs the join date** to show days before the account as
  "not possible" (FR-3). `User.created_at` has it; nothing returns it yet.
- **F6: Amole.** `amole_transactions` has `amount`, `source`,
  `reference_id`, `created_at` and an index on `user_id`. The repository
  only adds rows and sums them.
- **F7: Patterns.** Routes in `lesson_routers.py` with `get_current_user`;
  use cases in `app/application`; Protocol repositories with SQLAlchemy
  versions and in-memory fakes in `tests/fakes.py`; query counts are
  checked with a `before_cursor_execute` listener
  (`tests/performance`). There is no hand-written API document; the
  OpenAPI schema is FastAPI's own.

### Decisions

- **D1: `GET /api/v1/streak/history?from=YYYY-MM-DD&to=YYYY-MM-DD`**
  ```json
  {
    "from": "2026-04-01", "to": "2026-09-30",
    "practised_days": ["2026-09-28", "2026-09-29"],
    "current_streak": 2, "longest_streak": 9,
    "joined_on": "2026-03-14"
  }
  ```
  - Both dates required; `from` after `to`, or more than 186 days
    inclusive, is 422 `invalid_range`.
  - `practised_days` sorted, within the range, UTC dates.
  - `current_streak` is the stored value, the same number the pill shows
    (F3). `longest_streak` is the longest run over **all** practised days,
    and never less than `current_streak`.
  - `joined_on` is the UTC date of `User.created_at` (F5).
- **D2: Reviews do not count (F1).** A practised day has at least one
  attempt that is not a review. The query reads `completed_at` and
  `result["is_review"]` through SQLAlchemy's JSON accessor (portable
  between SQLite and Postgres); a missing key counts as not a review.
- **D3: Two queries, whatever the range.** One for the learner's attempt
  times and review flags (by the existing `(user_id, completed_at)`
  index), one for the streak row. Dates, the range and the longest run are
  worked out in Python. Rows are one small pair per finished lesson, so
  reading all of them for the longest run stays cheap.
- **D4: `GET /api/v1/amole/transactions?limit=20`**
  ```json
  { "entries": [ { "amount": -350, "source": "bean_refill",
                   "created_at": "2026-09-30T06:00:00+00:00" } ] }
  ```
  - `limit` 1-50, default 20; outside that is 422 (FastAPI's own check).
  - Newest first; ties broken by `id` so the order is stable. One query.
  - `source` is the raw ledger value; the app words it (bolt 061).
- **D5: Where the code goes.**
  - Domain: `longest_streak(days)` as a pure function beside the streak
    policy in `domain/lesson/services.py`.
  - Repositories: `LessonAttemptRepository.list_practised_days(user_id)`
    and `AmoleTransactionRepository.list_recent(user_id, limit)`, with
    SQLAlchemy versions and fakes.
  - Use cases: `get_streak_history` and `get_amole_history` in a new
    `application/stat_use_cases.py`.
  - Routes and schemas: `lesson_routers.py` and `lesson_schemas.py`,
    beside `/beans`.

### Question for you

- **Q1 (F3): the stale streak number.** Should the pill (and this
  endpoint's `current_streak`) show 0 once a day is missed, instead of the
  stored number? It is a small change in how the skill tree reports the
  streak, but it changes what learners see today, so it is not in this
  bolt unless you say so. My suggestion: a separate small bolt after 061.
  - *Answered 2026-09-30: left for a later bolt, as suggested.*

### Out of scope

- Any write, table or migration; storing a longest streak; freezes.
- The app side (bolt 061).

### Tests

- Unit: `longest_streak` (empty, one day, gaps, unsorted, duplicates).
- Use cases with fakes: range checks, reviews excluded, days outside the
  range left out but counted for the longest run, `longest >= current`,
  join date, an empty learner; Amole order, limit, empty.
- Integration (SQLite): both endpoints end to end with real rows,
  including a review-only day, rows without `is_review`, another
  learner's rows, 401 without a session, 422 for bad ranges and limits.
- Query count: the streak read makes the same number of queries for a
  1-day and a 186-day range, and with 1 or 200 attempts; the Amole read
  makes one.

### Acceptance criteria

- **A. Streak history**
  - [ ] Practised UTC dates in the range, sorted, reviews excluded.
  - [ ] `current_streak` as stored; `longest_streak` over all days, never
    less than current; `joined_on`.
  - [ ] 422 for a reversed or over-186-day range; 401 without a session.
  - [ ] No attempts: empty list, 0 and 0.
  - [ ] Constant query count.
- **B. Amole history**
  - [ ] Up to `limit` entries (default 20, max 50), newest first, stable.
  - [ ] Own rows only; 401 without a session; 422 for a bad limit.
  - [ ] One query.
- **C. Checks**
  - [ ] `ruff`, `mypy` (as the project runs them) and `pytest` pass.

---

## Implementation Notes (Stage 2)

Plan approved 2026-09-30; Q1 (the out-of-date streak number) left for a
later bolt.

### New

- **`app/application/stat_use_cases.py`**: `get_streak_history` (range
  checks, practised days in the range, stored current streak, longest run
  over all days and never below current, join date) and
  `get_amole_history`. `STREAK_HISTORY_MAX_DAYS = 186`.
- **`InvalidRangeError`** (`invalid_range`, 422) in
  `domain/lesson/exceptions.py`, mapped in `error_handlers.py`.
- **`longest_streak(days)`** in `domain/lesson/services.py`.

### Changed

- **Repositories** (Protocol, SQLAlchemy, fakes):
  - `LessonAttemptRepository.list_practised_days(user_id)`: one query for
    `completed_at` and `result["is_review"]`; UTC dates worked out in
    Python.
  - `AmoleTransactionRepository.list_recent(user_id, limit)`: newest
    first, ties by `id`.
- **Routes** in `lesson_routers.py`: `GET /api/v1/streak/history`
  (`from`/`to` query dates; `from` is a Python keyword, so the parameter
  is `start` with alias `from`, and the response field `from_` is sent as
  `from`), and `GET /api/v1/amole/transactions` (`limit` 1-50, default
  20). Schemas in `lesson_schemas.py`.

### Found while testing

- **SQLite hands the review flag back as `1`/`0`**, not `true`/`false`
  (`JSON_QUOTE(JSON_EXTRACT(...))` of a JSON boolean). The first version
  checked `is not True` and counted review-only days; the integration test
  caught it. It now checks truthiness, which is right for SQLite's `1`/`0`
  and Postgres's booleans alike.

### Tests (+35)

- `tests/unit/test_stat_use_cases.py` (19): `longest_streak`; the streak
  history (sorted days, reviews left out, a review beside a lesson, other
  learners, the longest run outside the range, longest >= current, empty,
  one day, 186 days, 187 rejected, backwards rejected); the Amole history
  (order and limit, own rows, empty).
- `tests/integration/test_stat_endpoints.py` (13): both endpoints over
  real SQLite rows, including a row without `is_review`, a review-only
  day, another learner, a new learner, 186 vs 187 days, missing and
  malformed dates, the limit and its default, stable ties, 422 limits, and
  401 without a session.
- `tests/performance/test_stat_performance.py` (3): the streak read is 2
  queries for 1 or 186 days and for 1 or 201 attempts; the Amole read is 1.

## Checks (Stage 2)

- `ruff check` and `ruff format --check`: clean.
- `mypy app`: 4 errors, all in code this bolt did not touch
  (`services.py` crown level, `audio_link_checker.py`,
  `lesson_repositories.py` vocab lookup, `admin_routers.py`); none in the
  new code.
- `pytest`: 1334 passed.
- No migration, no Neon change, no seed change.

---

## Test Report (Stage 3)

Implement approved 2026-09-30.

### Runs

| Suite | Result |
|---|---|
| `ruff check app tests` | clean |
| `mypy app` | the same 4 errors in untouched code; none in this bolt's |
| `pytest` (whole backend) | 1334 passed |
| The three new test files, repeated | 35 passed, 3 of 3 runs |

### Acceptance criteria

- **A. Streak history** (`test_stat_use_cases.py`,
  `test_stat_endpoints.py`, `test_stat_performance.py`)
  - [x] Practised UTC dates in the range, sorted, reviews excluded.
  - [x] `current_streak` as stored; `longest_streak` over all days, never
    less than current; `joined_on`.
  - [x] 422 for a reversed or over-186-day range; 401 without a session.
  - [x] No attempts: empty list, 0 and 0.
  - [x] Constant query count (2).
- **B. Amole history**
  - [x] Up to `limit` entries (default 20, max 50), newest first, stable.
  - [x] Own rows only; 401 without a session; 422 for a bad limit.
  - [x] One query.
- **C. Checks**
  - [x] `ruff` and `pytest` pass; `mypy` has nothing new.

### Not covered here

- Postgres (Neon) was not run: the tests use SQLite. The review flag is
  read by truthiness so either database's form works, and the query is
  plain SQLAlchemy with no SQL of its own. It is first exercised on Neon
  when the backend is next deployed.
- Nothing in the app calls these reads yet; bolt 061 does.
