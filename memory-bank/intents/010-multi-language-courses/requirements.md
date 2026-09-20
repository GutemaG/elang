---
intent: 010-multi-language-courses
phase: inception
status: complete
created: '2026-09-20T12:00:00Z'
updated: '2026-09-20T13:40:00Z'
---

# Requirements: Multi-Language Courses

## Intent Overview

Let a learner pick from a list of courses and switch between them, Duolingo-style, with the choice saved. A **course** is a (learning language, from-language) pair, so an Amharic speaker who does not speak English can learn Afaan Oromo, and the reverse, whenever content exists for that pair. Type: New Feature (schema + API + UI + content).

**Verified against real source before writing** (not assumed):
- The user has one `users.selected_language` string, validated by `LanguageCode` against `SUPPORTED_LANGUAGE_CODES`. It means "target language" only; there is no from-language.
- `categories`, `skills`, `lessons`, `exercises` and `vocab_items` carry no course/language field. The single course is implicit (English to Amharic).
- Progress (`user_skill_progress`, `user_vocab_progress`) is keyed by skill and vocab item, so once content belongs to a course, progress separates per course naturally.
- Flutter has two hardcoded course lists (onboarding `language_selection_screen.dart` and `settings_screen.dart`): Amharic live, Afaan Oromo disabled "coming soon". Changing the language in Settings has no visible effect today.
- The app interface is English only.

## Business Goals

| Goal | Success Metric | Priority |
|------|----------------|----------|
| Let learners choose and switch courses, with the choice saved | Course list on the dashboard; selection persists across restarts and devices | Must |
| Support any-language-speaker to any-language courses | Amharic speaker with no English can take Amharic to Afaan Oromo; Afaan Oromo speaker can take Afaan Oromo to Amharic | Must |
| Keep everything already shipped working | Existing suites pass; existing users land on their English to Amharic course with progress intact | Must |

## Functional Requirements

### FR-1: Course Model
- **Description**: New `courses` table (`id`, `learning_language`, `from_language`, `title`, `status` = `available` | `coming_soon`, `order_index`), unique per (learning, from) pair. `categories` gain a NOT NULL `course_id`. A migration creates the course English to Amharic (`en`->`am`) and assigns the five existing categories to it.
- **Acceptance Criteria**:
  - After migration every category belongs to a course; no skill, lesson, exercise, vocab or progress row is lost or altered
  - Migration upgrades a database that already has users and progress, and downgrades cleanly
  - Language codes are `am`, `om`, `en`; an unknown code is rejected
  - A pair can exist as `coming_soon` with no content
- **Priority**: Must

### FR-2: Active Course Saved Per User
- **Description**: Each user has one active course, stored on the server so it survives restarts and other devices. Existing users are migrated to `en`->`am`. New endpoints read and change it. Only `available` courses can be selected.
- **Acceptance Criteria**:
  - Switching returns the new active course and it is still active after logout/login
  - Selecting a `coming_soon` or unknown course fails with a clear error and changes nothing
  - Existing users' active course is `en`->`am`
  - The old `selected_language` no longer disagrees with the active course (exact handling is a Technical Design decision)
- **Priority**: Must

### FR-3: Course List API
- **Description**: `GET` returns every course (available and coming soon) with learning language, from-language, title, status and whether it is the user's active course. Optional per-course progress summary (completed / total skills).
- **Acceptance Criteria**:
  - List is ordered and stable; coming-soon courses are included and marked
  - Exactly one course is marked active for the user
  - Query count is constant (no per-course N+1)
- **Priority**: Must

### FR-4: Course-Scoped Skill Tree and Progress
- **Description**: The skill tree returns the categories and skills of the user's active course only. Crowns, unlocked skills and lesson attempts are tracked per course through the skill they belong to. Completing a lesson in one course never changes another. A user new to a course sees the first skill of each category active, as today.
- **Acceptance Criteria**:
  - Switching courses shows that course's categories and its own skill states
  - Switching back restores the earlier states and crowns exactly
  - XP, streak, Beans and Amole stay account-wide and are unchanged by switching
  - A locked skill's lesson still returns 403; a lesson of an unavailable course is not startable
  - Existing skill-tree response fields consumed by the client are unchanged
- **Priority**: Must

### FR-5: Course-Scoped Practice (SRS)
- **Description**: Practice and the dashboard due count use only vocab from the active course. Words from other courses keep their schedule and reappear when the user switches back.
- **Acceptance Criteria**:
  - Due count and Practice session contain only active-course words
  - Practice answers update only that word's Leitner box
  - Switching course changes the due count on the dashboard after refresh
- **Priority**: Must

