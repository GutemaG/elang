---
unit: 001-courses-service
intent: 010-multi-language-courses
phase: inception
status: draft
created: '2026-09-20T12:50:00Z'
updated: '2026-09-20T12:50:00Z'
---

# Unit Brief: Courses Service

## Purpose

Make a course (learning language plus from-language) a first-class content level, save one active course per user, expose the course list and switch endpoints, scope the skill tree, progress and Practice to the active course, and seed three Afaan Oromo starter courses.

## Scope

### In Scope
- `courses` table; `categories.course_id` NOT NULL FK; migration backfilling the five existing categories into English to Amharic
- Active course per user, stored server-side; existing users migrated to English to Amharic; signup accepts the language pair
- Course list and switch endpoints; only `available` courses selectable
- Skill tree and lesson access scoped by course; progress separate per course; Practice due items/count scoped to the active course
- Seed: English to Afaan Oromo, Amharic to Afaan Oromo, Afaan Oromo to Amharic (1 category, 2 skills x 2 lessons each)

### Out of Scope
- Any Flutter UI (owned by `002-courses-ui`)
- Interface translation, real audio, waitlist backend, per-course streak/XP/Amole

## Assigned Requirements

| FR | Requirement | Priority |
|----|-------------|----------|
| FR-1 | Course Model | Must |
| FR-2 | Active Course Saved Per User | Must |
| FR-3 | Course List API | Must |
| FR-4 | Course-Scoped Skill Tree and Progress | Must |
| FR-5 | Course-Scoped Practice | Must |
| FR-9 | Seed Afaan Oromo Starter Courses | Must |

## Domain Concepts

| Entity | Description | Attributes |
|--------|-------------|------------|
| `Course` (new) | A learning language taught from a given language | `id`, `learning_language`, `from_language`, `title`, `status`, `order_index` |
| `Category` (existing, extended) | Gains `course_id` | - |
| Active course (new) | The user's current course | `user_id`, `course_id` |
| `VocabItem` (existing) | Likely gains `course_id` (Technical Design decision) | - |

## Constraints

- Re-read the real `users`, `categories`, `vocab_items` schemas, the registration flow, and `LanguageCode` at Construction time before finalizing the design.
- Decide the fate of `users.selected_language` in an ADR (Prior Decision Lookup against `decision-index.md`).
- Course scoping must have one shared definition used by the skill-tree read, `LessonAccessPolicy`, completion and Practice queries.
- Reads keep constant query counts. Seed stays idempotent (deterministic uuid5 slugs).

## Bolt Suggestions

| Bolt | Type | Stories | Objective |
|------|------|---------|-----------|
| 024-courses-service | ddd-construction-bolt | 001, 002, 003, 004, 005 | Schema, active course, list API, scoping |
| 025-course-content-seed | simple-construction-bolt | 006 | Three Afaan Oromo courses |
