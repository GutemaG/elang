---
stage: plan
bolt: 111-configuration-nav
created: '2026-10-13T15:55:00Z'
---

## Implementation Plan: role-aware-shell

### Objective

Story 014 (FR-13). A Configuration nav group, and course admins kept to
the workspace.

### Decisions

- **D1** `AppShell` groups: Workspace (Curriculum, Vocabulary,
  Workbook, Sounds, Guide); Learners (`superOnly`); Configuration
  (`superOnly`: Team, Languages, Voices, App updates). The App group is
  gone; URLs unchanged.
- **D2** `App.tsx`: `<SuperOnly>` around `/team`, `/languages`,
  `/voices`, `/app-updates`, `/dashboard`, `/learners`,
  `/learners/:id`, `/feedback`; a course admin is sent to `/`.

### Acceptance Criteria

- [x] Every criterion of story 014.

---

## Implement (2026-10-13)

- D1–D2 as planned. `/team` renders the Team page from bolt 112, so no
  placeholder was needed.

---

## Test (2026-10-13)

- `src/team/team.test.tsx` ("the navigation"): the three groups for a
  super admin, only Workspace for a course admin, and a redirect from
  each of the 7 super-admin addresses. Admin suite: 849 passed (42 files).
