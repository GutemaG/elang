---
bolt: 024-courses-service
created: '2026-09-20T15:05:00Z'
status: accepted
superseded_by: null
---

# ADR-12: Courses as the top content level: explicit `course_id` on categories and vocab, active course on `users`, additive skill-tree envelope, lessons accessed by their own course

## Context

The app has one implicit course (English to Amharic). Intent 010 needs several, each a (learning language, from-language) pair, so an Amharic speaker with no English can learn Afaan Oromo and the reverse. Facts that constrain the design:

- Content is a hierarchy of categories (ADR-11), skills, lessons and exercises; vocab items feed SRS/Practice (ADR-10). None carries a language or course.
- Progress rows (`user_skill_progress`, `user_vocab_progress`) are keyed by skill and vocab item, so once content belongs to a course, progress separates per course with no new column.
- Offline completions are replayed against the per-completion endpoint (ADR-6), possibly after the user has switched course.
- The shipped Flutter client parses the skill-tree response strictly, so removals would break it between the backend bolt and the UI bolts (ADR-10, ADR-11 precedent).

## Decision

1. **A `courses` table sits above categories**: `id`, `learning_language`, `from_language`, `title`, `status` (`available` | `coming_soon`), `order_index`; unique per language pair; the two languages must differ.
2. **`course_id` is explicit on `categories` and on `vocab_items`** (NOT NULL FK). Skills, lessons and exercises reach their course through their category. Category `order_index` becomes unique per course.
3. **The active course is `users.active_course_id`** (NOT NULL FK), written only by an `ActivateCourse` operation.
4. **The skill-tree envelope stays additive**: it is scoped to the active course and gains a `course` object; every existing field, including the deprecated `unit_title`/`unit_subtitle`, is unchanged.
5. **A lesson is startable and completable when its own course is `available`**, regardless of the user's active course. Skill access is computed inside the lesson's own course, so locked skills remain 403 everywhere.
6. **Practice is scoped by `vocab_items.course_id`** against the active course.
7. **The migration** creates English to Amharic with a deterministic id and backfills every existing category, vocab item and user to it.

## Rationale

Making the course a real level keeps progression, Practice and offline data separable with plain foreign keys, and needs no change to progress tables or the exercise model. An explicit `course_id` on vocab makes Practice a single indexed filter instead of a four-join derivation. Accessing lessons by their own course, not the active one, is what lets a queued offline completion in course A sync correctly after the user has switched to B, without weakening the locked-skill check. The additive envelope follows ADR-10 and ADR-11 so the shipped app keeps working at every intermediate commit.

### Alternatives Considered

| Alternative | Pros | Cons | Why Rejected |
|-------------|------|------|--------------|
| Derive vocab's course through exercises, lessons, skills, categories | No new column on `vocab_items` | Four joins per Practice query; vocab with no exercise has no course | Explicit column is simpler and cheaper |
| Store `active_course_id` in a separate table | Room for history | Extra join and write path; no history needed | Column on `users` is enough |
| Require a lesson's course to equal the active course | Simpler access rule | Queued offline completions after a switch would be rejected and lost | Breaks ADR-6's replay model |
| Nested `courses[].categories[].skills[]` skill-tree response | Cleaner shape | Breaks the shipped client until the UI bolts land | Additive envelope is safe at every commit |
| Per-course progress tables | Explicit isolation | Duplicates existing tables and logic | Isolation already follows from content ownership |
| Separate databases or deployments per language | Hard isolation | Cross-language accounts, XP, streak and Amole become impossible | Account-wide values must stay shared |

## Consequences

### Positive

- Any (learning, from) pair is a data change: add a course and its content, no code change.
- Progress, Practice and offline data separate per course through ownership alone.
- The shipped app keeps working after this bolt alone.
- Queued offline completions survive a course switch.

### Negative

- The migration touches four tables and swaps a unique constraint (SQLite batch mode); downgrade is safe only while category order values are globally unique.
- `Category`, `VocabItem` and `User` gain required fields, so many test fixtures change.
- Vocab is duplicated per course by design (the same English word in two courses is two items).

### Risks

- Risk: a later code path assumes one global course. Mitigation: tests assert independence between courses (completing in A changes nothing in B; Practice returns only the active course).
- Risk: an active course later becomes `coming_soon`. Mitigation: a deterministic fallback to the first available course, persisted through `ActivateCourse`.
- Risk: existing uniqueness on vocab words blocks a second course's vocab. Mitigation: verified at Stage 4; make it unique per course if needed.

## Related

- **Stories**: 001-course-model-and-migration, 002-active-course-per-user, 003-course-list-api, 004-course-scoped-skill-tree-and-progress, 005-course-scoped-practice
- **Standards**: none new (data-stack's "courses → units → lessons" hierarchy anticipated this level)
- **Previous ADRs**: builds on ADR-11 (categories, additive envelope), ADR-10 (additive widening), ADR-6 (offline replay), ADR-3 (content tables); ADR-13 covers the `selected_language` amendment
