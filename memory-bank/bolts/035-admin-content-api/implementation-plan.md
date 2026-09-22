---
stage: plan
bolt: 035-admin-content-api
created: '2026-09-22T11:40:00Z'
---

## Implementation Plan: content-admin-api

### Objective

An admin can read a course's whole content tree, and create, edit, reorder and
delete its sections, skills, lessons and exercises through `/api/v1/admin/*`:
- Exercises that the app could not play are refused.
- Deleting content that learners have history on is refused.
- Every write leaves one audit log line.

### What the code showed (read before planning)

1. **Every level has an order uniqueness constraint.** The constraints are
   `uq_categories_course_order_index`, `uq_skills_category_order_index`,
   `uq_lessons_skill_order` and `uq_exercises_lesson_order`. Reordering by
   writing the final indexes directly would violate them mid-way, so a
   reorder has to pass through a temporary range first.
2. **Nothing checks that an answer key matches its content.** The docstrings
   of `ChoiceAnswerKey` and `PairAnswerKey` say the infrastructure layer
   validates their ids against the sibling content when reconstructing, but
   `_content_from_json` / `_answer_key_from_json` never do. The per-object
   invariants exist, such as "at least 2 choices" and "left and right the
   same length". The cross-check does not. A key pointing at a missing
   choice would be stored and served today.
3. **Offline packs refresh by `content_version`.** It is
   `max(lesson.updated_at, max(exercise.updated_at))`:
   - Editing an exercise moves it.
   - **Deleting** an exercise, or reordering in a way that leaves the newest
     row alone, may not move it. A downloaded lesson would then stay stale.
4. **Only two tables tie learners to content.** The foreign keys are
   `user_skill_progress.skill_id` and `lesson_attempts.lesson_id`. Nothing
   references an exercise, and SRS progress hangs off `vocab_items`, which
   this bolt does not delete.
5. **Seeded listening exercises use `PLACEHOLDER_AUDIO_URL`**, an https piano
   clip. The local Audio Lab uses relative `/media/audio/...` paths, which
   exist only on a local backend.

### Deliverables

**Endpoints**
All of them sit under `/api/v1/admin` and are guarded by `require_admin`,
the router-level check from bolt 034.

Courses and the tree:
- `GET /courses`: every course, with its counts.
- `PATCH /courses/{id}`: `{title}`.
- `GET /courses/{id}/tree`: sections → skills → lessons in order, with child
  counts. Each lesson lists its exercises as id, type, prompt, order and
  `audio` (`placeholder` / `hosted` / `local` / `none`).

Sections, skills and lessons:
- `POST` creates one under its parent: `/courses/{id}/sections` takes
  `{title, subtitle}`; `/sections/{id}/skills` and `/skills/{id}/lessons`
  take `{title}`. New items get a uuid4 id and go last.
