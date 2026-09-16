---
unit: 001-lesson-service
bolt: 004-lesson-content-service
stage: test
status: complete
updated: 2026-09-16T11:00:00Z
---

# Test Report - Lesson Content Service

## Test Summary

| Category | Passed | Failed | Skipped | Coverage |
|----------|--------|--------|---------|----------|
| Unit | 88 | 0 | 0 | 100% (lesson-content domain + application layers) |
| Integration | 44 | 0 | 0 | 100% (lesson db/repositories, lesson db/models); endpoint routes exercised end-to-end |
| Security | 9 | 0 | 0 | - |
| Performance | 4 | 0 | 0 | - |
| **Total** | **145** | **0** | **0** | **81% of `app/` overall; 100% of lesson-content-logic-bearing modules (see Coverage Report)** |

Of the 145 total, 76 (45 unit / 23 integration / 6 security / 2 performance) are `001-auth-service`'s pre-existing suite, unmodified except for two additive, non-behavioral extensions: `tests/conftest.py`'s `make_client` factory now also registers the new lesson router (needed so lesson-endpoint integration tests can use the same fixture), and `tests/fakes.py` gained 3 new fake lesson repositories alongside the existing auth fakes. The remaining 69 (43 unit / 21 integration / 3 security / 2 performance) are new, written for this bolt.

Command run: `uv run pytest --cov=app --cov-report=term-missing` (from `backend/`). All 145 tests pass on a clean run.

## Acceptance Criteria Validation

| Story | Criteria | Status |
|-------|----------|--------|
| 001-serve-skill-tree-and-lesson-content | AC1: signed-in user's skill tree returns all skills with accurate per-skill state and crown level | ✅ `test_skill_tree_progression_policy.py` (domain), `test_lesson_use_cases.py::TestGetSkillTree`, `test_lesson_endpoints.py::TestSkillTreeEndpoint` |
| 001-serve-skill-tree-and-lesson-content | AC2: a skill with no prior progress is `locked` unless it's the first skill, which is `active` by default | ✅ `test_skill_tree_progression_policy.py::TestSkillTreeProgressionPolicyNewUserBootstrap` (3 tests incl. out-of-order input), `test_lesson_endpoints.py::TestSkillTreeEndpoint::test_new_user_sees_first_skill_active_and_rest_locked` |
| 001-serve-skill-tree-and-lesson-content | AC3: an active/completed skill's lesson content returns the full ordered exercise list (prompts, choices/word-bank/audio URL) in one response | ✅ `test_lesson_repositories.py::TestSqlAlchemyLessonRepository::test_get_by_id_loads_lesson_with_all_3_exercise_types_ordered`, `test_lesson_endpoints.py::TestLessonContentEndpoint::test_returns_full_ordered_exercise_list_in_one_request` |
| 001-serve-skill-tree-and-lesson-content | AC4: a locked skill's lesson is rejected even by direct lesson ID | ✅ `test_skill_tree_progression_policy.py::TestLessonAccessPolicy`, `test_lesson_use_cases.py::test_raises_skill_locked_for_a_lesson_whose_skill_is_locked`, `test_lesson_endpoints.py::test_locked_skills_lesson_is_unreachable_by_direct_id` |
| 001-serve-skill-tree-and-lesson-content | Edge case: brand-new user, zero progress rows, still gets a correct skill tree computed on the fly | ✅ Covered by the new-user bootstrap tests above (no pre-seeded progress row is ever inserted for those cases) |
| 001-serve-skill-tree-and-lesson-content | Edge case: nonexistent lesson ID → clear 404, not a crash | ✅ `test_lesson_use_cases.py::test_raises_lesson_not_found_for_unknown_lesson_id`, `test_lesson_endpoints.py::test_unknown_lesson_id_returns_404` |
| 001-serve-skill-tree-and-lesson-content | Edge case: expired/invalid session token → same auth-failure behavior as existing auth endpoints | ✅ `test_get_current_user.py` (direct, all branches), `test_lesson_endpoints.py::TestSkillTreeAuthentication`, `test_lesson_security.py` (session isolation) |
| 001-serve-skill-tree-and-lesson-content | Technical Design Decision 1: answer keys never exposed in the lesson-content payload (ADR-4) | ✅ `test_lesson_endpoints.py::test_never_includes_answer_key_data_in_the_response`, `test_lesson_security.py::TestAnswerKeyNeverLeaked` |
| 005-seed-curriculum-content | AC1: at least 2 skills exist, each with multiple lessons | ✅ `test_seed_lesson_content.py::test_seeds_at_least_2_skills_each_with_multiple_lessons` |
| 005-seed-curriculum-content | AC2: every seeded lesson contains a mix of all 3 exercise types | ✅ `test_seed_lesson_content.py::test_every_lesson_has_a_mix_of_all_3_exercise_types` |
| 005-seed-curriculum-content | AC3: content is real, correct English→Amharic vocabulary, not placeholder text | ✅ `test_seed_lesson_content.py::test_content_is_real_amharic_fidel_script_not_placeholder_text` (checks for lorem-ipsum markers and verifies genuine Ethiopic-script characters) |
| 005-seed-curriculum-content | AC4: listening exercises include a valid audio URL (R2 or documented local/dev equivalent) | ✅ `test_seed_lesson_content.py::test_listening_exercises_include_a_documented_placeholder_audio_url` -- see Issues Found below re: real R2 |
| 005-seed-curriculum-content | Edge case: seed script run twice → no duplicates, no crash | ✅ `test_seed_lesson_content.py::TestSeedIdempotency` (2 tests: identical row counts on re-run; content edits update in place) |
| 005-seed-curriculum-content | Edge case: Amharic Fidel-script text stored/rendered correctly as UTF-8 | ✅ Verified throughout (repository round-trip tests, endpoint response tests) — direct SQLite query during Stage 4 manual verification also confirmed correct UTF-8 storage |

