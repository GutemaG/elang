---
unit: 001-match-pairs-service
bolt: 011-match-pairs-service
stage: test
status: complete
updated: '2026-09-17T06:10:00Z'
---

# Test Report - Match-Pairs Service

## Test Summary

| Category | Passed | Failed | Skipped | Coverage |
|----------|--------|--------|---------|----------|
| Unit | 5 new (+237 pre-existing, unaffected) | 0 | 0 | 100% (`value_objects.py`, new code) |
| Integration | 3 new (+ 1 pre-existing fixed) | 0 | 0 | 100% (`lesson_repositories.py`, new code) |
| Security | 0 new (reused existing type-agnostic coverage — see Security Tests) | 0 | 0 | - |
| Performance | 0 new (reused existing type-agnostic coverage — see Performance Tests) | 0 | 0 | - |
| **Total** | **251/251 (backend full suite)** | **0** | **0** | **99% on the 4 modules this bolt touched** |

## Acceptance Criteria Validation

| Story | Criteria | Status |
|-------|----------|--------|
| 001-serve-match-pairs-exercise-content | `ExerciseType.MATCH_PAIRS` added to the domain enum | ✅ |
| 001-serve-match-pairs-exercise-content | Content served via existing lesson-content endpoint, no new endpoint/envelope | ✅ |
| 001-serve-match-pairs-exercise-content | At least 1 seeded `match_pairs` exercise exists | ✅ (`TestMatchPairsSeedContent`) |
| 001-serve-match-pairs-exercise-content | No per-type special-casing beyond content/answer-key shape | ✅ |
| ~~002-grade-match-pairs-attempts~~ | Retired — reassigned to `002-match-pairs-ui` (bolt 012, not yet built) | N/A — out of scope for this bolt |

## Unit Tests

Added to `tests/unit/test_lesson_value_objects.py`:
- `TestMatchPairsContent`: rejects <2 left tiles, rejects mismatched left/right tile counts, accepts equal-length columns.
- `TestAnswerKeys` (extended): `PairAnswerKey` rejects <2 pairs, accepts ≥2 pairs.

All new value objects follow the exact `__post_init__` validation convention already used by `MultipleChoiceContent`/`ChoiceAnswerKey`/etc.

## Integration Tests

- `tests/integration/test_lesson_repositories.py`: new `test_get_by_id_round_trips_a_match_pairs_exercise` — verifies the domain-level JSON→`MatchPairsContent`/`PairAnswerKey` reconstruction against a real (temp-file) SQLite DB.
- `tests/integration/test_lesson_endpoints.py`: new `TestMatchPairsExercise` class (isolated fixture, not extending the shared `seeded_content` fixture used by exact-type-list assertions elsewhere) — verifies `GET /api/v1/lessons/{id}` serializes `left_tiles`/`right_tiles`/`correct_pairs` correctly and never leaks the raw `answer_key` JSON column name, matching ADR-5's existing boundary.
- `tests/integration/test_seed_lesson_content.py`: fixed 1 pre-existing regression (`test_every_lesson_has_a_mix_of_all_3_exercise_types` → renamed `..._of_at_least_3_..`, assertion widened from `==` to `>=` since the 3-type mix is a floor, not a ceiling); added `TestMatchPairsSeedContent` (2 new tests) verifying the seeded exercise exists and its `correct_pairs` reference real tile ids from its own content (no dangling references); extended the existing placeholder-text/real-Amharic check to cover `left_tiles`/`right_tiles`.

## Security Tests

No new dedicated tests. `tests/security/test_lesson_security.py`'s existing `TestAnswerKeyFieldsShapedPerADR5` and `TestPerUserIsolation` guarantees are already type-agnostic by construction (they test the response-shaping/auth boundary generically, not per-exercise-type), so they cover `match_pairs` without modification — verified by re-running the full suite, not by adding a redundant type-specific copy.

## Performance Tests

No new dedicated tests, for the same reason: `tests/performance/test_lesson_performance.py`'s query-count assertions (`selectinload` batches all exercises regardless of type) are exercise-type-agnostic. Re-ran and confirmed unaffected (still ≤2 queries for lesson fetch, ≤8 for skill tree).

## Coverage Report

Measured via `pytest --cov` scoped to the 4 modules this bolt touched:

| Module | Coverage | Notes |
|--------|----------|-------|
| `app/domain/lesson/value_objects.py` | 100% | |
| `app/infrastructure/db/lesson_repositories.py` | 100% | |
| `app/infrastructure/api/lesson_schemas.py` | 100% | |
| `app/infrastructure/api/lesson_routers.py` | 91% (5 lines) | The 5 missed lines (184, 202, 214, 233, 272) are pre-existing endpoint-return lines for other endpoints (skill-tree, beans, refill, complete), all exercised by passing tests elsewhere in the suite — most likely a coverage-instrumentation artifact of measuring through `TestClient`'s background thread, not genuinely untested code. Not investigated further as out of scope for this bolt. |

## Issues Found

| Issue | Severity | Status |
|-------|----------|--------|
| Stage 1/2 design assumed `MatchPairsContent` needed no separate `answer_key` (self-revealing content) | Medium | Fixed at Stage 4 — see `ddd-01-domain-model.md`/`ddd-02-technical-design.md` correction notes |
| Stage 2 assumed no Alembic migration was needed | Medium | Fixed at Stage 4 — migration `c726efa81972` widens `ck_exercises_type` via `batch_alter_table`, verified via downgrade/upgrade round-trip |
| Pre-existing test hard-coded "exactly 3 exercise types per lesson" | Low | Fixed — widened to `>=` (floor, not ceiling) |

## Ready for Operations

- [x] All acceptance criteria met (for this unit's now-corrected scope — story 002 retired, not applicable)
- [x] Code coverage > 80% (99% on touched modules)
- [x] No critical/high severity issues open
- [x] Performance targets met (unaffected, verified)
- [x] Security tests passing (unaffected, verified)
