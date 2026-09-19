---
unit: 001-categories-service
intent: 009-course-categories
phase: inception
status: draft
created: '2026-09-19T19:30:00Z'
updated: '2026-09-19T19:30:00Z'
---

# Unit Brief: Categories Service

## Purpose

Introduce categories as a first-class content level, make progression linear within a category with every category open, return categories from the skill-tree API, and seed four new categories with real content.

## Scope

### In Scope
- `categories` table; `skills.category_id` NOT NULL FK; migration backfilling the existing two skills into "Foundations & Greetings"
- Category-aware `SkillTreeProgressionPolicy` (first skill of each category active for new users) and `LessonCompletionService` (unlock next skill within the same category)
- `GET /skill-tree` returning categories; removal of hardcoded `UNIT_TITLE`/`UNIT_SUBTITLE`
- Seed: Family & People, Numbers & Time, Travel & Places, Colors/Body & Health (2 skills x 2 lessons each), with vocab links and >= 1 match_pairs per category

### Out of Scope
- Any Flutter UI (owned by `002-categories-ui`)
- Category picker, cross-category prerequisites, per-category streaks, real audio

## Assigned Requirements

| FR | Requirement | Priority |
|----|-------------|----------|
| FR-1 | Category Content Model | Must |
| FR-2 | Per-Category Progression | Must |
| FR-3 | Skill-Tree API Exposes Categories | Must |
| FR-4 | Seed Four New Categories | Must |

## Domain Concepts

| Entity | Description | Attributes |
|--------|-------------|------------|
| `Category` (new) | Named group of skills | `id`, `title`, `subtitle`, `order_index` |
| `Skill` (existing, extended) | Gains `category_id` | — |

## Constraints

- Re-read the real `skills` schema, `uq_skills_order_index`, and both progression code paths at Construction time before finalizing the design (other work may land first).
- Progression rule must have a single definition shared by the skill-tree read, `LessonAccessPolicy`, and completion-unlock.
- Skill-tree read keeps a constant query count.
- Seed stays idempotent (deterministic uuid5 slugs).

## Bolt Suggestions

| Bolt | Type | Stories | Objective |
|------|------|---------|-----------|
| 021-categories-service | ddd-construction-bolt | 001, 002, 003 | Schema, progression, API |
| 022-category-content-seed | simple-construction-bolt | 004 | Four seeded categories |