### FR-6: Offline Behaviour Per Course
- **Description**: The cached skill tree and downloaded lesson packs are keyed by course. Switching course while offline works for a course that has been cached and shows a clear message for one that has not. Queued offline completions sync correctly whichever course they belong to.
- **Acceptance Criteria**:
  - A tree cached for course A is not shown while course B is active
  - Downloaded packs of both courses are kept; Manage Downloads shows which course each belongs to
  - Switching to an uncached course offline shows a message and keeps the current course
  - A completion queued in course A syncs to course A even if the user has since switched to B
- **Priority**: Must

### FR-7: Course Switcher UI
- **Description**: A course chip in the dashboard top bar opens a course list. It is grouped by "I want to learn" language, offers a from-language for each, disables coming-soon courses, and marks the active one. Selecting saves and reloads the dashboard. Settings uses the same picker; the two hardcoded lists are removed.
- **Acceptance Criteria**:
  - The list is driven by the course API, not hardcoded
  - Coming-soon courses render disabled and cannot be selected
  - Selecting a course closes the picker and shows that course's dashboard
  - No overflow at 360dp with long titles and 1.3x text
  - The selection request failing offline or with an error leaves the current course active and shows a message
- **Priority**: Must

### FR-8: Onboarding Asks the Language Pair
- **Description**: Onboarding asks "I speak" and "I want to learn" and only offers available pairs. The pending selection stores both; account creation activates that course.
- **Acceptance Criteria**:
  - Choosing Amharic as spoken language offers Afaan Oromo as a learning option (and the reverse), with no English required
  - A pair with no available course cannot be continued
  - The chosen course is active after signup
  - Existing onboarding tests updated, not deleted
- **Priority**: Must

### FR-9: Seed Afaan Oromo Starter Courses
- **Description**: Extend the idempotent seed with three available courses: English to Afaan Oromo, Amharic to Afaan Oromo, Afaan Oromo to Amharic. Each has one category "Foundations & Greetings" with 2 skills x 2 lessons, >= 4 exercises per lesson from >= 3 exercise types, and >= 1 `match_pairs`. Prompts appear in the from-language, answers in the learning language. Afaan Oromo is written in Latin script, Amharic in Fidel.
- **Acceptance Criteria**:
  - Re-running the seed creates no duplicates
  - All exercises satisfy existing content validation, including match-pair ids and sentence-construction word banks
  - Multiple-choice vocabulary items link to course-specific `vocab_items`, so Practice works in each course
  - Audio URLs use the existing placeholder (known limitation)
  - Remaining pairs (for example English to Afaan Oromo variants beyond these) can be listed as coming soon
- **Priority**: Must

### FR-10: Existing Flows Unaffected
- **Description**: Lesson taking, Beans, XP/streak/Amole awards, offline download/sync, Practice, categories and settings behave as before in the English to Amharic course.
- **Acceptance Criteria**:
  - Existing backend and Flutter suites pass, aside from fixtures needing the new fields
  - Skill-tree query count stays constant
- **Priority**: Must

## Non-Functional Requirements

### NFR-1: Data Integrity
- Migration is non-destructive and reversible; existing users, progress, attempts, XP, Amole, vocab progress and downloads are preserved.

### NFR-2: Performance
- Skill-tree, course-list and Practice reads keep constant query counts; no regression against existing performance tests.

### NFR-3: Content Quality
- All Afaan Oromo content and its Amharic/Afaan Oromo translations are agent-authored and **not native-speaker reviewed**. Suitable to demonstrate the product; native review is required before release. Recorded, not silently assumed.

### NFR-4: Script Rendering
- Fidel and Latin text both render correctly in exercises, word banks and the picker, with no font fallback boxes, on Android at 360dp.

### NFR-5: Security
- Only authenticated users may read or change their active course; the server validates the course id and availability, never trusting the client.

## Scope

**In scope**: courses table, category-to-course link, migration; active course per user; course list and switch API; course-scoped skill tree, progress, Practice, offline cache and packs; dashboard switcher, Settings picker and onboarding pair; three seeded Afaan Oromo starter courses; tests.

**Out of scope**: translating the app interface (buttons, menus); real audio; more than one category per new course; per-course streaks/XP/Amole; admin/content tooling; a waitlist backend for coming-soon courses; speak-check (006).

## Open Questions (for Technical Design, not Inception)
- Fate of `users.selected_language`: drop, keep in sync with the active course, or repurpose as from-language.
- Whether `vocab_items` are per course (recommended) or shared with a translation table.
- Whether a lesson in a non-active course can be completed (queued offline case) or is rejected.
- Exact API envelope and cache key format for the offline skill tree.
