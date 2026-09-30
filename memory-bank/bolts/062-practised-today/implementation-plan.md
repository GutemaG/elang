---
stage: plan
bolt: 062-practised-today
created: '2026-09-30T08:44:00Z'
---

## Implementation Plan: practised-today

### Objective

Story 001 (FR-6): `GET /api/v1/skill-tree` says whether today's UTC streak
day is already practised, so the app can cancel that evening's reminder
after a lesson finished on another device.

### What the code says (checked before planning)

- **F1: The streak row is already read.** `get_skill_tree`
  (`application/lesson_use_cases.py`) loads `streak_repo.get(user_id)` for
  `streak_count`, and it already takes `now`. `UserStreak` has
  `last_completed_date` (a UTC date).
- **F2: Only lessons that count write that date.** `complete_lesson`
  upserts the streak with the completion's UTC date; `_complete_review`
  only reads the streak; Practice sessions don't touch it. So
  `last_completed_date == today` is exactly the streak's own rule.
- **F3: The skill tree has a query-count test**
  (`tests/performance/test_lesson_performance.py`), which stays as it is.
- **F4: There is no separate API notes file** for these routes; the
  schema is the contract.

### Decisions

- **D1:** `SkillTreeSummary.practised_today: bool`, set to
  `streak.last_completed_date == now.astimezone(UTC).date()`.
- **D2:** `SkillTreeResponse.practised_today: bool = False`: a new field
  with a default, so nothing that builds the response elsewhere breaks and
  old clients ignore it.
- **D3:** No new query and no migration. The app side (reading the field,
  keeping it in the saved dashboard) is bolt 063.

### Tests

- Unit (`get_skill_tree` with fakes): a new learner → false; last lesson
  today → true; yesterday → false; `now` just after midnight UTC with a
  lesson just before it → false (the day rolled over).
- Integration (HTTP): complete a lesson, then the skill tree says true;
  a learner with only a review attempt → false.
- The existing query-count test passes unchanged.

### Acceptance criteria

- [ ] `practised_today` true exactly when a non-review lesson was
  completed on today's UTC date.
- [ ] False for a new learner, yesterday, a review only.
- [ ] No extra query.
- [ ] `ruff`, `mypy` (no new errors) and `pytest` pass.

---

## Implementation Notes (Stage 2)

Plan approved 2026-09-30.

### Changed

- **`app/application/lesson_use_cases.py`**: `SkillTreeSummary` gains
  `practised_today: bool = False`; `get_skill_tree` sets it to
  `streak.last_completed_date == now.astimezone(UTC).date()`, using the
  streak row it already reads.
- **`app/infrastructure/api/lesson_schemas.py`**:
  `SkillTreeResponse.practised_today: bool = False`.
- **`app/infrastructure/api/lesson_routers.py`**: passes it through.

No new query, table or migration; as planned.

### Tests (+7)

- `tests/unit/test_lesson_use_cases.py`, `TestPractisedToday` (5): a new
  learner; a lesson today; yesterday; one second after midnight UTC; and
  01:30 in Addis Ababa on the 17th, still the 16th in UTC.
- `tests/integration/test_lesson_engagement_endpoints.py` (2): false, then
  true after finishing a lesson; a lesson two days ago plus a review today
  stays false.
- The skill tree's query-count test passes unchanged.

## Checks (Stage 2)

- `uv run ruff check app tests`: clean; `ruff format --check`: clean.
- `uv run mypy app`: the same 4 errors as before, all in untouched files.
- `uv run pytest`: 1341 passed (was 1334).

---

## Test Report (Stage 3)

Implement approved 2026-09-30.

### Runs

| Suite | Result |
|---|---|
| `uv run pytest` (full) | 1341 passed |
| This bolt's files plus the skill tree and performance tests, repeated | 42 passed, 3 of 3 runs |
| `uv run ruff check app tests`, `ruff format --check` | clean |
| `uv run mypy app` | the same 4 errors as before, in untouched files |

### Acceptance criteria

- [x] `practised_today` true exactly when a non-review lesson was
  completed on today's UTC date (unit: today, the UTC midnight rollover,
  a time zone ahead of UTC; integration: after a real completion).
- [x] False for a new learner, yesterday, a review only (unit and
  integration).
- [x] No extra query (the query-count test is unchanged and passes).
- [x] `ruff`, `mypy` (no new errors) and `pytest` pass.

### Not covered here

- The app reading the field and keeping it in the saved dashboard: bolt
  063.
- Neon: nothing to do, since there is no migration; the field appears when
  the backend is deployed.
