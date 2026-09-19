---
stage: implement
bolt: 024-courses-service
created: '2026-09-20T17:00:00Z'
---

## Implementation Walkthrough: courses-service

### Summary

The backend now has a course level above categories. A user has one active course saved on their account, the skill tree and Practice are limited to it, and lessons are gated by their own course's availability. The Flutter client is untouched: every existing response field is preserved and the new fields are additive.

### Structure Overview

`Course` is a small shared-kernel type (`app/domain/course.py`) used by both the auth/user side and the lesson side. Categories and vocab items carry a `course_id`; skills, lessons and exercises reach their course through their category. The user carries `active_course_id`, and `selected_language` is kept as a mirror of the active course's learning language. One function, `activate_course_for_user`, is the only place both are written, and signup, the switch endpoint and the old `PATCH language` path all use it (ADR-13). Progression is unchanged because it already works per category; only the set of skills fed to it changed.

### Completed Work

- [x] `app/domain/course.py` (new) - `Course`, `CourseStatus`, `LanguagePair`, `CourseSummary`, `CourseSelectionPolicy` (activate check, resolve pair, fallback), `CourseRepository` protocol
- [x] `app/domain/exceptions.py`, `value_objects.py`, `entities.py`, `services.py` - `CourseNotFound`/`CourseNotAvailable` errors; language codes `am`/`om`/`en`; `PendingOnboardingSelection.from_language`; `User.active_course_id`; `activate_course_for_user`; signup resolves the pair to a course and rejects an unresolvable pair before any user exists; `UserPreferencesService` turns a `language` change into a course activation
- [x] `app/domain/lesson/*` - `Category.course_id`, `VocabItem.course_id`; `CategoryRepository.list_by_course`; course-scoped `list_due`/`count_due`; `LessonAccessPolicy.ensure_course_available` and `LessonCourseUnavailableError` (403)
- [x] `app/application/course_use_cases.py` (new) - `list_courses` (3 queries), `activate_course`
- [x] `app/application/lesson_use_cases.py`, `use_cases.py` - skill tree scoped to the active course and returns its `course`; lesson content and completion gated on the lesson's own course; due items/count filtered by course; signup passes `from_language` through
- [x] `app/infrastructure/db/*` - `CourseModel`; `course_id` on categories and vocab (per-course category order uniqueness); `users.active_course_id`; `SqlAlchemyCourseRepository`; category and due-query changes; seed defines English to Amharic and attaches existing content
- [x] Migration `b8e3f0a4c6d2` - creates `courses` with English to Amharic, backfills categories, vocab and users, then NOT NULL and FKs; downgrade reverses. Rehearsed on a copy of the real `dev.db`, then applied to it (backup `dev.db.bak-pre-024`)
- [x] `app/infrastructure/api/*` - `GET /api/v1/courses`, `PUT /api/v1/users/me/active-course`; skill-tree `course`; `active_course_id` on signup, session and preferences responses; optional `from_language` on signup; error mapping (404 `course_not_found`, 422 `course_not_available`, 403 for a lesson of an unavailable course)
- [x] Tests: existing fixtures updated for the new required fields; a fake course repository; every test database now starts with the English to Amharic course. Existing suite: 393 passed; ruff clean

### Key Decisions

- **`selected_language` kept as a mirror** (ADR-13), written only through `activate_course_for_user`.
- **Skill filtering in the use case**, not a new skill repository method: the tree loads all skills (already constant) and keeps those in the active course's categories. This reused the existing fakes and left `SkillRepository` unchanged.
- **Optional course parameters on use cases** (`course_repo`, `active_course_id`, `course_id`): omitted means unscoped. The HTTP routers always pass them; this kept about 45 existing unit tests unchanged. Stage 5 adds endpoint tests proving the routers scope and gate correctly.
- **Skills whose category is not in the active course are dropped** from the tree. Previously an orphan skill sorted last; three test fixtures that relied on a missing category row now create it.

### Deviations from Plan

- User responses (signup, session, preferences) carry `active_course_id` but not `from_language`, to avoid an extra course lookup on every session check. The client learns the language pair from `GET /courses` and the skill tree's `course`.
- The fallback when an active course later becomes `coming_soon` (design's `fallback_course`) exists in the policy but is not wired into any read path yet; no requirement depends on it and it can be added when a course is ever taken offline.

### Verify-at-Stage-4 Items Resolved

- Alembic head was `a7d1c5e29b04`; constraint names `uq_categories_order_index` and the unnamed `vocab_items` table needed no special handling.
- No existing uniqueness on `vocab_items` word fields, so a second course's vocab needs no constraint change.
- Signup, `UpdateUserPreferences` and Practice code paths read and amended as designed; performance and security tests still pass.

### Dependencies Added

None.

### Developer Notes

- `dev.db` now has the `courses` table, one course, and every existing category, vocab item and user linked to it. Restore with `backend/dev.db.bak-pre-024` if needed.
- Backend must be restarted to pick up the new routes.
- Not yet covered by new tests: the course list/switch endpoints, per-course progress isolation, Practice scoping, signup with a pair, migration test, and query counts. All are Stage 5.
