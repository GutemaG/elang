---
stage: plan
bolt: 110-session-role
created: '2026-10-13T15:45:00Z'
---

## Implementation Plan: role-aware-shell

### Objective

Story 013 (FR-12). The admin site knows the signed-in role.

### Decisions

- **D1** `AdminMe` gains `role`, `is_owner`, `course_ids` (optional, so
  a server from before intent 028 still works: no role means super
  admin, as every admin was then).
- **D2** `SessionState` `admin` carries `role`, `isOwner`, `courseIds`.
- **D3** `src/auth/access.ts`: `useAccess()` → `isSuper`,
  `canOpenCourse(id)`.
- **D4** `NotAuthorisedScreen`: "… is signed in, but is not on the
  team." and "Ask a super admin to add this address."
- **D5** A 403 `super_admin_only` already shows the server's message
  ("Only a super admin can do this") where the action was, like any
  other API error.

### Acceptance Criteria

- [x] Every criterion of story 013.

---

## Implement (2026-10-13)

- D1–D5 as planned.

---

## Test (2026-10-13)

- `src/team/team.test.tsx` ("an account not on the team"); the
  existing sign-in tests pass with `/me` bodies that carry only the
  email. Admin suite: 849 passed (42 files); `tsc -b` and `eslint .` clean.