- `PATCH /sections|skills|lessons/{id}` renames.
- `DELETE /sections|skills|lessons/{id}[?confirm=true]` deletes (see "Delete
  rules" below).
- `PUT /courses/{id}/sections/order`, `/sections/{id}/skills/order` and
  `/skills/{id}/lessons/order` each take `{ids: [...]}`, the complete list
  of the parent's children in their new order.

Exercises:
- `GET /lessons/{id}/exercises`: the full exercises, including `content` and
  `answer_key`, for the editors. Admin only; the learner API still never
  returns answer keys (ADR-4).
- `POST /lessons/{id}/exercises` takes `{type, prompt, content, answer_key}`.
- `PUT /exercises/{id}` takes the same fields.
- `DELETE /exercises/{id}`.
- `PUT /lessons/{id}/exercises/order`.

**Validation** (story 004): one domain function, used on every exercise
write.
- It builds the content and answer key through the existing reconstruction.
  The two functions are lifted from `lesson_repositories.py` into
  `app/domain/lesson/exercise_parts.py`, so the learner read path and the
  admin write path share one copy.
- It adds the missing cross-checks from finding 2:
  - A choice key must be one of the choices.
  - Sequence ids must be among the tiles.
  - Pairs must use left and right ids, each left once.
- It adds admin-only input checks:
  - The prompt must be non-empty.
  - Unknown keys in `content` or `answer_key` are rejected.
  - A type change on `PUT` is rejected.
  - `audio_url` must be absolute `https://`. `/media/...` is also accepted,
    but only when `ENVIRONMENT=local`, so the Audio Lab stays editable on
    your machine.
- A failure is a `422` with `field` (e.g. `answer_key.correct_choice_id`)
  and a readable message.
- The cross-checks run on **write only**. The learner read path is not made
  stricter, so a bad row already in Neon cannot start breaking lessons that
  currently load. A test proves that every seeded exercise passes the new
  checks.

**Delete rules** (story 003)
- Deleting a section, skill or lesson counts the distinct learners with rows
  in `user_skill_progress` or `lesson_attempts` anywhere beneath it. If any
  exist, the response is **`409 content_in_use`** with `learners` and the
  counts, and nothing is deleted. The same applies with `confirm=true`.
- With no learner history:
  - Without `confirm` the response is **`409 confirmation_required`**,
    listing what would be deleted (skills, lessons, exercises).
  - With `confirm=true`, the item and everything beneath it are deleted in
    one transaction.
- Deleting an exercise needs no confirmation, since nothing references it.
- After a delete, the remaining siblings are renumbered so their order stays
  contiguous.

**Keeping offline copies fresh** (finding 3): creating, deleting or
reordering exercises also updates the parent lesson's `updated_at`, so
`content_version` always moves.

**Audit** (story 003): each successful write logs one line on the `app.admin`
logger:
`admin_write action=<create|update|reorder|delete> entity=<...> id=<...> admin=<email>`.
Content text is never logged. The email is the admin identity the story
requires; nothing else personal is logged.

**Errors**: new `AdminContentError` subclasses, mapped in the existing
`error_handlers.py`, whose error body gains optional `details`:
- `404 content_not_found`
- `409 content_in_use`
- `409 confirmation_required`
- `422 invalid_order`
- `422 invalid_exercise`

### Dependencies

- `require_admin` and the admin router from bolt 034.
- The existing content models and domain value objects. No migration and no
  new packages.

### Technical Approach

- **Where the code goes:**
  - `app/application/admin_content_use_cases.py` holds the use cases: tree,
    create, rename, reorder, guarded delete and exercise writes.
  - `app/infrastructure/db/admin_content_repository.py` holds the SQL. It
    works on ORM models directly, because these are plain CRUD writes over
    rows the learner-side aggregates only read.
  - Routers stay thin: request DTO → use case → response DTO.
- **Reorder:** check that the ids are exactly the parent's current children.
  Then, in one transaction, move every row to `order_index + 10000`, flush,
  and write `1..n`, matching the existing 1-based order. The "exactly the current children" check rejects
  missing, extra and duplicate ids alike.
- **Response shapes:** these are admin-only pydantic schemas in
  `admin_schemas.py`. The learner schemas are untouched.
- **What "create" needs:** a section needs a title and subtitle; skills and
  lessons need a title. Nothing is "locked": every category is open, and the
  first skill in a category becomes active on its own (existing behaviour).

### Out of Scope (named so it is not assumed)

- Moving an item to a different parent: reorder happens within one parent.
- Creating or deleting courses, and editing `vocab_item_id` (vocabulary is
  bolt 040).
- Audio upload (bolt 036).

### Acceptance Criteria

- [ ] The tree returns every level in order, with counts and each listening
  exercise's audio status
- [ ] Created items get uuid4 ids, go last, and show up in the learner
  `/skill-tree` or lesson fetch on the next request
- [ ] Reorder applies atomically; missing, extra or duplicate ids return
  `422` with nothing changed; no uniqueness violation on SQLite or on
  Postgres semantics
- [ ] Deleting content with learner history returns `409` with the learner
  count, and nothing is deleted
- [ ] Deleting unused content without `confirm` returns `409` with counts;
  with `confirm=true` it deletes the whole subtree; siblings stay contiguous
- [ ] Course titles are editable; there is no create or delete endpoint for
  courses
- [ ] All six exercise types: saving a seeded exercise back unchanged is
  accepted and stored identically
- [ ] Bad answer keys, fewer than two choices, an empty prompt, unknown
  tiles or keys, a type change, or a non-https `audio_url` each return `422`
  naming the field
- [ ] Every seeded exercise passes the new cross-checks
- [ ] Exercise create, delete and reorder move the lesson's
  `content_version`
- [ ] One `admin_write` log line per successful write, containing no content
  text
- [ ] Every admin endpoint returns `403` for a non-admin
- [ ] The full suite is green, ruff is clean, and the learner endpoints'
  behaviour is unchanged
