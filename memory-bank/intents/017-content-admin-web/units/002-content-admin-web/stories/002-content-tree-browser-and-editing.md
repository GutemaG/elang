---
id: 002-content-tree-browser-and-editing
unit: 002-content-admin-web
intent: 017-content-admin-web
status: generated
priority: must
created: '2026-09-22T10:00:00Z'
assigned_bolt: 037-admin-web-shell
implemented: false
---

# Story: 002-content-tree-browser-and-editing

## User Story

**As a** Buna admin
**I want** to browse a course's sections, skills, lessons and exercises and rearrange them
**So that** I can find and organise any lesson quickly

## Acceptance Criteria

- [ ] **Given** the courses, **When** one is picked, **Then** its tree shows in order with child counts, and listening exercises marked when still on the placeholder audio
- [ ] **Given** a section, skill or lesson, **When** the admin adds, renames or deletes it, **Then** the tree updates from the server response
- [ ] **Given** siblings, **When** the admin moves one up or down, **Then** the new order is saved in one request and the tree reflects it
- [ ] **Given** a delete the server refuses (`409`), **When** it happens, **Then** the message states how many learners are affected and nothing disappears
- [ ] **Given** a delete needing confirmation, **When** the admin confirms, **Then** it is sent with `confirm=true`
- [ ] **Given** a failed request, **When** it happens, **Then** an error is shown and the tree is not left showing unsaved changes

## Technical Notes

- Up/down buttons are enough for v1; drag-and-drop is a later nicety.

## Dependencies

### Requires
- 001-admin-web-scaffold-and-sign-in

### Enables
- 003-exercise-editors
