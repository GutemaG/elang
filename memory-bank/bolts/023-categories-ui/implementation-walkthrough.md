---
stage: implement
bolt: 023-categories-ui
created: '2026-09-20T00:30:00Z'
---

## Implementation Walkthrough: categories-ui

### Summary

The Flutter app now understands course categories. The skill-tree model, the HTTP and fake APIs, and the dashboard were changed so each category renders its own banner followed by its own skill path. An older backend that sends no categories still renders as a single banner.

### Structure Overview

Categories are a new value type beside the skill nodes. Every node carries the id of its category, and the response exposes the ordered category list plus a helper returning one category's nodes. The dashboard iterates the categories in order and renders a section per category inside the existing single scroll. Nothing about the skill node, download badge, HUD or Practice card changed.

### Completed Work

- [x] `lib/shared/models/skill_tree.dart` - new category type; skill nodes carry a category id; the tree response exposes categories and per-category node lookup; the deprecated unit title/subtitle fields are removed
- [x] `lib/shared/services/http_lesson_api.dart` - parses categories and each skill's category id; an older response without categories becomes one category from the deprecated unit fields; a skill in no known category fails clearly instead of disappearing
- [x] `lib/shared/services/fake_lesson_api.dart` - two categories (Foundations & Greetings, Numbers & Time) with two extra fake skills and lessons; unlocking a skill now only unlocks a later skill in the same category
- [x] `lib/features/lesson/screens/skill_tree_dashboard_screen.dart` - one section per category (banner plus path), zig-zag restarting per category, per-category completed count and progress bar, ellipsis on banner text, empty category shows 0/0
- [x] `lib/features/lesson/screens/download_management_screen.dart` - removed a now-unused import left from the earlier redesign
- [x] `test/helpers/controllable_lesson_api.dart`, `test/features/lesson/screens/skill_tree_dashboard_screen_test.dart`, `test/features/auth/splash_screen_test.dart` - fixtures moved to the category model; splash test expects the new banner title
- [x] `test/shared/services/http_lesson_api_test.dart` - the existing response test is now the older-server fallback case; new tests for categories parsing, an empty category, and an unknown category failing

### Key Decisions

- **Fallback for older servers**: kept, as recommended in the plan. It is the only remaining reader of the deprecated unit fields.
- **Strict parsing when categories are present**: an unknown category id throws rather than dropping the skill, so a backend bug is visible.
- **Per-category unlock in the fake API**: mirrors the real backend so dev-fake behavior matches the real path.
- **Flat node list kept**: the response keeps a flat node list and derives groups, so other consumers of the nodes are unaffected.

### Deviations from Plan

- The dashboard multi-category widget tests, empty-category and 360dp/320dp overflow tests, and fake-API per-category unlock tests are written in Stage 3, not here.
- Running `dart format` reformatted unrelated files; those were reverted, so only the files above changed.

### Dependencies Added

None.

### Developer Notes

- Full Flutter suite: 175 tests pass; `flutter analyze` reports no errors or warnings (only existing info-level lints).
- Nothing has been run on the phone yet; the manual check comes after Stage 3.
