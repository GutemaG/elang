---
bolt: 029-course-switcher-panel
created: '2026-09-21T06:10:00Z'
status: accepted
supersedes: null
superseded_by: null
---

# ADR-15: The course rail is the courses the learner has opened, derived from the offline cache

## Context

Story 003 asks for a rail of "the learner's courses" in the dashboard header, with a
`+ Course` tile for everything else. But `GET /api/v1/courses` (ADR-12, ADR-13) returns
the **entire catalog** — every course, available and coming soon, with `is_active`,
`completed_skills` and `total_skills`. The backend has no notion of enrolment, and adding
one would mean a schema change, a migration and a new write path for something that is
presentation state.

So "my courses" has to be derived on the client, and the derivation has to survive the
case that matters most: a learner who has just switched to a course and has not yet
finished anything in it.

## Decision

A course is on the rail if **any** of these hold, with the active course always first:

1. It has a cached dashboard in `CourseCacheStore` (ADR-14).
2. It is the active course.
3. It reports `completed_skills > 0`.

Coming-soon courses are never on the rail; they live in the catalog behind `+ Course`.

The first rule is the substantive one. ADR-14 already writes one cached dashboard **per
course id** after every successful load, so "has a cached dashboard" already means exactly
"this learner has opened this course". The rail reads that existing state through one new
method, `CourseCacheStore.cachedCourseIds`. No backend change, no migration, no new
persisted concept.

Rules 2 and 3 are the safety net for a device whose cache is empty or was cleared: the
learner still sees the course they are in, plus anything the server says they have
progress in, and the rail refills as they use the app.

## Rationale

The alternative that needed no new code was "active plus anything with progress". It fails
the case above: switch to a new course, switch away before finishing a skill, and it
vanishes from the rail — the opposite of what the learner just told the app they cared
about. The cache already records that intent, durably and per course, so using it costs
one read.

Putting the whole catalog on the rail was also considered. With four seeded courses the
rail would *be* the catalog, and `+ Course` would mean nothing.

## Alternatives Considered

- **Enrolment on the backend**: a `user_courses` table, correct and explicit, but a schema
  change plus migration for what is currently a presentation concern. Worth revisiting if
  the rail ever needs to be the same across devices.
- **A separate local "recent courses" list**: duplicates what the dashboard cache already
  records, with its own staleness to keep in sync.
- **Every available course on the rail**: makes `+ Course` redundant.

## Consequences

- The rail is **per device**. A learner on a second device sees their active course plus
  anything with progress until they open the others there. Acceptable: the rail is a
  shortcut, and the catalog always holds everything.
- Clearing the app's data shrinks the rail. Same trade-off the lesson pack store and the
  sync queue already make, and it refills on use.
- The rail and the offline cache are now coupled: anything that clears cached dashboards
  (for example the not-yet-built "clear the cache on log out" follow-up from ADR-14)
  also empties the rail. That is the correct behaviour for log out, and it is the reason
  the two must be considered together.
- A course whose dashboard is cached but which has since become `coming_soon` is filtered
  out of the rail, consistent with intent 010's still-open follow-up on that case.
