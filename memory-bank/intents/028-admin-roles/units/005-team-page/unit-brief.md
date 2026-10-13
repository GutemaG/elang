---
unit: 005-team-page
intent: 028-admin-roles
unit_type: frontend
default_bolt_type: simple-construction-bolt
phase: inception
status: complete
created: '2026-10-13T09:30:00Z'
updated: '2026-10-13T09:30:00Z'
---

# Unit Brief: Team Page

## Purpose

Give super admins one page to manage the team.

## Scope

### In Scope
- The `/team` list, the add/edit dialog and the remove dialog.

### Out of Scope
- Changing an email in place.

---

## Assigned Requirements

| FR | Requirement | Priority |
|----|-------------|----------|
| FR-14 | Team page | Must |

---

## Stories

| Story ID | Title | Priority | Status |
|----------|-------|----------|--------|
| 015-team-list-page | The Team page lists the team | Must | Complete (bolt 112) |
| 016-member-dialog | A super admin adds or edits an admin in a dialog | Must | Complete (bolt 113) |
| 017-remove-member | A super admin removes an admin | Must | Complete (bolt 113) |

### 015-team-list-page (FR-14)

**As a** super admin, **I want** to see the team at a glance, **so that** I know who has which courses.

- [x] `/team`: eyebrow "Configuration", title "Team", description "Who can sign in to Buna Studio, and which courses they work on."
- [x] Columns: Email, Role ("Owner", "Super admin", "Course admin"), Courses (titles, "All courses" or "No courses yet"), Last signed in ("Not signed in yet" when null). Stacks into cards on a phone.
- [x] Owners show a lock icon and "Set in the server's ADMIN_EMAILS", with no Edit or Remove.
- [x] Your own row says "You" and has no Edit or Remove.
- [x] Loading and load-error states as on other pages, with Try again.

### 016-member-dialog (FR-14)

**As a** super admin, **I want** a simple form to add or edit an admin, **so that** I can give a helper their courses in a minute.

- [x] **Add admin** opens a dialog: Email (focused), Role as two radio cards — "Course admin" (default, "Works on the courses you choose") and "Super admin" ("Everything, including the team and configuration") — and Courses as checkboxes with "Select all", shown only for a course admin.
- [x] Help text: "They sign in with Google using this address. No email is sent."
- [x] **Edit** opens the same dialog with the email read-only.
- [x] Server field errors show under their field; other errors at the foot of the dialog.
- [x] The list refreshes after a save.

### 017-remove-member (FR-14)

**As a** super admin, **I want** to remove someone who no longer helps, **so that** they can't sign in to the studio any more.

- [x] **Remove** asks in a dialog: "Remove {email}? They lose access on their next click." with Remove / Cancel.
- [x] On success the row disappears; on failure the dialog shows the error.

---

## Dependencies

### Depends On
- `003-team-api`
- `004-role-aware-shell`

---

## Bolt Suggestions

| Bolt | Type | Stories | Objective |
|------|------|---------|-----------|
| 112-team-list-page | simple-construction-bolt | 015 | Show the team on `/team`. |
| 113-team-member-dialogs | simple-construction-bolt | 016, 017 | Add, edit and remove admins from the Team page. |
