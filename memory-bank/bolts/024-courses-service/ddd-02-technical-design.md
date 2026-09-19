---
stage: design
bolt: 024-courses-service
created: '2026-09-20T14:40:00Z'
---

## Technical Design: courses-service

Stage 2 does not read source. Everything below rests on facts verified earlier in this session and during inception (`users.selected_language` String(8) validated by `LanguageCode`/`SUPPORTED_LANGUAGE_CODES` in `domain/value_objects.py`; the registration flow carrying `pending_selection.language` and `pending_language_code`; `PATCH /api/v1/users/me` with a `language` field; categories, per-category skill order and the additive skill-tree envelope from ADR-11; SRS keyed by `vocab_items`/`user_vocab_progress`; the Flutter client reading `selected_language` as a required string). Anything not verified is listed under "Verify at Stage 4".

### Architecture Pattern

Same layered pattern as the rest of the backend: pure domain rules in `domain/` (auth/user side) and `domain/lesson/`, use cases in `application/`, SQLAlchemy repositories in `infrastructure/db/`, FastAPI routers and schemas in `infrastructure/api/`. No new pattern; this amends existing layers and adds one small content level (`Course`) above `Category`.

### Layer Structure

```text
┌──────────────────────────────────────────────────┐
│ Presentation  course routers/schemas,             │  GET /courses, PUT active-course,
│               skill-tree + user + signup schemas  │  additive fields
├──────────────────────────────────────────────────┤
│ Application   list_courses, activate_course,      │  active course resolved once per request
│               get_skill_tree, complete_lesson,    │
│               practice due/count, register        │
├──────────────────────────────────────────────────┤
│ Domain        Course, LanguagePair, CourseStatus, │  CourseSelectionPolicy,
│               User.active_course_id,              │  PracticeSelectionPolicy (pure)
│               LessonAccessPolicy (course-aware)   │
├──────────────────────────────────────────────────┤
│ Infrastructure CourseModel, FKs on categories,    │  Alembic migration, repositories, seed
│                vocab_items, users                 │
└──────────────────────────────────────────────────┘
```

### Design Decisions (for your approval)

**D1. Active course is a column on `users` (recommended).**
`users.active_course_id` String(36), NOT NULL, FK to `courses.id`. One row per user, no history is needed, and the skill-tree read already loads the user. Alternative: a separate `user_active_course` table; rejected as an extra join and an extra write path for no benefit.

**D2. Fate of `users.selected_language`: keep it as a mirror of the active course's learning language (recommended).**
The shipped Flutter client reads `selected_language` as a required string in the session and preferences responses, so removing it would break the app until bolt 026. Decision: the column stays; it always equals the active course's `learning_language`; the **only** code that writes it is the new `ActivateCourse` operation (signup and switching both go through it). The from-language is not stored on the user; it is derived from the active course. `PATCH /users/me` keeps accepting `language` for older clients: it is translated into "activate the available course for (language, current from-language)", and fails with the existing invalid-preference error if none exists. Both responses gain `active_course_id` and `from_language` additively. This amends ADR-7 (its single sanctioned mutation path becomes: created by signup, changed only by `ActivateCourse`, which `UpdateUserPreferences` delegates to). Alternatives: drop the column (breaks the client), or repurpose it as the from-language (silent semantic change, confusing).

**D3. Vocab items carry an explicit `course_id` (recommended).**
`vocab_items.course_id` NOT NULL, FK, indexed. Practice's due query becomes one indexed filter: `user_vocab_progress` joined to `vocab_items` where `course_id = :active`. Deriving the course through exercise, lesson, skill and category needs four joins and misses vocab with no exercise. Backfilled to English to Amharic by the migration.

**D4. Category order is unique per course (recommended).**
Replace `UNIQUE(order_index)` on `categories` with `UNIQUE(course_id, order_index)`, mirroring ADR-11's per-category skill order. Each course then numbers its own categories from 1. Cost: a batch constraint swap on SQLite.

**D5. A lesson is startable/completable if its own course is `available`, regardless of the user's active course (recommended).**
This is required for a completion queued offline in course A that syncs after the user switched to B (ADR-6 replays the per-completion endpoint). Access is computed inside the lesson's own course: the progression policy runs on that course's skills only, so a locked skill is still 403 in every course. Progress is written against the lesson's skill, which already belongs to its course. Alternative (reject non-active-course lessons) would silently lose queued completions.

