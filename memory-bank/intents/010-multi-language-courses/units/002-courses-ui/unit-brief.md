---
unit: 002-courses-ui
intent: 010-multi-language-courses
phase: inception
status: draft
created: '2026-09-20T12:50:00Z'
updated: '2026-09-20T12:50:00Z'
---

# Unit Brief: Courses UI

## Purpose

Let learners see the list of courses, switch between them from the dashboard or Settings, choose a language pair during onboarding, and keep the offline cache and downloaded packs separated by course.

## Scope

### In Scope
- Dashboard top-bar course chip and a course picker (grouped by "I want to learn", with from-language, coming-soon disabled, active marked)
- Settings uses the same picker; both hardcoded course lists removed
- Onboarding asks "I speak" and "I want to learn" and only offers available pairs
- Skill-tree cache and `LessonPackStore` keyed by course; offline switching rules; queued completions sync to their own course
- Manage Downloads shows the course of each pack
- End-to-end verification and regression run

### Out of Scope
- Interface translation, backend changes (owned by `001-courses-service`), category picker

## Assigned Requirements

| FR | Requirement | Priority |
|----|-------------|----------|
| FR-6 | Offline Behaviour Per Course | Must |
| FR-7 | Course Switcher UI | Must |
| FR-8 | Onboarding Asks the Language Pair | Must |
| FR-10 | Existing Flows Unaffected | Must |

## Domain Concepts

| Entity | Description | Attributes |
|--------|-------------|------------|
| `Course` (Flutter model) | Mirrors the API course | `id`, `learningLanguage`, `fromLanguage`, `title`, `status`, `isActive` |
| Course-keyed cache | Skill tree and packs stored per course id | - |

## Constraints

- Read the real onboarding, settings, dashboard top bar, skill-tree cache and `LessonPackStore` at Plan time before restructuring.
- No overflow at 360dp with long titles and 1.3x text; Fidel and Latin render correctly.
- Existing onboarding, settings and dashboard tests are updated, not deleted.

## Bolt Suggestions

| Bolt | Type | Stories | Objective |
|------|------|---------|-----------|
| 026-course-picker-ui | simple-construction-bolt | 001, 002 | Switcher, Settings picker, onboarding pair |
| 027-course-offline-and-verification | simple-construction-bolt | 003, 004 | Offline per course, end-to-end verification |
