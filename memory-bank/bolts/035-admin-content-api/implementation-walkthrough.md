---
stage: implement
bolt: 035-admin-content-api
created: '2026-09-22T12:40:00Z'
---

## Implementation Walkthrough: content-admin-api

### Summary

The admin API now manages content, all behind the router-level
`require_admin` check from bolt 034. It can:
- list and rename courses
- return a course's full tree
- create, rename, reorder and delete sections, skills and lessons
- read, create, update, reorder and delete exercises

Every exercise write goes through one validator. It is shared with the
learner read path, and it adds the answer-key cross-checks that were
missing. Deletes are guarded by learner history and need confirmation.

### Structure Overview

The code follows the existing layering: thin routers, use cases in the
application layer, SQL in one repository.
- **One repository shape for four levels.** Sections, skills, lessons and
  exercises share one description (model, parent column, parent model), so
  create, reorder and delete are written once, not four times.
- **One copy of the JSON mapping.** The mapping between stored exercise JSON
  and domain value objects moved into the domain. The learner repository
  reads through it, and the admin validator builds on it.

### Completed Work

- [x] `backend/app/domain/lesson/exercise_parts.py` - new:
  - the JSON-to-value-object mapping, lifted unchanged from the lesson
    repository
  - `validate_exercise`: allowed keys per type, tile shape and unique ids,
    non-empty prompt, `https://` audio (`/media/` locally), the value
    objects' own invariants, and the answer-key cross-checks
- [x] `backend/app/domain/lesson/exceptions.py` - admin errors carrying
  `details`: not found, invalid content, invalid exercise, invalid order, in
  use, confirmation required
- [x] `backend/app/infrastructure/db/lesson_repositories.py` - reads through
  the lifted mapping; the old private names are kept as aliases for the
  existing dispatch test
- [x] `backend/app/infrastructure/db/admin_content_repository.py` - new:
  - course list with counts, and the course tree in four queries
  - children in order
  - subtree and learner counts
  - two-pass reorder
  - subtree delete
  - touching a lesson to move its content version
- [x] `backend/app/application/admin_content_use_cases.py` - new: rename
  course; create, rename, reorder and guarded-delete a node; list, create,
  update and delete exercises; one `admin_write` log line per successful
  write
- [x] `backend/app/infrastructure/api/admin_schemas.py` - admin request and
  response schemas: courses, the tree, nodes and exercises
- [x] `backend/app/infrastructure/api/admin_routers.py` - the 20 new
  endpoints listed in the plan; audio status for listening exercises in the
  tree
- [x] `backend/app/infrastructure/api/error_handlers.py` - admin errors
  mapped to 404/409/422, with `details` in the body

### Key Decisions

- **Cross-checks run on write only.** The learner read path is unchanged,
  so a bad row already in Neon cannot start failing a lesson that loads
  today.
  - A check over all 181 seeded exercises (177 main and 4 Audio Lab) found
    that every one passes the new validator.
- **A sequence answer may not use a tile twice.** Repeated letters in a
  `spell_tiles` word are separate tiles with separate ids (`016`'s rule),
  so reusing one id is always a mistake. All seeded exercises satisfy it.
- **Match pairs** must pair every left tile exactly once, with distinct
  right tiles, which matches the equal-length columns rule.
- **Exercise content is stored exactly as sent** once it validates, so a
  seeded exercise sent back unchanged is stored unchanged. Only the prompt
  is trimmed of surrounding spaces.
- **Deleting needs confirmation at every level**, even an empty lesson. One
  rule is simpler for the admin site to follow than "sometimes".
- **The application layer imports the repository and ORM models directly**
  instead of going through a domain repository protocol, like the learner
  code does. These are plain CRUD writes with no domain behaviour, and a
  protocol for them would be ceremony. This is recorded here so it reads as
  a choice, not an oversight.
- **After any delete, siblings are renumbered to 1..n.** A reorder
  renumbers too. So positions stay contiguous, although the Audio Lab's
  seeded position 0 becomes 1 after its first reorder.

### Deviations from Plan

- **The plan cited the wrong ADR.** It said the learner API "never returns
  answer keys (ADR-4)". ADR-5 superseded that: the learner lesson response
  already includes answer keys, because grading happens on the client.
  Nothing in this bolt depended on the claim. The admin exercise list simply
  returns the same data plus `vocab_item_id`.
- **Otherwise none.**

### Dependencies Added

None.

### Developer Notes

- **Checks run at this stage:**
  - The full backend suite is green (640 passed) and ruff is clean.
  - A throwaway smoke test drove every kind of write through the real
    router and was then removed. It covered create, a bad answer key
    (`422` naming the field), reorder, the tree, and delete without and then
    with confirm. The real tests are Stage 3's.
- **Reorders are 1-based.** The two-pass reorder offsets by 10,000. Any
  future content that legitimately uses positions that high would need a
  larger offset.