## Unit Tests

88 tests, `tests/unit/` (45 pre-existing auth + 43 new), no DB/HTTP for the new tests -- fakes only at the repository boundary, real domain logic throughout:

- `test_lesson_value_objects.py` (14 tests): `Choice`/`MultipleChoiceContent`/`ListeningContent`/`SentenceConstructionContent` shape invariants (empty id/text, minimum choice/tile counts); `ChoiceAnswerKey`/`SequenceAnswerKey` non-empty constraints and the "sequence may be a strict subset of the word bank" allowance; `CrownLevel` range (0-5) boundaries.
- `test_skill_tree_progression_policy.py` (11 tests): new-user bootstrap (first skill by `order_index` — not input-list order — is active, rest locked, with zero progress rows); progress-row-present branches (`completed_at is None` → active, set → completed with its crown level); a completed first skill does *not* auto-unlock the second (this bolt is read-only, per Stage 1); `state_for_skill` lookup and its `ValueError` for an unmodeled skill id; `LessonAccessPolicy` locked/unlocked branches.
- `test_lesson_use_cases.py` (5 tests): `get_skill_tree`/`get_lesson_content` against fakes — correct entries, per-user isolation at the fake-repository level, `LessonNotFoundError`/`SkillLockedError` propagation.
- `test_get_current_user.py` (5 tests): the new shared `get_current_user` dependency exercised directly (not through `TestClient`) — missing header, non-Bearer header, Bearer-with-empty-token, unknown-token (`InvalidSessionError`), and the valid-token success path; added specifically to get a normal-event-loop cross-check against the endpoint tests, mirroring `001-auth-service`'s own `test_use_cases.py` rationale (see Coverage Report note below).
- `test_lesson_repository_helpers.py` (3 tests): `_ensure_utc`'s naive/aware/already-UTC branches directly.

## Integration Tests

44 tests, `tests/integration/` (23 pre-existing auth + 21 new), real SQLAlchemy models via the actual repository implementations against a fresh temp-file SQLite database per test:

