---
intent: 009-course-categories
phase: inception
created: '2026-09-19T19:25:00Z'
---

# Units: course-categories

## Overview

2 units, backend/frontend split matching this project's pattern. The backend unit holds two bolts: the structural change (schema + progression + API) and the content seed, split because content authoring is a separate risk from the structural work and can be reviewed independently.

## Units

### 001-categories-service (backend)

**Purpose**: `categories` table + `skills.category_id` migration, per-category progression, skill-tree API with categories, and the four new seeded categories.
**Assigned Requirements**: FR-1, FR-2, FR-3, FR-4
**Complexity**: Moderate-high. Progression logic lives in two places (`SkillTreeProgressionPolicy` and `LessonCompletionService`) that must stay in agreement; the migration must preserve existing user progress.
**Bolts**: `021-categories-service` (ddd-construction-bolt: schema, progression, API), `022-category-content-seed` (simple-construction-bolt: seed content)

### 002-categories-ui (frontend, simple-construction-bolt)

**Purpose**: Group the dashboard by category (banner + skill path per category) and verify new-category content works end to end.
**Assigned Requirements**: FR-5, FR-6
**Complexity**: Moderate — the dashboard currently assumes one banner and one path; the layout math (zig-zag offset) and per-category counts change.
**Depends on**: `001-categories-service`

## Dependency Graph

```text
021-categories-service --> 022-category-content-seed --> 023-categories-ui
021-categories-service ---------------------------------> 023-categories-ui
```

## Notes

NFR-3: Amharic content is agent-authored and not native-speaker reviewed; a proof-read is required before any real release.
