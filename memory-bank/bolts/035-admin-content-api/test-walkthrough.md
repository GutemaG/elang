---
stage: test
bolt: 035-admin-content-api
created: '2026-09-22T13:30:00Z'
---

## Test Report: content-admin-api

### Summary

- **Tests**: 905/905 passed across the full backend suite. That is 640 before
  this bolt plus 265 new. Most of the new ones are parametrized: one per
  seeded exercise, and one per admin route.
- **Lint**: `ruff check` and `ruff format --check` are clean.
- **Coverage**: see Notes. The percentages for code driven through
  `TestClient` understate the real coverage.

### Test Files

- [x] `backend/tests/unit/test_exercise_validation.py`:
  - one valid sample per type
  - every one of the 177 seeded exercises passes
  - the 4 Audio Lab exercises pass only when local media is allowed
  - 26 refusals, each asserting the exact field named
- [x] `backend/tests/integration/test_admin_content_endpoints.py`, over HTTP
  against the real seeded content:
  - **Access**: every admin route returns 403 for a non-admin. The route
    list is read from the router itself, so a new route is covered
    automatically.
  - **Tree**: course list and counts; ordering and counts at every level;
    exercise total matches the database; listening exercises marked
    `placeholder`, others `null`; 404 for an unknown course.
  - **Create and rename**:
    - a new section, skill, lesson and exercise each go last with a uuid4
      id, appear in the learner `/skill-tree`, and load through the learner
      `/lessons/{id}`
    - renaming at all four levels, including the course
    - blank titles return 422 `title`
    - no course create or delete (405)
    - 404 under a missing parent
  - **Reorder**:
    - a new section order applies, renumbered 1..n
    - missing, extra or duplicate ids return 422 and change nothing
    - lesson and exercise reorders; the learner lesson fetch returns the new
      exercise order
  - **Delete**:
    - skill progress blocks deleting the section and the skill (409, 1
      learner)
    - a lesson attempt blocks deleting the lesson
    - unused content: first 409 `confirmation_required` with exact counts,
      then 204 with the whole subtree gone and siblings renumbered
    - a section delete removes its skills
    - an exercise deletes without confirmation and its siblings are
      renumbered
  - **Exercise writes**:
    - every seeded en→am exercise, all six types, saved back unchanged
      leaves the stored rows **identical** (compared at the database)
    - a bad answer key returns 422 naming the field
    - a type change is refused
    - hosted `https` audio is accepted and `http` is refused
    - 404 for an unknown exercise
  - **Content version**: exercise create, delete and reorder each move the
    lesson's `updated_at`.
  - **Audit**: one line per write, with the exact text; no line for a read;
    the prompt text never appears; a refused write logs nothing.

### Acceptance Criteria Validation

- ✅ **Tree in order, with counts and audio status**: `TestTree`
- ✅ **Created items get uuid4 ids, go last, and reach the learner API**:
  `test_created_content_goes_last_and_reaches_the_learner`
- ✅ **Reorder is atomic; a wrong id list returns 422 and changes nothing;
  no uniqueness violation**: `TestReorder`, on SQLite. See Issues Found for
  Postgres.
- ✅ **Learner history → 409 with the learner count, nothing deleted**: two
  tests, one via skill progress and one via a lesson attempt
- ✅ **Unused content: 409 with counts, then the confirmed delete removes the
  subtree; siblings stay contiguous**: `TestDelete`
- ✅ **Course title editable; no course create or delete**:
  `test_rename_course_section_skill_and_lesson` and
  `test_there_is_no_course_create_or_delete`
- ✅ **All six types round-trip identically**:
  `test_every_seeded_exercise_saves_back_unchanged`
- ✅ **Each bad input returns 422 naming the field**: `TestRefusals`,
  `test_a_bad_exercise_is_refused_naming_the_field`, `test_type_cannot_change`
  and `test_attaching_hosted_audio`
- ✅ **Every seeded exercise passes the cross-checks**:
  `test_every_seeded_exercise_passes`, 177 cases
- ✅ **Exercise create, delete and reorder move `content_version`**:
  `TestContentVersion`
- ✅ **One `admin_write` line per write, with no content text**: `TestAudit`
- ✅ **403 for a non-admin on every endpoint**: `TestAccess`, 20 routes
- ✅ **Full suite green, ruff clean, learner behaviour unchanged**: 905
  passed, and the learner tests are untouched

### Issues Found

- **Falsification checks**, each run against deliberately broken code and
  then restored:
  - With the answer-key cross-check disabled, 5 validation tests fail. These
    are the ones that pin the new rule.
  - With the lesson "touch" disabled, all 3 content-version tests fail. That
    confirms plan finding 3 was real: without the touch, a create, delete or
    reorder would leave downloaded lessons stale.
- **Postgres not exercised.** The two-pass reorder is tested on SQLite only.
  On Postgres the same per-row UPDATEs apply, and the 10,000 offset keeps
  every intermediate value distinct, so it should hold. It is unproven until
  it runs against Neon. It can be checked in Operations, after the admin
  site exists.

### Notes

- **Coverage percentages under `--cov`:**
  - `exercise_parts.py` 95%
  - `admin_schemas.py` and `error_handlers.py` 100%
  - `admin_content_repository.py` 81%, `admin_routers.py` 75%,
    `admin_content_use_cases.py` 41%

  The last three understate real coverage. Their code runs inside
  `TestClient`'s portal thread through SQLAlchemy's greenlet bridge, which
  `coverage` does not trace without `concurrency = greenlet` settings, and
  the project's coverage config does not set those. Every use-case branch
  (create, rename, reorder ok/invalid, delete in-use/confirm/done, exercise
  create/update/type-change/delete) is asserted by a named test above.
- **Coverage-run warnings.** The coverage run also produced 84 extra
  warnings that the plain run does not (it shows the usual 2). They appear
  only with `--cov` switched on, so they are tied to running under coverage.
  I did not investigate them further.
- **The local `dev.db` needs nothing.** This bolt adds no migration.
