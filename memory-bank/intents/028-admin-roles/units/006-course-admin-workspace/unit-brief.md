---
unit: 006-course-admin-workspace
intent: 028-admin-roles
unit_type: frontend
default_bolt_type: simple-construction-bolt
phase: inception
status: complete
created: '2026-10-13T09:30:00Z'
updated: '2026-10-13T09:30:00Z'
---

# Unit Brief: Course Admin Workspace

## Purpose

Show a course admin only their courses and the actions they can use.

## Scope

### In Scope
- Empty course lists, hidden course and chart actions, and Sounds filtered to their languages.

### Out of Scope
- Anything inside a course, which is unchanged.

---

## Assigned Requirements

| FR | Requirement | Priority |
|----|-------------|----------|
| FR-15 | Course admins' Workspace | Must |

---

## Stories

| Story ID | Title | Priority | Status |
|----------|-------|----------|--------|
| 018-course-admin-workspace | A course admin's workspace shows only their courses and actions | Must | Complete (bolt 114) |

### 018-course-admin-workspace (FR-15)

**As a** course admin, **I want** a workspace with only my courses and the actions I can use, **so that** I'm never offered something that will be refused.

- [x] Curriculum, Vocabulary and Workbook lists show their courses; with none: "No courses yet. Ask a super admin to give you one."
- [x] "New course", "Edit course" and "Delete course" are hidden.
- [x] Sounds lists only their languages' charts; "New chart" and "Delete chart" are hidden.
- [x] Everything inside a course is unchanged: sections, skills, lessons, exercises, imports, vocabulary, Workbook, publishing, Record / Upload / Link / Generate.
- [x] A URL for another course shows the usual not-found state.

---

## Dependencies

### Depends On
- `002-route-permissions`
- `004-role-aware-shell`

---

## Bolt Suggestions

| Bolt | Type | Stories | Objective |
|------|------|---------|-----------|
| 114-course-admin-workspace | simple-construction-bolt | 018 | Hide course and chart actions from course admins. |
