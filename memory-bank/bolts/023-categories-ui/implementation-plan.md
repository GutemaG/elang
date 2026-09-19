---
stage: plan
bolt: 023-categories-ui
created: '2026-09-19T23:59:00Z'
---

## Implementation Plan: categories-ui

### Objective

Make the Flutter dashboard render one banner per course category, each with its own skill path, and verify that new-category lessons behave exactly like the original ones (complete, download, Practice, per-category unlock).

### Real-Source Findings (read at Plan stage)

- `SkillTreeResponse` (`lib/shared/models/skill_tree.dart`) holds a flat `nodes` list plus `unitTitle` / `unitSubtitle`. `SkillTreeNode` has no category. `completedCount` is computed over all nodes.
- `HttpLessonApi.getSkillTree` reads `unit_title` / `unit_subtitle` and maps `skills`. It ignores the new `categories` array and the per-skill `category_id`, which is why the phone currently shows one "Foundations & Greetings" banner above all ten skills.
- `FakeLessonApi.getSkillTree` returns a hardcoded "Unit 1" and four nodes, so it cannot exercise multi-category rendering.
- The dashboard (`skill_tree_dashboard_screen.dart`) builds `_UnitBanner(tree)` once, then one `Column` of all nodes using `_lateralOffset(i)` (i % 3: center / right / left). Nothing else reads `unitTitle`/`unitSubtitle` (grep of `lib/`); the offline pack code does not touch the skill tree.
- Tests that construct `SkillTreeResponse` with `unitTitle`: 8 sites in `skill_tree_dashboard_screen_test.dart`, plus `http_lesson_api_test.dart`, `controllable_lesson_api.dart` and `fake_lesson_api_test.dart` (which only calls it). The HUD, Practice card, download affordance and node widget do not depend on the category.
- Backend contract (bolt 021, ADR-11): `categories: [{id, title, subtitle, order_index}]` ordered, each skill has `category_id`, skills come ordered by category then order. `unit_title`/`unit_subtitle` are deprecated.

### Deliverables

- **Model**: new `SkillCategory` (id, title, subtitle). `SkillTreeNode` gains `categoryId`. `SkillTreeResponse` drops `unitTitle`/`unitSubtitle` and gains `categories` plus helpers `nodesIn(category)` and per-category completed count. `copyWith` keeps `categoryId`.
- **HTTP API**: parse `categories` and `category_id`. If the response has no `categories` (older backend), synthesize one category from `unit_title` / `unit_subtitle` and assign every node to it, so an older server still renders one banner instead of crashing. This is the only remaining reader of the deprecated fields.
- **Fake API**: return two categories (the existing four skills split into "Foundations & Greetings" and "Family & People") so the dev fake and widget tests cover multi-category.
- **Dashboard**: a `_CategorySection` per category, in order, = banner (title, Amharic subtitle, "x/y Completed", progress bar, per-category counts) + that category's skill path. The zig-zag restarts per category (index within category). HUD and Practice card stay above the first category. A category with no skills renders its banner with 0/0 and an empty progress bar, no crash.
- **Overflow**: banner title and subtitle get `maxLines` and ellipsis; the completed-count text is kept on one line. Verified at 360dp and 320dp.
- **Story 002 verification**: a backend-driven check plus Flutter widget tests (below), and a manual on-device pass.

### Dependencies

- Bolt 021: skill-tree `categories` / `category_id` contract, applied to `backend/dev.db`.
- Bolt 022: seeded content (five categories). Its completion script has not been run yet; it is functionally done and tested, so this bolt does not block on it, but it should be completed afterwards.

### Technical Approach

- Group nodes in `SkillTreeResponse` by `categoryId` using the API's category order; a node whose category id is unknown is ignored by grouping but still counted nowhere, so the parser is strict: it fails clearly (`FormatException` surfaced as `LessonApiException`) rather than hiding a skill.
- Keep `SkillPathNode`, the download affordance and `_onNodeTap` untouched, so existing skill behaviors (locked/active/completed, crown, download, tap-to-start) are unchanged.
- Replace the single `Column` with a `SliverList`-style list of sections inside the existing `CustomScrollView` (single scroll, as decided).
- Update existing tests' constructors via a small shared test helper rather than repeating category boilerplate.
- Story 002: (a) backend end-to-end tests already cover complete, XP, vocab rows and per-category unlock (bolt 022, `test_seeded_categories_end_to_end.py`); this bolt adds the Practice/due-items check against real seeded content if the API supports it, (b) Flutter tests: completing a lesson in a second category leaves the other category's nodes unchanged, and download affordance appears per node in every category, (c) manual check on the phone against the migrated `dev.db`.

### Test Plan

- Model: grouping, per-category counts, empty category.
- HTTP: parses categories, older response fallback, malformed category fails clearly.
- Fake API: two categories, completing a lesson unlocks only within its category.
- Dashboard widget: N categories render N banners with correct "x/y Completed"; zig-zag restarts per category; locked/active/completed states, crown and download affordance unchanged; no overflow at 360dp with long titles and 1.3x text scale; empty-category case.
- Full Flutter suite, `flutter analyze`.

### Acceptance Criteria

- [ ] N categories render N banners, in order, with correct counts and progress
- [ ] Each category's skills sit beneath its banner, zig-zag restarting per category
- [ ] No overflow at 360dp (and 320dp)
- [ ] Existing skill behaviors unchanged
- [ ] Model, HTTP and fake APIs parse and expose categories; the app no longer reads `unit_title` except as the older-server fallback
- [ ] Older response without `categories` still renders
- [ ] New-category lessons complete, download and unlock only within their category (tests)
- [ ] Full Flutter suite and `flutter analyze` pass
- [ ] Manual on-device check done by the user

### Open Decisions (my recommendation in bold)

- Old-server response: **fall back to one synthesized category** vs. fail with the retry screen. The fallback costs a few lines and keeps a mismatched dev backend usable.
- Out of scope, as decided earlier: category picker screen, collapsing categories.
