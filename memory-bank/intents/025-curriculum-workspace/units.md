---
intent: 025-curriculum-workspace
phase: inception
status: units-decomposed
updated: 2026-10-05T10:30:00Z
---

# Curriculum Workspace - Unit Decomposition

## Units Overview

Two units: the backend keeps the draft curriculum and publishes a lesson
from it into the live course; the admin site reads the workbook, shows
progress, lets the admin review and record each row, and generates, edits
and publishes a lesson's exercises. Stories are written inside each unit
brief, numbered across the intent.

### Unit 1: 001-curriculum-service

**Description:** Draft curriculum tables per course, admin-only endpoints
to import, list, edit and record rows, a lesson's draft exercises, and
publishing one lesson into the live tables.

**Requirements:** FR-1, FR-3 (merge rules), FR-4 (counts), FR-5
(validation), FR-6 (audio), FR-7 and FR-8 (draft exercises), FR-9

**Deliverables:**
- Migrations: `curriculum_entries` (sections, skills, lessons),
  `curriculum_rows` (words and sentences), the lesson's draft exercises
  and what it published; backward compatible
- `PUT /admin/courses/{id}/curriculum` (atomic import), `GET` (plan, rows,
  counts), `PATCH` a row (with a version check), set a row's audio
- Draft exercises saved per lesson; `POST .../lessons/{ref}/publish`
- Tests; API notes

**Dependencies:** none. Depended on by unit 2.

**Estimated complexity:** M

### Unit 2: 002-curriculum-admin

**Description:** The Curriculum tab: workbook import with preview, export,
the overview, a lesson's rows with editing and recording, and generating,
editing and publishing its exercises.

**Requirements:** FR-2, FR-3 (preview), FR-4, FR-5, FR-6, FR-7, FR-8,
FR-9 (UI), FR-10

**Deliverables:**
- Curriculum tab per course; overview with progress and publish state
- Reading the workbook in the browser; preview; confirm; export
- A lesson's page: edit, status, comment; record or upload; next unrecorded
- Generate with the lesson CSV import's rules; preview; edit in the
  exercise editor; publish
- Tests

**Dependencies:** `001-curriculum-service`.

**Estimated complexity:** L

## Requirement-to-Unit Mapping

- **FR-1** Draft curriculum per course → `001-curriculum-service`
- **FR-2** Import the workbook → `002-curriculum-admin` (stored by `001-curriculum-service`)
- **FR-3** Re-import safely → `001-curriculum-service` (merge); `002-curriculum-admin` (preview)
- **FR-4** Overview with progress → `002-curriculum-admin` (counts from `001-curriculum-service`)
- **FR-5** Review a lesson's rows → `002-curriculum-admin`; validation in `001-curriculum-service`
- **FR-6** Record or upload audio → `002-curriculum-admin`; stored by `001-curriculum-service`
- **FR-7** Generate exercises → `002-curriculum-admin`; kept by `001-curriculum-service`
- **FR-8** Edit generated exercises → `002-curriculum-admin`; kept by `001-curriculum-service`
- **FR-9** Publish a lesson → `001-curriculum-service`; button in `002-curriculum-admin`
- **FR-10** Export to Excel → `002-curriculum-admin`

## Unit Dependency Graph

```text
[001-curriculum-service] ──> [002-curriculum-admin]
```

## Execution Order

1. `001-curriculum-service`: draft tables, import, list, edit, audio
   (bolt 082)
2. `002-curriculum-admin`: the tab, import preview and export (bolt 083);
   review and record (bolt 084)
3. `001-curriculum-service`: draft exercises and publish (bolt 085)
4. `002-curriculum-admin`: generate, edit and publish (bolt 086)