**D6. Skill-tree envelope stays additive and is scoped to the active course.**
`GET /skill-tree` returns only the active course's categories and skills (ordered as today) plus a new `course` object `{id, learning_language, from_language, title}`. All existing fields, including the deprecated `unit_title`/`unit_subtitle`, are unchanged. The client uses `course.id` as its cache key.

**D7. Signup carries the pair; the from-language is optional and defaults to `en`.**
The registration request and `PendingOnboardingSelection` gain an optional `from_language`. Absent means `en`, so the shipped client (which sends only a language) keeps creating English to Amharic accounts. An unresolvable pair (no `available` course) rejects signup with the existing invalid-selection error and creates no user.

**D8. Language codes.**
`LanguageCode` accepts `am`, `om`, `en`. Whether a language can be learned is decided by course existence, not by the constant: no course has `learning_language = en`, so learning English is rejected as "no available course" everywhere.

**D9. One migration revision, data-preserving.**
1. Create `courses`.
2. Insert English to Amharic with deterministic id `uuid5(CONTENT_NAMESPACE, "course:en-am")`, re-derived inline with the same namespace as the seed (`uuid5(NAMESPACE_DNS, "buna.app/lesson-content")`; the migration must not import app code), status `available`, `order_index` 1. The seed later upserts the same row.
3. `categories.course_id`: add nullable, backfill all five categories, batch-alter NOT NULL + FK, swap the unique constraint (D4).
4. `vocab_items.course_id`: add nullable, backfill, NOT NULL + FK + index.
5. `users.active_course_id`: add nullable, backfill every user to English to Amharic, NOT NULL + FK.
6. Downgrade reverses in opposite order; restoring `UNIQUE(order_index)` on categories is safe only while order values stay globally unique (documented in the migration).
No skill, lesson, exercise, progress, attempt, XP, Amole, or vocab-progress row is altered. Backup `backend/dev.db` before applying it.

**D10. Seed change in this bolt is minimal.**
With NOT NULL columns, the existing seed can no longer insert categories or vocab. Bolt 024 makes the smallest seed change: define the English to Amharic course and attach the existing categories and vocab to it. New courses are bolt 025.

### Data Model

- **`courses`** (new): `id` String(36) PK; `learning_language` String(8) NOT NULL; `from_language` String(8) NOT NULL; `title` String(255) NOT NULL; `status` String(16) NOT NULL (`available` | `coming_soon`; CHECK constraint); `order_index` Integer NOT NULL; `created_at` timestamp. `UNIQUE(learning_language, from_language)`; `UNIQUE(order_index)`; CHECK `learning_language <> from_language`.
- **`categories`** (amended): `course_id` NOT NULL FK; `UNIQUE(order_index)` replaced by `UNIQUE(course_id, order_index)`; index on `course_id`.
- **`vocab_items`** (amended): `course_id` NOT NULL FK; index on `course_id`. Any existing uniqueness on the word itself may need to become per course (verify).
- **`users`** (amended): `active_course_id` NOT NULL FK; `selected_language` retained as mirror (D2).
- **Domain**: `Course` frozen dataclass; `CourseStatus`; `LanguagePair`; `Category` gains required `course_id`; `VocabItem` gains required `course_id`; `User` gains required `active_course_id`. Required, not defaulted, so an orphan is unrepresentable (test fixtures need updating; use shared helpers).

### API Design

- **`GET /api/v1/courses`** (auth): `{ active_course_id, courses: [ { id, learning_language, from_language, title, status, order_index, is_active, completed_skills, total_skills } ] }`, ordered by `order_index`. Coming-soon courses included with 0/0. Three queries regardless of course count (courses; skill totals grouped by course; user completed skills grouped by course).
- **`PUT /api/v1/users/me/active-course`** (auth): request `{ course_id }`; success `200 { active_course_id, selected_language, course }`. Errors in the existing `{error_code, message}` shape: `404 course_not_found`; `422 course_not_available` for `coming_soon`. Unchanged active course on any error. Switching to the current course succeeds with no change.
- **`GET /api/v1/skill-tree`**: scoped to the active course; adds `course` (D6).
- **`GET` Practice due/count endpoints**: shape unchanged; results limited to the active course's vocab. Practice answer submission unchanged.
- **`POST` registration / signup**: optional `from_language` (D7); response user gains `active_course_id`, `from_language`.
- **`PATCH /api/v1/users/me`**: `language` still accepted (D2).
- `GET /lessons/{id}` and `POST /lessons/{id}/complete`: behaviour per D5.

