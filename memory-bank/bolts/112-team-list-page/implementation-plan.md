---
stage: plan
bolt: 112-team-list-page
created: '2026-10-13T16:05:00Z'
---

## Implementation Plan: team-page

### Objective

Story 015 (FR-14). The Team page lists the team.

### Decisions

- **D1** `src/team/api.ts` (types, routes, role labels) and
  `src/team/TeamPage.tsx`, built like the Languages page: a header with
  Add admin, an error with Try again, and a list whose rows wrap on a
  phone.
- **D2** Each row: email, role badge (Owner / Super admin / Course
  admin), "You" on your own row, courses ("All courses", titles, or "No
  courses yet"), "Last signed in {date}" or "Not signed in yet".
  Owners show a lock and "Set in the server’s ADMIN_EMAILS"; owners and
  your own row have no Edit or Remove.

### Acceptance Criteria

- [x] Every criterion of story 015.

---

## Implement (2026-10-13)

- D1–D2 as planned. A list rather than a table: it stacks on a phone
  without a second layout.

---

## Test (2026-10-13)

- `src/team/team.test.tsx` ("lists owners, super admins and course
  admins with their courses"). Admin suite: 849 passed (42 files).
