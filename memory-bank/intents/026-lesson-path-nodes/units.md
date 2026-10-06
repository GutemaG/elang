---
intent: 026-lesson-path-nodes
phase: inception
status: units-decomposed
updated: 2026-10-06T08:57:00Z
---

# Lesson Path Nodes - Unit Decomposition

## Units Overview

Two units: the backend adds each skill's lessons to the skill tree; the
app draws a bubble per lesson. Stories are written inside each unit
brief, numbered across the intent.

### Unit 1: 001-path-lessons-service

**Description:** `lessons` on each skill of `GET /api/v1/skill-tree`.

**Requirements:** FR-1

**Deliverables:**
- One grouped query for the lessons' ids and titles
- The response field; tests; API notes

**Dependencies:** none. Depended on by unit 2.

**Estimated complexity:** S

### Unit 2: 002-path-lessons-app

**Description:** The path's lesson bubbles, skill labels, states, taps,
and dropping the skill-part wording.

**Requirements:** FR-2, FR-3, FR-4, FR-5

**Deliverables:**
- The model reads and saves `lessons`; the path's stops built from it
- Lesson bubbles, the skill label with its crown, the popover's states
- No skill-progress card or ring with lesson bubbles
- New strings in three languages; tests

**Dependencies:** `001-path-lessons-service`.

**Estimated complexity:** M

## Requirement-to-Unit Mapping

- **FR-1** Lessons in the skill tree → `001-path-lessons-service`
- **FR-2** One bubble per lesson → `002-path-lessons-app`
- **FR-3** Lesson states and taps → `002-path-lessons-app`
- **FR-4** No parts of a skill → `002-path-lessons-app`
- **FR-5** Older backend → `002-path-lessons-app`

## Unit Dependency Graph

```text
[001-path-lessons-service] ──> [002-path-lessons-app]
```

## Execution Order

1. `001-path-lessons-service` (bolt 087)
2. `002-path-lessons-app` (bolt 088)