- `test_lesson_repositories.py` (7 tests): `SqlAlchemySkillRepository` ordering-by-`order_index` regardless of insert order, empty-result case, and the `id` default-factory fallback; `SqlAlchemyLessonRepository.get_by_id` loading a lesson with all 3 exercise types in one `selectinload` call, correctly reconstructing each type's `content`/`answer_key` value objects from JSON (ADR-3's actual round trip, not just the domain model's shape); `SqlAlchemyUserSkillProgressRepository`'s timezone round trip through a brand-new session/connection (same discipline as `001-auth-service`'s bug #2 regression test).
- `test_lesson_endpoints.py` (9 tests): full `TestClient` coverage of both new routes, signing in via the **real** `/api/v1/auth/google` endpoint (not a shortcut) to mint a genuine session token — missing/unknown-token 401s, new-user skill-tree bootstrap, full ordered exercise payload with real Amharic content, no-answer-key-leakage, locked-skill 403, unknown-lesson 404, and unauthenticated-request 401.
- `test_seed_lesson_content.py` (6 tests): idempotency (identical counts across 2 runs; content edits apply in place on re-run) and all 4 of story 005's content acceptance criteria directly against the actual `CURRICULUM` data structure and `seed()` function.

## Security Tests

9 tests, `tests/security/` (6 pre-existing auth + 3 new), `test_lesson_security.py`:

- No exercise in a lesson-content response carries `answer_key`/`correct_choice_id`/`correct_sequence` under any field name (ADR-4), verified against the actual JSON response body.
- One user's `UserSkillProgress` row (directly inserted, simulating what bolt `005`'s write path will do) never affects another user's skill-tree view — user A sees `skill-a` as `completed`/crown 1, user B (zero rows) still sees the new-user-bootstrap default (`active`/crown 0) for the same skill.
- Two independent sign-ins produce two independent, non-interchangeable session tokens and user ids (sanity check that `get_current_user` genuinely resolves to the issuing user, not a shared/global session).

## Performance Tests

4 tests, `tests/performance/` (2 pre-existing auth + 2 new). Rather than a wall-clock smoke test, `test_lesson_performance.py` asserts the precise thing the "no per-exercise/per-skill round trip" NFR requires: the number of SQL statements executed via a SQLAlchemy `before_cursor_execute` event listener, not a timing proxy.

| Metric | Target | Actual | Status |
|--------|--------|--------|--------|
| SQL statements to fetch a 20-exercise lesson | ≤ 2 (one for the lesson, one batched `selectinload` for all exercises) — never proportional to exercise count | 2 | ✅ |
| SQL statements to compute a 50-skill skill tree | ≤ 2 (`list_all` skills + `list_by_user` progress) — never one per skill | 2 | ✅ |

