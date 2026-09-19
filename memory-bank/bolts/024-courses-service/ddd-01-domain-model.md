---
stage: model
bolt: 024-courses-service
created: '2026-09-20T14:05:00Z'
---

## Static Model: courses-service

### Entities

- **Course** (new): `id`, `learning_language`, `from_language`, `title`, `status` (`available` | `coming_soon`), `order_index`, `created_at`. Content only, no per-user state. Business rules: the pair (`learning_language`, `from_language`) is unique; the two languages differ; both are supported language codes; a `coming_soon` course may hold zero categories; only an `available` course can be studied or selected.
- **Category** (existing, extended): gains a required `course_id`. Business rules: every category belongs to exactly one course; a category's position inside its course is given by its `order_index`.
- **Skill, Lesson, Exercise** (existing, unchanged): reach their course only through their category (skill to category to course). Nothing new is stored on them.
- **VocabItem** (existing, extended, see open question 2): a vocab item is the answer to a "how do you say X" question in one direction, so "hello" in English to Amharic and "hello" in English to Afaan Oromo are different items. Modelled as belonging to exactly one course.
- **User** (existing, extended): gains an **active course** reference. Business rules: a user has exactly one active course; it must reference an `available` course; a new user's active course is the course matching their onboarding pair.
- **UserSkillProgress, UserVocabProgress, LessonAttempt** (existing, unchanged): still per user and per skill / vocab item / lesson. Because skills and vocab items now belong to a course, progress is separate per course without any new column. XP, streak, Beans and Amole stay account-wide (no course reference).

### Value Objects

- **LanguageCode** (existing, extended): `am`, `om`, `en`. An unsupported code is rejected. (`en` was not a valid selected language before; it is now valid as a from-language.)
- **CourseStatus**: `available` or `coming_soon`. Equality by value.
- **LanguagePair**: (`learning`, `from`). Equality by value; the two must differ.
- **CourseSummary** (derived, read-side): `course`, `is_active`, `completed_skills`, `total_skills`. Computed for the list, never stored.

### Aggregates

- **Course** (aggregate root, content only). It does not contain categories; categories reference it by id, the same approach as `Category`/`Skill` in ADR-11, so category, skill and lesson aggregates stay untouched apart from `Category.course_id`.
- **User** (aggregate root, amended): new invariant - `active_course_id` must reference an existing, `available` course. The old invariant on `selected_language` (write-once, ADR-7) has to be reconciled with this (open question 1).
- **VocabItem** (aggregate root): new invariant - `course_id` references an existing course.

### Domain Events

- **ActiveCourseChanged**: Trigger: the user switches course, or signup activates the onboarding pair. Payload: `user_id`, `course_id`. Effect: the skill tree, due count and Practice items now resolve against the new course. Documented as a conceptual trigger; the codebase uses return values instead of event objects (same convention as bolts 019 and 021).
- **AccountCreatedWithPair**: Trigger: signup completes with a pending onboarding selection holding a language pair. Payload: `user_id`, `learning_language`, `from_language`. Effect: the matching course becomes the user's active course; if no available course matches, account creation is rejected.
- **SkillCompleted** (existing, unchanged in meaning): still unlocks the next skill in the same category's path (`SkillPath`, ADR-11). Because a category belongs to one course, an unlock can never cross courses.

### Domain Services

- **CourseSelectionPolicy** (new, pure): Operations: `can_activate(course) -> bool` (true only for `available`), `resolve_for_pair(pair, courses) -> Course | None`, `fallback_course(courses) -> Course` (used if the active course stops being available; deterministic, first available by `order_index`). No I/O.
- **SkillTreeProgressionPolicy** (existing, unchanged): receives only the skills of the active course, so its per-category "first skill active" rule now applies inside that course. No rule change.
- **LessonAccessPolicy** (existing, amended): a lesson is startable only if its state is not locked (as today) and its course is `available`. Whether it must also equal the user's *active* course is open question 3.
- **PracticeSelectionPolicy** (new, pure): Operations: `due_items(vocab_progress, now, course_id)` - due words are those whose vocab item belongs to the course. The Leitner math (`next_box`, intervals) is unchanged.
- **AccountCreationService** (existing, amended): reads the pending selection's language pair, resolves it through `CourseSelectionPolicy.resolve_for_pair`, and sets the new user's active course; unresolvable pair is a domain error, no user created.
- **LessonCompletionService** (existing, unchanged): unlock logic already category-local; XP/streak/Amole unchanged.

