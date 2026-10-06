---
unit: 001-path-lessons-service
intent: 026-lesson-path-nodes
unit_type: backend
default_bolt_type: simple-construction-bolt
phase: inception
status: complete
created: '2026-10-06T08:57:00Z'
updated: '2026-10-06T08:57:00Z'
---

# Unit Brief: Path Lessons Service

## Purpose

Tell the app each skill's lessons, so it can draw one bubble per lesson.

## Scope

### In Scope
- `lessons: [{id, title, done}]` on each skill of `GET /api/v1/skill-tree`
- A grouped repository read of each skill's lesson ids and titles
- Tests; the API notes

### Out of Scope
- Any change to progress, crowns, unlocking or lesson completion

---

## Assigned Requirements

| FR | Requirement | Priority |
|----|-------------|----------|
| FR-1 | Lessons in the skill tree | Must |

---

## Stories

| Story ID | Title | Priority | Status |
|----------|-------|----------|--------|
| 001-lessons-in-the-skill-tree | Each skill's lessons in the skill tree | Must | Complete (bolt 087) |

### 001-lessons-in-the-skill-tree (FR-1)

**As a** learner's app, **I want** each skill's lessons with whether each
is done, **so that** I can show every lesson as its own stop.

- [x] Each skill has `lessons`, ordered by `order_index`, each with `id`,
  `title` and `done` (in the current pass's done set).
- [x] A skill with no lessons has `lessons: []`.
- [x] Every existing field is unchanged.
- [x] The read is one grouped query, not one per skill.

---

## Dependencies

### Depends On
None.

### Depended By
| Unit | Reason |
|------|--------|
| 002-path-lessons-app | Draws the bubbles from `lessons` |

---

## Bolt Suggestions

| Bolt | Type | Stories | Objective |
|------|------|---------|-----------|
| 087-path-lessons-service | simple-construction-bolt | 001 | The `lessons` field |