**Note on the pre-existing auth performance test**: `tests/performance/test_performance.py::test_repeated_google_auth_requests_complete_within_bound` (from `001-auth-service`, unmodified) failed once during a full-suite run with `--cov` coverage instrumentation active (its own report already flagged this test's wall-clock bound as "generous... varies by run"), and passed cleanly both in isolation and on two subsequent full-suite runs without `--cov`. This is pre-existing timing flakiness under added instrumentation overhead, not a regression introduced by this bolt — nothing in this bolt touches auth's request path.

## Coverage Report

`uv run pytest --cov=app --cov-report=term-missing` results, by module:

| Layer | Modules | Coverage |
|-------|---------|----------|
| Lesson domain | `domain/lesson/entities.py`, `exceptions.py`, `repositories.py`, `services.py`, `value_objects.py` | 100% (147/147 stmts) |
| Lesson application | `application/lesson_use_cases.py` | 100% (18/18 stmts) |
| Lesson API | `infrastructure/api/lesson_dependencies.py`, `lesson_schemas.py`; `dependencies.py` (shared, `get_current_user`) | 100% |
| Lesson API (routers) | `infrastructure/api/lesson_routers.py` | 94% (2 lines: see note below) |
| Lesson DB | `infrastructure/db/lesson_models.py`, `lesson_repositories.py` | 100% (107/107 stmts) |
| **Lesson-content subtotal** | | **~99%** |
| Lesson seed | `infrastructure/db/seed_lesson_content.py` | 89% (missing: the `main()` CLI entrypoint's body, lines 396-400/409 — not exercised by tests, same treatment as `main.py`/bootstrap code below) |
| Pre-existing (unchanged) gaps from `001-auth-service` | `session.py` (33%), `google_verifier.py`/`apple_verifier.py` (0%), `logging_config.py` (0%), `main.py` (0%), `routers.py` (89%, same tail-line artifact) | intentionally out of scope for that bolt, unaffected by this one |
| **Whole `app/` package** | | **81% (857/1062 stmts)** |

**Note on `lesson_routers.py`'s 2 reported-missed lines (118, 134)**: identical, already-documented phenomenon from `001-auth-service`'s own test report — these are the tail `return` statements of the 2 new route handlers, both demonstrably executed (every endpoint test in `test_lesson_endpoints.py` and `test_lesson_security.py` asserts on the exact response body/status those lines produce). `test_get_current_user.py` was added specifically to get a normal-event-loop cross-check of the shared dependency underneath both handlers, following the exact precedent `001-auth-service` set with its `test_use_cases.py` for the same `coverage.py`/thread-tracing artifact under `TestClient`'s background portal thread. This bolt's coverage target (>80% on lesson-content logic) is met either way (~99% including, effectively 100% excluding these 2 lines).

The success criteria's ">80% coverage" target is interpreted the same way `001-auth-service` interpreted it: the domain/application/API/DB layers that implement this bolt's 2 stories (~99%), not the whole `app/` package, which also contains code this stage deliberately does not exercise (external verifiers, bootstrap, and the seed script's CLI entrypoint).

## Issues Found

| Issue | Severity | Status |
|-------|----------|--------|
| Listening-exercise `audio_url` values use a documented, non-functional placeholder scheme (`https://r2-placeholder.buna.dev/audio/<slug>.mp3`) rather than real Cloudflare R2-hosted audio | Low | Open — by design. No real R2 bucket/credentials exist in this environment, per the task's explicit constraint (mirrors `001-auth-service`'s treatment of missing real Google/Apple OAuth credentials as a non-blocking placeholder). Swapping in real audio is a pure data update (re-run the idempotent seed script with real URLs) once R2 is provisioned, not a schema or contract change. Flagged here so it isn't silently forgotten before any real device/QA testing of the listening exercises. |
| `lesson_routers.py`'s 2 tail-`return` lines report as "missed" by `coverage.py` | Low | Not a real gap — see Coverage Report note above; same documented artifact `001-auth-service` already identified and worked around. |
| `seed_lesson_content.py`'s `main()` CLI entrypoint has 0% test coverage | Low | Open — by design, same treatment as `app/main.py`. Manually verified during Stage 4 (`uv run python -m app.infrastructure.db.seed_lesson_content`, run twice, row counts confirmed identical; direct SQLite query confirmed correct UTF-8 Amharic content) but not exercised by an automated test, since `main()`'s only job is wiring the real session factory + printing a summary — the actual `seed()` logic it calls is fully covered. |
| One pre-existing (`001-auth-service`) performance test flaked once under `--cov` instrumentation overhead in the full suite | Low | Not introduced by this bolt — see Performance Tests section above. |

No source code in `app/domain/lesson/`, `app/application/lesson_use_cases.py`, or the new `app/infrastructure/` lesson modules needed correction during this stage — only test files, `tests/conftest.py` (additive), and `tests/fakes.py` (additive) were touched.

## Recommendations

- Before real Cloudflare R2 credentials/audio exist in any environment, replace the placeholder `audio_url` values by re-running `uv run python -m app.infrastructure.db.seed_lesson_content` after updating `CURRICULUM`'s `_audio_url(...)` calls to real R2 URLs — idempotent by construction, no migration needed.
- `005-lesson-engagement-service` can now proceed against a fully implemented, tested content model and the explicit server-side-only answer-key contract (ADR-4) — `SubmitExerciseAnswer` should read `exercises.answer_key` via its own repository method (not exposed by anything in this bolt), and `UserSkillProgressRepository` will need write methods (`add`/`update`) added alongside its existing read-only `list_by_user`.
- This is the final stage of this bolt (`004-lesson-content-service`); the unit's second bolt (`005-lesson-engagement-service`) can now start.

## Ready for Operations

- [x] All acceptance criteria met
- [x] Code coverage > 80% (~99% on lesson-content-logic-bearing modules; 81% on the whole `app/` package, with the shortfall fully accounted for by out-of-scope external-verifier/bootstrap/CLI code — see Coverage Report and Issues Found)
- [x] No critical/high severity issues open
- [x] Performance targets met (constant query-count assertions, not just wall-clock smoke tests)
- [x] Security tests passing