### Repository Interfaces

- **CourseRepository** (new): Entity: `Course`. Methods: `list_all() -> list[Course]` ordered by `order_index`; `get(course_id)`; `find_by_pair(learning, from)`.
- **UserRepository** (existing, amended): `set_active_course(user_id, course_id)`; loaded `User` carries `active_course_id`.
- **CategoryRepository** (existing, amended): `list_by_course(course_id)` ordered by `order_index`.
- **SkillRepository** (existing, amended): skills for a set of categories / a course, without a per-category query.
- **VocabRepository / due-item queries** (existing, amended): due items and due count filtered by `course_id`.
- **UserSkillProgressRepository, LessonRepository, exercise repositories**: unchanged.

### Ubiquitous Language

- **Course**: what a learner studies: one language (the learning language) taught from another (the from-language). Replaces the implicit single course.
- **Learning language / From-language**: the language being learned and the language the prompts and translations are written in.
- **Language pair**: the (learning, from) combination that identifies a course.
- **Active course**: the one course whose skill tree, Practice and downloads the user currently sees; saved on the account.
- **Available / Coming soon**: a course can be studied only when `available`.
- **Course-scoped**: progress, vocab and Practice that belong to one course. XP, streak, Beans and Amole are account-wide instead.
- **English to Amharic**: the existing course; every existing category, skill and user is migrated into it.

### Open Questions Carried to Technical Design (flagged, not resolved here)

1. What happens to `users.selected_language`: drop it, keep it in sync with the active course's learning language, or repurpose it as the from-language. ADR-7 constrains this: its write-once rule and its single sanctioned mutation path (`UpdateUserPreferences`) will need an explicit amendment.
2. Whether `vocab_items` carries an explicit `course_id` (recommended: simple Practice filter, direct integrity) or derives the course through its exercises.
3. Whether completing a lesson that belongs to a non-active course is allowed. It matters for queued offline completions after a later switch. Likely: allow it, recorded against the lesson's own course, provided the course is `available`.
4. Whether `categories.order_index` uniqueness becomes per course (mirrors ADR-11's per-category skill order).
5. Whether the active course is a column on `users` or a separate table.
6. The API envelope: skill-tree gains a `course` field additively (ADR-11 precedent) and how the client names the course when it asks for a list; cache key format is a UI-unit decision.
7. Migration on a populated database: create English to Amharic, backfill categories and vocab, set every user's active course, and downgrade safety.
8. Language-code set: `en` is new for `LanguageCode`; check every place that validates a code (signup, preferences).

### Story Coverage

- `001-course-model-and-migration`: `Course`, `CourseStatus`, `LanguagePair`, `LanguageCode` extension, `Category.course_id`, `VocabItem.course_id`, `CourseRepository`, backfill rule.
- `002-active-course-per-user`: `User.active_course_id`, `CourseSelectionPolicy`, `AccountCreatedWithPair`, `ActiveCourseChanged`, ADR-7 reconciliation (open question 1).
- `003-course-list-api`: `CourseSummary`, `CourseRepository.list_all`.
- `004-course-scoped-skill-tree-and-progress`: `CategoryRepository.list_by_course`, `SkillRepository`, `LessonAccessPolicy` amendment, open questions 3-4 and 6.
- `005-course-scoped-practice`: `PracticeSelectionPolicy`, `VocabItem.course_id`, due-item queries.
