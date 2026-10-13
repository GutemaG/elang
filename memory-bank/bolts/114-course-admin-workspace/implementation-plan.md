---
stage: plan
bolt: 114-course-admin-workspace
created: '2026-10-13T16:25:00Z'
---

## Implementation Plan: course-admin-workspace

### Objective

Story 018 (FR-15). A course admin's workspace shows only their courses
and the actions they can use.

### Decisions

- **D1** `CourseList`: New course only for a super admin; with no
  courses a course admin reads "No courses yet. Ask a super admin to
  give you one."
- **D2** `CourseTree`: Rename course, Make available / Move to coming
  soon, and Delete course only for a super admin (all three are
  `PATCH`/`DELETE /courses/{id}`, super admin only since bolt 103).
- **D3** `SoundsPage`: New chart only for a super admin, with its own
  empty-state text; `SoundChartPage`: Delete this chart only for a
  super admin.
- **D4** Lists are already filtered by the server (bolts 104, 106), and
  another course's address already shows the not-found state.

### Acceptance Criteria

- [x] Every criterion of story 018.

---

## Implement (2026-10-13)

- D1–D4 as planned. Everything inside a course is unchanged.

---

## Test (2026-10-13)

- `src/team/team.test.tsx` ("a course admin’s workspace"): no New
  course and the empty hint; Add section but no rename, publish or
  delete; no New chart on Sounds. Admin suite: 849 passed (42 files).
