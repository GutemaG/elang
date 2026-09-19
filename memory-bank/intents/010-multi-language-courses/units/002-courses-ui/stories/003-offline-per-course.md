---
id: 003-offline-per-course
unit: 002-courses-ui
intent: 010-multi-language-courses
status: draft
priority: must
created: '2026-09-20T13:10:00Z'
assigned_bolt: 027-course-offline-and-verification
implemented: false
---

# Story: 003-offline-per-course

## User Story

**As a** learner with patchy connectivity
**I want** each course's cached tree and downloaded lessons kept separate
**So that** switching courses never shows the wrong content, online or offline

## Acceptance Criteria

- [ ] **Given** a skill tree cached for course A, **When** course B is active, **Then** A's tree is not shown
- [ ] **Given** packs downloaded in two courses, **When** Manage Downloads opens, **Then** both are kept and each shows its course
- [ ] **Given** the device is offline and the target course was cached, **When** the user switches, **Then** it opens from cache
- [ ] **Given** the device is offline and the target course was never cached, **When** the user switches, **Then** a message appears and the current course stays active
- [ ] **Given** a completion queued in course A, **When** the user has since switched to B and sync runs, **Then** it syncs to course A
- [ ] **Given** existing cached data from before this intent, **When** the app upgrades, **Then** it is treated as English to Amharic and not lost

## Technical Notes

- Reads the real skill-tree cache and `LessonPackStore` keys first. Offline-switch rule needs the active course saved locally too (the server call cannot be made offline).

## Dependencies

### Requires
- `001-course-switcher-and-settings-picker`, backend `004-course-scoped-skill-tree-and-progress`

### Enables
- `004-multi-course-end-to-end-verification`

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Offline switch, server active course now differs | Reconciled on next successful sync |
| Deleting a pack in one course | Other course's packs untouched |

## Out of Scope

- Automatic pre-download of other courses
