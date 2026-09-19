---
id: 001-course-switcher-and-settings-picker
unit: 002-courses-ui
intent: 010-multi-language-courses
status: draft
priority: must
created: '2026-09-20T13:10:00Z'
assigned_bolt: 026-course-picker-ui
implemented: false
---

# Story: 001-course-switcher-and-settings-picker

## User Story

**As a** Buna learner
**I want** to open a list of courses from the dashboard and switch, like Duolingo
**So that** I can move between languages and have my choice remembered

## Acceptance Criteria

- [ ] **Given** the dashboard, **When** it loads, **Then** a course chip in the top bar shows the active course
- [ ] **Given** the chip is tapped, **When** the picker opens, **Then** courses come from the course API, grouped by the language to learn, with their from-language, and the active one marked
- [ ] **Given** a coming-soon course, **When** shown, **Then** it is disabled and cannot be selected
- [ ] **Given** an available course is tapped, **When** the switch succeeds, **Then** the picker closes and the dashboard shows that course's skills, Practice count and banners
- [ ] **Given** the switch request fails, **When** the error returns, **Then** the current course stays active and a message is shown
- [ ] **Given** Settings, **When** the language row is used, **Then** it opens the same picker and the two hardcoded course lists are gone
- [ ] **Given** 360dp width, long titles and 1.3x text, **When** rendered, **Then** nothing overflows

## Technical Notes

- Reads the real dashboard top bar before restructuring. Existing settings tests updated, not deleted.

## Dependencies

### Requires
- `003-course-list-api`, `002-active-course-per-user` (backend)

### Enables
- `003-offline-per-course`

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Only one available course | Picker still opens, shows the others as coming soon |
| Switch while offline | Handled by `003-offline-per-course` |

## Out of Scope

- Waitlist for coming-soon courses
