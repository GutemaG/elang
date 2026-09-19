---
unit: 002-categories-ui
intent: 009-course-categories
phase: inception
status: draft
created: '2026-09-19T19:30:00Z'
updated: '2026-09-19T19:30:00Z'
---

# Unit Brief: Categories UI

## Purpose

Render the dashboard grouped by category and confirm new-category content behaves correctly end to end in the app.

## Scope

### In Scope
- Flutter `SkillTree` model, `HttpLessonApi` parsing and `FakeLessonApi` updated for categories
- Dashboard: one banner (title, Amharic subtitle, "x/y Completed", progress bar) plus skill path per category; zig-zag restarts per category; no overflow at 360dp
- End-to-end verification of new-category lessons (take, complete, offline download, Practice)

### Out of Scope
- Category picker screen; any new exercise-rendering code

## Assigned Requirements

| FR | Requirement | Priority |
|----|-------------|----------|
| FR-5 | Dashboard Groups Skills by Category | Must |
| FR-6 | Existing Flows Unaffected | Must |

## Constraints

- Read the real dashboard (`_UnitBanner`, `_lateralOffset`, node download affordances) at Plan stage before restructuring.
- Depends on `001-categories-service` for the real API contract.

## Bolt Suggestions

| Bolt | Type | Stories | Objective |
|------|------|---------|-----------|
| 023-categories-ui | simple-construction-bolt | 001, 002 | Grouped dashboard + verification |
