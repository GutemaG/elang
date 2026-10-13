---
stage: plan
bolt: 113-team-member-dialogs
created: '2026-10-13T16:15:00Z'
---

## Implementation Plan: team-page

### Objective

Stories 016 and 017 (FR-14). Add, edit and remove admins.

### Decisions

- **D1** `src/team/MemberDialog.tsx`: Email (read-only when editing),
  Role as two radio cards with one line each, Courses as checkboxes
  with Select all / Clear all, shown only for a course admin. The
  server's field errors (`details.field`: email, role, course_ids) show
  under their field; others at the foot.
- **D2** Remove asks in a `Modal`: "Remove {email}? They lose access on
  their next click." with Remove / Cancel; an error stays in the
  dialog.

### Acceptance Criteria

- [x] Every criterion of stories 016 and 017.

---

## Implement (2026-10-13)

- D1–D2 as planned. A super admin is sent with `course_ids: []`.

---

## Test (2026-10-13)

- `src/team/team.test.tsx`: adds a course admin with a course, adds a
  super admin, shows a 409 under Email, edits courses with Select all,
  removes after asking. Admin suite: 849 passed (42 files).
