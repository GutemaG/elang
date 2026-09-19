---
intent: 010-multi-language-courses
phase: inception
created: '2026-09-20T12:45:00Z'
---

# Units: multi-language-courses

## Overview

2 units, backend/frontend split matching this project's pattern. Content authoring is a separate bolt from the structural backend work so the Afaan Oromo material can be reviewed on its own. The UI unit splits into the picker/onboarding work and the offline/verification work.

## Units

### 001-courses-service (backend)

**Purpose**: `courses` table and `categories.course_id` migration, active course per user (including signup with a language pair), course list and switch API, course-scoped skill tree, progress and Practice, and the three seeded Afaan Oromo starter courses.
**Assigned Requirements**: FR-1, FR-2, FR-3, FR-4, FR-5, FR-9
**Complexity**: High. Touches auth/user, skill tree, completion, and Practice queries; the migration must preserve existing progress; vocab may need to become per course.
**Bolts**: `024-courses-service` (ddd-construction-bolt: schema, active course, list API, scoping), `025-course-content-seed` (simple-construction-bolt: Afaan Oromo courses)

### 002-courses-ui (frontend)

**Purpose**: Course switcher on the dashboard, shared picker used by Settings, onboarding asks the language pair, offline cache and packs keyed by course, and end-to-end verification.
**Assigned Requirements**: FR-6, FR-7, FR-8, FR-10
**Complexity**: Moderate-high. Replaces two hardcoded lists, adds a course dimension to the offline cache, and changes the onboarding flow.
**Depends on**: `001-courses-service`
**Bolts**: `026-course-picker-ui` (simple-construction-bolt), `027-course-offline-and-verification` (simple-construction-bolt)

## Dependency Graph

```text
024-courses-service --> 025-course-content-seed --> 027-course-offline-and-verification
024-courses-service --> 026-course-picker-ui ------> 027-course-offline-and-verification
025-course-content-seed --> 026-course-picker-ui (real data for on-device checks)
```

## Notes

NFR-3: all Afaan Oromo and cross-language content is agent-authored and not native-speaker reviewed; a proof-read is required before any real release.
