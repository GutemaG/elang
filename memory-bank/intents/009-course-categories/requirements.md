---
intent: 009-course-categories
phase: inception
status: approved
created: '2026-09-19T19:00:00Z'
updated: '2026-09-19T19:00:00Z'
---

# Requirements: Course Categories

## Intent Overview

Introduce a real **category** (unit) level above skills so the app can offer multiple course categories, and seed four new categories with real Amharic content. Type: Enhancement (schema + API + UI + content).

**Verified against real source before writing** (not assumed):
- There is no category/unit concept anywhere. `skills` is a flat table (`id, title, order_index`, global `uq_skills_order_index`); `GET /skill-tree` returns one flat `skills` list plus a **hardcoded** `UNIT_TITLE = "Unit 1: Foundations & Greetings"` / `UNIT_SUBTITLE` (`lesson_use_cases.py:69`), which the Flutter `_UnitBanner` renders once.
- Progression is a single linear chain by global `order_index`: `SkillTreeProgressionPolicy.compute_states` makes only the first skill active for a new user, and `LessonCompletionService` unlocks `ordered[current_index + 1]` over ALL skills. Both must become category-aware.
- The seed (`seed_lesson_content.py`) has 2 skills x 2 lessons and 8 vocab items; it is idempotent via deterministic uuid5 slugs.
- Vocab/SRS (008) and offline packs (003) key off exercises/lessons, not skills, so new content flows into Practice and downloads without changes.

## Business Goals

| Goal | Success Metric | Priority |
|------|----------------|----------|
| Let the learner pick from multiple course categories rather than one linear list | Dashboard shows 5 categories, each with its own banner and skill path | Must |
| Demonstrate every exercise type across varied real content | Each new category has lessons using multiple_choice, listening, sentence_construction, and >= 1 match_pairs | Must |
| Keep everything already shipped working | Zero regression across existing backend/Flutter suites; existing users' progress preserved | Must |

## Functional Requirements

### FR-1: Category Content Model
- **Description**: New `categories` table (`id`, `title`, Amharic `subtitle`, `order_index`). New `skills.category_id` FK (NOT NULL). A migration creates the first category "Foundations & Greetings" (subtitle `ሰላምታ እና ፊደል መግቢያ`) and assigns the two existing skills to it.
- **Acceptance Criteria**:
  - After migration every skill has a category; no skill/lesson/exercise row is lost or altered other than gaining `category_id`
  - Migration upgrades a database that already contains users and progress, and downgrades cleanly
  - Categories are ordered by `order_index`; skills within a category by `order_index`
- **Priority**: Must

### FR-2: Per-Category Progression (all categories open)
- **Description**: Progression becomes linear **within** a category, with every category open. For a user with no progress row, the first skill of **each** category is active and the rest of that category is locked. Completing a skill unlocks the next skill in the **same category** only; the last skill of a category unlocks nothing further. `LessonAccessPolicy`/`state_for_skill` and the skill-tree read must use the same rule so they cannot disagree.
- **Acceptance Criteria**:
  - A brand-new user sees exactly one active skill per category and all others locked
  - Completing skill N of a category unlocks skill N+1 of that category and does not affect other categories
  - Completing a category's final skill unlocks nothing and does not error
  - A locked skill's lesson is still unreachable by direct lesson id (403), in every category
  - Existing users: a completed Greetings skill keeps its state and crown level; Food & Drink stays active/completed as before
- **Priority**: Must

### FR-3: Skill-Tree API Exposes Categories
- **Description**: `GET /api/v1/skill-tree` returns categories (id, title, subtitle, order) and each skill carries its `category_id`. The hardcoded `UNIT_TITLE`/`UNIT_SUBTITLE` are removed. The change is **additive** where feasible (existing skill fields preserved); exact envelope is a Technical Design/ADR decision.
- **Acceptance Criteria**:
  - Response lists every category in order, each skill mapped to exactly one category
  - Query count for the skill-tree read stays constant (does not grow per category or per skill)
  - Existing response fields consumed by the client (`state`, `crown_level`, `lesson_id`, `content_version`, HUD stats) are unchanged
- **Priority**: Must

### FR-4: Seed Four New Categories With Real Content
- **Description**: Extend the idempotent seed with four categories, each with 2 skills x 2 lessons, real hand-authored English -> Amharic (Fidel) content, ~4-5 exercises per lesson: **Family & People**, **Numbers & Time**, **Travel & Places**, **Colors, Body & Health**. Multiple-choice "how do you say X" exercises link to new `vocab_items` (feeds Practice/SRS automatically). Every category includes at least one `match_pairs` exercise.
- **Acceptance Criteria**:
  - Re-running the seed creates no duplicates and edits in place (existing idempotency guarantee holds)
  - Each new category has 2 skills, each skill 2 lessons, each lesson >= 4 exercises drawn from >= 3 exercise types
  - All exercises satisfy existing content validation (answer keys reference real choices; sentence-construction sequences use only bank words; match-pair ids are consistent)
  - New vocab is `vocab_items`-linked where a single clear word is tested
  - Audio URLs use the existing placeholder (known limitation carried over; no real audio in scope)
- **Priority**: Must

### FR-5: Dashboard Groups Skills by Category
- **Description**: The dashboard remains a single scroll. Each category renders a banner (title, Amharic subtitle, "x/y Completed", progress bar, matching today's `_UnitBanner`) followed by that category's skill path. The lateral zig-zag offset restarts per category. Practice card and HUD stay above the first category.
- **Acceptance Criteria**:
  - N categories render N banners in order, with correct per-category completed counts
  - Locked/active/completed states, crown levels, download affordances, and tap-to-start behavior are unchanged per skill
  - No horizontal overflow at 360dp width
- **Priority**: Must

### FR-6: Existing Flows Unaffected
- **Description**: Lesson-taking, Beans, XP/streak/Amole awards, offline download/sync, Practice/SRS, and settings behave exactly as before for new-category content.
- **Acceptance Criteria**:
  - Completing a lesson in a new category awards XP/Amole, updates streak, and creates vocab progress rows
  - A new-category lesson can be downloaded and taken offline
  - Full existing backend and Flutter suites pass unchanged (aside from fixtures needing the new field)
- **Priority**: Must

## Non-Functional Requirements

### NFR-1: Data Integrity
- Migration is non-destructive and reversible; existing `user_skill_progress`, attempts, XP, Amole and vocab progress are untouched.

### NFR-2: Performance
- Skill-tree read keeps a constant query count (no per-category N+1); response time not regressed against the existing performance test.

### NFR-3: Content Quality
- Amharic content is authored by the agent and is **not native-speaker reviewed**. It is suitable for demonstrating the product; a native-speaker proof-read is a required manual step before any real release. This is recorded, not silently assumed.

## Scope

**In scope**: categories table/FK/migration; category-aware progression; skill-tree API + Flutter model/dashboard; four seeded categories; tests.

**Out of scope**: category-picker screen; cross-category prerequisites; per-category streaks/XP; real audio; speak-check (006); category-level Practice filtering; admin/content-management UI.

## Open Questions (for Technical Design, not Inception)
- Keep the global `uq_skills_order_index` or make it unique per category?
- Exact response envelope (`categories[].skills[]` nested vs flat skills + `categories` list).
- Where "next skill within category" lives so the completion service and progression policy share one definition.