### Progression and Access Behaviour (exact rules)

- Course-scoped skill states use the existing `SkillTreeProgressionPolicy` on the course's skills only: per category ordered by `order_index`; row present = COMPLETED/ACTIVE; no row = ACTIVE if first in its category else LOCKED.
- New to a course: no progress rows exist, so the first skill of each category is ACTIVE on the fly, no stored rows required.
- Lesson access: lesson to skill to category to course; course must be `available`; skill state (computed within that course) must not be LOCKED, else 403.
- Completion unlock: `SkillPath.next_after` within the category (ADR-11); cannot cross courses because categories belong to one course.
- Active course becoming `coming_soon` later: `CourseSelectionPolicy.fallback_course` (first available by `order_index`) is used on the next read and persisted through `ActivateCourse`.
- XP, streak, Beans, Amole: no course reference; unchanged.

### Security Design

- All new endpoints require an authenticated session and act only on the caller.
- The server validates course id and availability; the client-sent language, from-language or course is never trusted beyond that lookup (NFR-5).
- No new sensitive data. Errors do not reveal other users' data.

### NFR Implementation

- **Performance (NFR-2)**: `get_skill_tree` adds one query (the course row for `users.active_course_id`) and the categories query gains a `course_id` filter; grouping stays in memory. Course list is constant at three queries. Practice due/count remain single indexed queries. The existing performance test bound must be re-checked (expected +1 on skill tree).
- **Data integrity (NFR-1)**: nullable-add, backfill, then NOT NULL inside one migration; migration test on a populated database plus a downgrade round trip.
- **Reliability**: `ActivateCourse` is the single writer of `active_course_id` and the `selected_language` mirror, in one transaction, so they cannot diverge.

### Anticipated ADRs (Stage 3)

- **ADR-12**: Courses as the top content level; explicit `course_id` on categories and vocab; active course stored on `users`; additive skill-tree envelope; lessons accessed by their own course.
- **ADR-13**: Amend ADR-7 so `selected_language` becomes a mirror written only by `ActivateCourse`, with `UpdateUserPreferences` delegating to it.

### Test Plan (detail at Stage 5)

- **Unit**: `CourseSelectionPolicy` (can_activate, resolve_for_pair, fallback); `LanguagePair`/`Course` validation (same language, unsupported code); `PracticeSelectionPolicy`; course-aware `LessonAccessPolicy`.
- **Integration**: course list order, one active, coming-soon included, 3 queries; switch success/persists across login, coming-soon 422, unknown 404, unchanged on failure; signup with pair (am to om) activates it, unresolvable pair rejected with no user; skill tree scoped to active course; progress in course A unchanged after switching to B and back; completing in A leaves B unchanged; queued-style completion of a non-active course lesson recorded to its own course; locked skill 403 in a non-first category of another course; Practice due count/items only the active course's; `PATCH language` compatibility; old-style signup (no from-language) gives English to Amharic.
- **Migration**: upgrade on a populated DB preserves rows, backfills users/categories/vocab; downgrade round trip.
- **Regression**: full existing backend suite; performance test.

### Verify at Stage 4 (not verified in this source-blind stage)

- Current alembic head, and the real constraint names on `categories` and `vocab_items`.
- The exact registration/onboarding code path, `PendingOnboardingSelection`, `AccountCreationService`, `UpdateUserPreferences`, and how invalid selections map to errors.
- Real names of the Practice due/count use cases and endpoints, and their query shapes.
- Whether anything besides the two services and repositories relies on global category or skill ordering.
- Any existing uniqueness on `vocab_items` word fields.
- The performance test's actual query-count assertion, and test fixtures that build `User`, `Category` or `VocabItem`.
- Every place that validates a language code (signup, preferences, schemas) for the new `en` code.

### Story Coverage

- 001: `Course`, `courses` table, D4, D9, D10, `CourseRepository`.
- 002: D1, D2, D7, D8, `ActivateCourse`, `PUT active-course`, signup and `PATCH` changes.
- 003: `GET /courses`, `CourseSummary`, constant query count.
- 004: D5, D6, course-scoped skill tree, access and completion.
- 005: D3, `PracticeSelectionPolicy`, course-filtered due queries.
